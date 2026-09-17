import Foundation
import UIKit
import Darwin

/// Hardware Profile representing optimized runtime settings tailored for device capability
public struct HardwareProfile {
    public let name: String
    public let badgeTitle: String
    public let recommendedWorkers: Int
    public let jitterMinSeconds: Int
    public let jitterMaxSeconds: Int
    public let maxMemoryCapMB: Int
    public let adCooldownSeconds: Int
    public let aggressiveCacheClean: Bool
    public let explanation: String
}

/// Comprehensive Diagnostic Report of iPhone hardware, jailbreak state, and tuning recommendations
public struct HardwareReport {
    public let rawIdentifier: String
    public let friendlyName: String
    public let socChip: String
    public let cpuCores: Int
    public let totalRAMGB: Double
    public let availableRAMMB: Int
    public let freeStorageGB: Double
    public let jailbreakType: String
    public let isRootless: Bool
    public let craneStatus: String
    public let cranePath: String?
    public let batteryLevel: Int
    public let isCharging: Bool
    public let thermalStatus: String
    public let profile: HardwareProfile
}

/// Hardware Auto-Tuning Engine: Scans all iPhone models (A9 to A18) and configures optimal parameters
public final class HardwareOptimizer {
    public static let shared = HardwareOptimizer()

    private init() {}

    /// Performs full hardware and environment diagnostic scan
    public func scanHardware() -> HardwareReport {
        let rawId = getRawDeviceIdentifier()
        let (friendlyName, socChip, defaultRAM) = mapDeviceHardware(identifier: rawId)
        let cores = ProcessInfo.processInfo.activeProcessorCount
        
        let totalRAMBytes = ProcessInfo.processInfo.physicalMemory
        let totalRAMGB = round((Double(totalRAMBytes) / (1024.0 * 1024.0 * 1024.0)) * 10.0) / 10.0
        let effectiveRAM = totalRAMGB > 0.5 ? totalRAMGB : defaultRAM

        let availableRAMMB = getAvailableMemoryMB()
        let freeStorageGB = getFreeDiskSpaceGB()
        let (jbType, isRootless) = detectJailbreakEnvironment()
        let (craneStatus, cranePath) = detectCraneInstallation()
        let (batteryPercent, isCharging) = detectBattery()
        let thermalStatus = detectThermalState()

        let profile = computeOptimalProfile(
            ramGB: effectiveRAM,
            soc: socChip,
            isRootless: isRootless,
            thermal: thermalStatus
        )

        return HardwareReport(
            rawIdentifier: rawId,
            friendlyName: friendlyName,
            socChip: socChip,
            cpuCores: cores,
            totalRAMGB: effectiveRAM,
            availableRAMMB: availableRAMMB,
            freeStorageGB: freeStorageGB,
            jailbreakType: jbType,
            isRootless: isRootless,
            craneStatus: craneStatus,
            cranePath: cranePath,
            batteryLevel: batteryPercent,
            isCharging: isCharging,
            thermalStatus: thermalStatus,
            profile: profile
        )
    }

    /// Automatically applies optimal profile to WorkerPoolManager and DatabaseManager
    public func applyOptimalProfile(_ report: HardwareReport) {
        // Set worker count based on RAM tier
        WorkerPoolManager.shared.setMaxWorkers(report.profile.recommendedWorkers)
        
        // Save to Database Settings for persistence
        DatabaseManager.shared.setSetting(key: "hardware_profile_name", value: report.profile.name)
        DatabaseManager.shared.setSetting(key: "max_concurrent_workers", value: "\(report.profile.recommendedWorkers)")
        DatabaseManager.shared.setSetting(key: "hardware_device_model", value: report.friendlyName)
        DatabaseManager.shared.setSetting(key: "hardware_soc", value: report.socChip)
        DatabaseManager.shared.setSetting(key: "is_rootless_environment", value: report.isRootless ? "true" : "false")

        if let crane = report.cranePath {
            DatabaseManager.shared.setSetting(key: "crane_dylib_path", value: crane)
        }

        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "Hardware Scanner: Đã áp dụng Profile [\(report.profile.name)] cho [\(report.friendlyName) - \(report.socChip) - \(report.totalRAMGB)GB RAM]. Max Workers: \(report.profile.recommendedWorkers)."
        ))
    }

    /// Returns dynamic root prefix: '/var/jb' on rootless jailbreak, empty string on rootful
    public func getRootPrefix() -> String {
        let rootlessMarker = "/var/jb"
        if FileManager.default.fileExists(atPath: rootlessMarker) {
            return "/var/jb"
        }
        return ""
    }

    // MARK: - Private Diagnostics Helpers

    private func getRawDeviceIdentifier() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "iPhone8,1" : identifier
    }

    private func mapDeviceHardware(identifier: String) -> (name: String, soc: String, ramGB: Double) {
        switch identifier {
        case "iPhone8,1": return ("iPhone 6s", "Apple A9", 2.0)
        case "iPhone8,2": return ("iPhone 6s Plus", "Apple A9", 2.0)
        case "iPhone8,4": return ("iPhone SE (1st Gen)", "Apple A9", 2.0)
        case "iPhone9,1", "iPhone9,3": return ("iPhone 7", "Apple A10 Fusion", 2.0)
        case "iPhone9,2", "iPhone9,4": return ("iPhone 7 Plus", "Apple A10 Fusion", 3.0)
        case "iPhone10,1", "iPhone10,4": return ("iPhone 8", "Apple A11 Bionic", 2.0)
        case "iPhone10,2", "iPhone10,5": return ("iPhone 8 Plus", "Apple A11 Bionic", 3.0)
        case "iPhone10,3", "iPhone10,6": return ("iPhone X", "Apple A11 Bionic", 3.0)
        case "iPhone11,2": return ("iPhone XS", "Apple A12 Bionic", 4.0)
        case "iPhone11,4", "iPhone11,6": return ("iPhone XS Max", "Apple A12 Bionic", 4.0)
        case "iPhone11,8": return ("iPhone XR", "Apple A12 Bionic", 3.0)
        case "iPhone12,1": return ("iPhone 11", "Apple A13 Bionic", 4.0)
        case "iPhone12,3": return ("iPhone 11 Pro", "Apple A13 Bionic", 4.0)
        case "iPhone12,5": return ("iPhone 11 Pro Max", "Apple A13 Bionic", 4.0)
        case "iPhone12,8": return ("iPhone SE (2nd Gen)", "Apple A13 Bionic", 3.0)
        case "iPhone13,1": return ("iPhone 12 mini", "Apple A14 Bionic", 4.0)
        case "iPhone13,2": return ("iPhone 12", "Apple A14 Bionic", 4.0)
        case "iPhone13,3": return ("iPhone 12 Pro", "Apple A14 Bionic", 6.0)
        case "iPhone13,4": return ("iPhone 12 Pro Max", "Apple A14 Bionic", 6.0)
        case "iPhone14,2": return ("iPhone 13 Pro", "Apple A15 Bionic", 6.0)
        case "iPhone14,3": return ("iPhone 13 Pro Max", "Apple A15 Bionic", 6.0)
        case "iPhone14,4": return ("iPhone 13 mini", "Apple A15 Bionic", 4.0)
        case "iPhone14,5": return ("iPhone 13", "Apple A15 Bionic", 4.0)
        case "iPhone14,6": return ("iPhone SE (3rd Gen)", "Apple A15 Bionic", 4.0)
        case "iPhone14,7": return ("iPhone 14", "Apple A15 Bionic", 6.0)
        case "iPhone14,8": return ("iPhone 14 Plus", "Apple A15 Bionic", 6.0)
        case "iPhone15,2": return ("iPhone 14 Pro", "Apple A16 Bionic", 6.0)
        case "iPhone15,3": return ("iPhone 14 Pro Max", "Apple A16 Bionic", 6.0)
        case "iPhone15,4": return ("iPhone 15", "Apple A16 Bionic", 6.0)
        case "iPhone15,5": return ("iPhone 15 Plus", "Apple A16 Bionic", 6.0)
        case "iPhone16,1": return ("iPhone 15 Pro", "Apple A17 Pro", 8.0)
        case "iPhone16,2": return ("iPhone 15 Pro Max", "Apple A17 Pro", 8.0)
        case "iPhone17,1": return ("iPhone 16 Pro", "Apple A18 Pro", 8.0)
        case "iPhone17,2": return ("iPhone 16 Pro Max", "Apple A18 Pro", 8.0)
        case "iPhone17,3": return ("iPhone 16", "Apple A18", 8.0)
        case "iPhone17,4": return ("iPhone 16 Plus", "Apple A18", 8.0)
        case "x86_64", "arm64": return ("iOS Simulator / Generic A-Series", "Apple Silicon", 4.0)
        default: return ("iPhone (Universal Device)", "Apple SoC", 4.0)
        }
    }

    private func getAvailableMemoryMB() -> Int {
        var pagesize: vm_size_t = 0
        host_page_size(mach_host_self(), &pagesize)
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kerr = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            let freeBytes = UInt64(vmStats.free_count) * UInt64(pagesize)
            return Int(freeBytes / (1024 * 1024))
        }
        return 512
    }

    private func getFreeDiskSpaceGB() -> Double {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attrs[.systemFreeSize] as? Int64 {
            let freeGB = Double(freeSize) / (1024.0 * 1024.0 * 1024.0)
            return round(freeGB * 10.0) / 10.0
        }
        return 16.0
    }

    private func detectJailbreakEnvironment() -> (type: String, isRootless: Bool) {
        if FileManager.default.fileExists(atPath: "/var/jb") {
            return ("Rootless (Dopamine / palera1n rootless)", true)
        }
        if FileManager.default.fileExists(atPath: "/usr/bin/dpkg") ||
           FileManager.default.fileExists(atPath: "/Library/MobileSubstrate") ||
           FileManager.default.fileExists(atPath: "/bin/bash") {
            return ("Rootful (palera1n rootful / checkra1n)", false)
        }
        if FileManager.default.fileExists(atPath: "/var/mobile/Containers") {
            return ("TrollStore (Entitled Sandbox)", false)
        }
        return ("Standard iOS Environment", false)
    }

    private func detectCraneInstallation() -> (status: String, path: String?) {
        let candidates = [
            "/usr/lib/libcrane.dylib",
            "/var/jb/usr/lib/libcrane.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/libcrane.dylib",
            "/var/jb/Library/MobileSubstrate/DynamicLibraries/libcrane.dylib"
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return ("Sẵn Sàng (libcrane.dylib)", path)
            }
        }
        return ("Chưa tìm thấy dylib Crane", nil)
    }

    private func detectBattery() -> (percent: Int, isCharging: Bool) {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        let percent = level >= 0 ? Int(level * 100) : 100
        let charging = (state == .charging || state == .full)
        return (percent, charging)
    }

    private func detectThermalState() -> String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "Bình Thường (Mát mẻ)"
        case .fair: return "Ấm nhẹ (Ổn định)"
        case .serious: return "Nóng cao (Cần hạ nhiệt)"
        case .critical: return "Quá nhiệt nguy cấp"
        @unknown default: return "Ổn định"
        }
    }

    private func computeOptimalProfile(ramGB: Double, soc: String, isRootless: Bool, thermal: String) -> HardwareProfile {
        if ramGB <= 2.5 {
            // Low-end / Legacy (iPhone 6s, 7, SE1 - A9/A10)
            return HardwareProfile(
                name: "ECO LIGHTWEIGHT",
                badgeTitle: "🟢 Profile ECO (2-3 Workers)",
                recommendedWorkers: 3,
                jitterMinSeconds: 45,
                jitterMaxSeconds: 70,
                maxMemoryCapMB: 120,
                adCooldownSeconds: 20,
                aggressiveCacheClean: true,
                explanation: "Tối ưu riêng cho A9/A10 (2GB RAM). Kiểm soát tuyệt đối Jetsam memory kill và nhiệt độ pin."
            )
        } else if ramGB <= 4.5 {
            // Mid-range (iPhone 8, X, XR, 11, 12, 13 mini - A11 to A14)
            return HardwareProfile(
                name: "BALANCED PRO",
                badgeTitle: "🟡 Profile Cân Bằng (6 Workers)",
                recommendedWorkers: 6,
                jitterMinSeconds: 20,
                jitterMaxSeconds: 35,
                maxMemoryCapMB: 280,
                adCooldownSeconds: 12,
                aggressiveCacheClean: false,
                explanation: "Tối ưu cho A11-A14 (3-4GB RAM). Khai thác hiệu năng cao với độ trễ thấp và an toàn đa nhiệm."
            )
        } else {
            // High-end (iPhone 12 Pro - 16 Pro Max - A14 Pro to A18 Pro, 6-8GB RAM)
            return HardwareProfile(
                name: "TURBO EXTREME",
                badgeTitle: "🚀 Profile Turbo Extreme (15 Workers)",
                recommendedWorkers: 15,
                jitterMinSeconds: 6,
                jitterMaxSeconds: 12,
                maxMemoryCapMB: 650,
                adCooldownSeconds: 6,
                aggressiveCacheClean: false,
                explanation: "Khai thác toàn bộ sức mạnh A15-A18 Pro (6-8GB RAM). Xử lý hàng chục tài khoản đồng thời tốc độ tối đa."
            )
        }
    }
}
