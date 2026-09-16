import Foundation
import UIKit

/// Manages automated registration, sequential batch queuing, and IPC communication with ToriumHelper Tweak
public final class AccountRegistrar {
    public static let shared = AccountRegistrar()

    public enum RegistrationStep: Equatable {
        case idle
        case switchingContainer(String)
        case fillingForm
        case waitingForCaptcha
        case fetchingOTP
        case submittingOTP
        case extractingToken
        case completed(String)
        case paused
        case failed(String)
    }

    private let ipcBaseDir = "/var/mobile/Library/ToriumBot/ipc"
    public private(set) var isQueueRunning: Bool = false
    public private(set) var isQueuePaused: Bool = false

    private init() {
        createIPCDirectoryIfNeeded()
    }

    private func createIPCDirectoryIfNeeded() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: ipcBaseDir) {
            try? fm.createDirectory(atPath: ipcBaseDir, withIntermediateDirectories: true, attributes: nil)
        }
    }

    // MARK: - Auto Re-Login Flow on 401

    /// Automatically logs into Torium in the background when 401 Unauthorized is detected
    public func performAutoRelogin(account: Account) async -> Bool {
        guard let containerId = account.containerId, !containerId.isEmpty else { return false }
        createIPCDirectoryIfNeeded()

        // 1. Write proxy.json so in-app traffic is protected
        writeProxyJSON(account: account)

        // 2. Write relogin task
        let taskData: [String: String] = [
            "action": "relogin",
            "email": account.email,
            "password": account.password
        ]
        if let json = try? JSONSerialization.data(withJSONObject: taskData) {
            try? json.write(to: URL(fileURLWithPath: "\(ipcBaseDir)/task.json"))
        }

        // 3. Switch container and launch
        CraneManager.shared.switchAndLaunch(containerId: containerId)

        // 4. Post Darwin Notification to tweak
        postDarwinNotification("com.toriumbot.relogin_start")

        // 5. Wait up to 25s for tweak to capture new token
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if let result = readAuthResult() {
                // Update SQLite
                DatabaseManager.shared.updateTokens(
                    id: account.id!,
                    token: result.token,
                    clerkId: result.clerkId,
                    deviceId: result.deviceId
                )
                DatabaseManager.shared.insertLog(Log(
                    accountId: account.id,
                    level: .info,
                    action: .login,
                    message: "Auto Re-Login thành công! Đã cấp token mới cho [\(account.email)]."
                ))
                cleanResultJSON()
                return true
            }
        }

        return false
    }

    // MARK: - Single Account Registration

    public func registerAccount(
        account: Account,
        credential: DongVanCredential?,
        onStepUpdate: @escaping (RegistrationStep) -> Void,
        onRequestCaptchaSolve: @escaping (@escaping () -> Void) -> Void
    ) async throws -> Account {
        guard let containerId = account.containerId, !containerId.isEmpty else {
            throw ToriumAPIError.networkError("Container ID is missing")
        }

        createIPCDirectoryIfNeeded()

        // Step 1: Write proxy & task for ToriumHelper tweak
        writeProxyJSON(account: account)

        let taskData: [String: String] = [
            "action": "register",
            "email": account.email,
            "password": account.password,
            "referralCode": account.referralCode ?? ""
        ]
        if let json = try? JSONSerialization.data(withJSONObject: taskData) {
            try? json.write(to: URL(fileURLWithPath: "\(ipcBaseDir)/task.json"))
        }

        // Step 2: Switch container in Crane & launch app
        onStepUpdate(.switchingContainer(containerId))
        CraneManager.shared.switchAndLaunch(containerId: containerId)
        try await Task.sleep(nanoseconds: 2_500_000_000)

        // Step 3: Trigger Tweak to auto-fill form
        onStepUpdate(.fillingForm)
        postDarwinNotification("com.toriumbot.reg_start")
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Step 4: Wait for user to tap Cloudflare Captcha
        onStepUpdate(.waitingForCaptcha)
        await withCheckedContinuation { continuation in
            onRequestCaptchaSolve {
                continuation.resume()
            }
        }

        // Step 5: Read OTP via dongvanfb API
        var otpCode: String?
        if let cred = credential {
            onStepUpdate(.fetchingOTP)
            do {
                otpCode = try await DongVanFBClient.shared.fetchToriumOTP(credential: cred, timeoutSeconds: 60.0)
            } catch {
                DatabaseManager.shared.insertLog(Log(
                    level: .warn,
                    action: .login,
                    message: "Lỗi đọc OTP DongVan: \(error.localizedDescription)"
                ))
            }
        }

        // Step 6: Dispatch OTP to Tweak via IPC
        if let otp = otpCode {
            onStepUpdate(.submittingOTP)
            let otpData: [String: String] = ["otp": otp]
            if let json = try? JSONSerialization.data(withJSONObject: otpData) {
                try? json.write(to: URL(fileURLWithPath: "\(ipcBaseDir)/otp.json"))
            }
            postDarwinNotification("com.toriumbot.otp_ready")
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        // Step 7: Intercept Auth Token
        onStepUpdate(.extractingToken)
        var extractedAuth: (token: String, clerkId: String, deviceId: String)?

        for _ in 0..<30 {
            if let res = readAuthResult() {
                extractedAuth = res
                cleanResultJSON()
                break
            }
            try? await Task.sleep(nanoseconds: 500_000_000)
        }

        // Fallback: Check TokenExtractor
        if extractedAuth == nil {
            if let fallback = TokenExtractor.shared.extractAuth(for: containerId) {
                extractedAuth = (fallback.token, fallback.clerkId, fallback.deviceId)
            }
        }

        guard let auth = extractedAuth else {
            onStepUpdate(.failed("Không lấy được Token sau đăng ký"))
            throw ToriumAPIError.serverError(statusCode: 401, message: "Token extraction failed")
        }

        var updatedAccount = account
        updatedAccount.bearerToken = auth.token
        updatedAccount.clerkId = auth.clerkId
        updatedAccount.deviceId = auth.deviceId
        DatabaseManager.shared.updateAccount(updatedAccount)

        // Step 8: Clean Caches of container to save disk space (<5MB)
        CraneManager.shared.optimizeContainerStorage(containerId: containerId)

        // Step 9: Instant Telegram Backup
        TelegramReporter.shared.sendManualBackup()

        onStepUpdate(.completed(account.email))
        return updatedAccount
    }

    // MARK: - Batch Sequential Registration Queue

    public func pauseBatchQueue() {
        isQueuePaused = true
    }

    public func resumeBatchQueue() {
        isQueuePaused = false
    }

    public func stopBatchQueue() {
        isQueueRunning = false
        isQueuePaused = false
    }

    // MARK: - IPC Helper Functions

    private func writeProxyJSON(account: Account) {
        if let host = account.proxyHost, !host.isEmpty, let port = account.proxyPort {
            let proxyDict: [String: Any] = [
                "host": host,
                "port": port,
                "username": account.proxyUsername ?? "",
                "password": account.proxyPassword ?? "",
                "protocol": account.proxyProtocol ?? "socks5"
            ]
            if let json = try? JSONSerialization.data(withJSONObject: proxyDict) {
                try? json.write(to: URL(fileURLWithPath: "\(ipcBaseDir)/proxy.json"))
            }
        }
    }

    private func readAuthResult() -> (token: String, clerkId: String, deviceId: String)? {
        let resultPath = "\(ipcBaseDir)/result.json"
        guard FileManager.default.fileExists(atPath: resultPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: resultPath)),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String],
              let token = dict["token"], !token.isEmpty else {
            return nil
        }
        let clerkId = dict["clerkId"] ?? "user_\(UUID().uuidString.prefix(12))"
        let deviceId = dict["deviceId"] ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        return (token, clerkId, deviceId)
    }

    private func cleanResultJSON() {
        try? FileManager.default.removeItem(atPath: "\(ipcBaseDir)/result.json")
    }

    private func postDarwinNotification(_ name: String) {
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let cfName = CFNotificationName(name as CFString)
        CFNotificationCenterPostNotification(center, cfName, nil, nil, true)
    }
}
