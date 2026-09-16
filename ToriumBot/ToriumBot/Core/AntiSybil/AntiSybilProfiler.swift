import Foundation

/// Represents a spoofed Android device profile for anti-sybil defenses
public struct DeviceProfile: Codable {
    public let model: String
    public let osVersion: String
    public let platform: String

    public init(model: String, osVersion: String, platform: String = "android") {
        self.model = model
        self.osVersion = osVersion
        self.platform = platform
    }
}

/// Advanced anti-sybil heuristic spoofer: randomizes hardware fingerprints, ad revenue, and timezones
public final class AntiSybilProfiler {
    public static let shared = AntiSybilProfiler()

    private let devicePool: [DeviceProfile] = [
        DeviceProfile(model: "SM-S928B", osVersion: "14"), // Samsung Galaxy S24 Ultra
        DeviceProfile(model: "SM-S918B", osVersion: "14"), // Samsung Galaxy S23 Ultra
        DeviceProfile(model: "Pixel 8 Pro", osVersion: "14"), // Google Pixel 8 Pro
        DeviceProfile(model: "Pixel 7a", osVersion: "13"),    // Google Pixel 7a
        DeviceProfile(model: "23049PCD8G", osVersion: "13"),  // Xiaomi POCO F5
        DeviceProfile(model: "CPH2451", osVersion: "13"),     // OnePlus 11
        DeviceProfile(model: "2201123G", osVersion: "13"),    // Xiaomi 12
        DeviceProfile(model: "SM-A546B", osVersion: "14"),    // Samsung Galaxy A54 5G
        DeviceProfile(model: "V2250", osVersion: "13")        // Vivo V27
    ]

    private init() {}

    /// Derives a consistent, unique hardware device profile for a given account
    public func getProfile(for account: Account) -> DeviceProfile {
        let seed = abs((account.email + (account.deviceId ?? "")).hashValue)
        let index = seed % devicePool.count
        return devicePool[index]
    }

    /// Generates randomized AdMob Rewarded Video micro-revenue ($0.00812 - $0.02435 USD)
    public func generateRandomValueMicros() -> Int {
        // Random micro-cents in range 8120 to 24350
        return Int.random(in: 8120...24350)
    }

    /// Computes accurate UTC offset in minutes based on proxy host or default timezone
    public func calculateUtcOffsetMinutes(for account: Account) -> Int {
        if let host = account.proxyHost?.lowercased() {
            // Heuristic detection based on common proxy domain suffixes
            if host.contains(".us") || host.contains("us-") || host.contains("usa") {
                return -300 // US Eastern (UTC-5)
            } else if host.contains(".uk") || host.contains("gb-") || host.contains("london") {
                return 0 // GMT (UTC+0)
            } else if host.contains(".de") || host.contains(".fr") || host.contains("eu-") {
                return 60 // CET (UTC+1)
            } else if host.contains(".sg") || host.contains("singapore") {
                return 480 // SGT (UTC+8)
            } else if host.contains(".vn") || host.contains("vietnam") {
                return 420 // ICT (UTC+7)
            }
        }

        // Fallback to configured global timezone offset or Vietnam UTC+7
        let offsetStr = DatabaseManager.shared.getSetting(key: "timezone_offset") ?? "420"
        return Int(offsetStr) ?? 420
    }

    /// Computes local date key "YYYY-MM-DD" based on account's effective UTC offset
    public func getLocalDateKey(offsetMinutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: offsetMinutes * 60)
        return formatter.string(from: Date())
    }

    /// Evaluates whether the current local time falls within the configured Night Sleep Simulator window
    public func isSleepTimeNow() -> Bool {
        let enabled = DatabaseManager.shared.getSetting(key: "sleep_simulator_enabled") == "true"
        guard enabled else { return false }

        let startHour = Int(DatabaseManager.shared.getSetting(key: "sleep_start_hour") ?? "1") ?? 1
        let endHour = Int(DatabaseManager.shared.getSetting(key: "sleep_end_hour") ?? "5") ?? 5

        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)! // UTC+7 baseline
        let currentHour = calendar.component(.hour, from: Date())

        if startHour < endHour {
            return currentHour >= startHour && currentHour < endHour
        } else {
            // Overnight range e.g. 23:00 to 05:00
            return currentHour >= startHour || currentHour < endHour
        }
    }
}
