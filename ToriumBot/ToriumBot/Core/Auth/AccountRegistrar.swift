import Foundation
import UIKit

/// Manages semi-automated registration: fills forms, prompts user for Cloudflare captcha, retrieves OTP, and extracts token
public final class AccountRegistrar {
    public static let shared = AccountRegistrar()

    public enum RegistrationStep: Equatable {
        case openingContainer
        case fillingCredentials
        case waitingForUserCaptcha
        case fetchingOTP
        case submittingOTP
        case extractingToken
        case completed
        case failed(String)
    }

    private init() {}

    /// Registers a new account inside a Crane container
    public func startRegistration(
        email: String,
        password: String,
        credential: DongVanCredential?,
        containerId: String,
        onStepUpdate: @escaping (RegistrationStep) -> Void,
        onRequestCaptchaSolve: @escaping (@escaping () -> Void) -> Void
    ) async throws -> Account {
        // Step 1: Open container
        onStepUpdate(.openingContainer)
        CraneManager.shared.launchContainer(containerId: containerId)
        try await Task.sleep(nanoseconds: 3_000_000_000) // Wait 3s for launch

        // Step 2: Fill credentials
        onStepUpdate(.fillingCredentials)
        UIPasteboard.general.string = "\(email)"
        try await Task.sleep(nanoseconds: 1_500_000_000)

        // Step 3: Wait for user to solve Cloudflare Turnstile captcha
        onStepUpdate(.waitingForUserCaptcha)

        await withCheckedContinuation { continuation in
            onRequestCaptchaSolve {
                continuation.resume()
            }
        }

        // Step 4: Retrieve OTP if dongvanfb credential is provided
        var otpCode: String?
        if let cred = credential {
            onStepUpdate(.fetchingOTP)
            do {
                otpCode = try await DongVanFBClient.shared.fetchToriumOTP(credential: cred, timeoutSeconds: 60.0)
            } catch {
                DatabaseManager.shared.insertLog(Log(
                    level: .warn,
                    action: .login,
                    message: "Không lấy được OTP tự động qua API dongvanfb: \(error.localizedDescription)"
                ))
            }
        }

        // Step 5: Submitting OTP
        if let otp = otpCode {
            onStepUpdate(.submittingOTP)
            UIPasteboard.general.string = otp
            try await Task.sleep(nanoseconds: 2_000_000_000)
        }

        // Step 6: Extract static Bearer token from container
        onStepUpdate(.extractingToken)
        try await Task.sleep(nanoseconds: 3_000_000_000)

        let extracted = TokenExtractor.shared.extractAuth(for: containerId)
        let token = extracted?.token
        let clerkId = extracted?.clerkId ?? "user_\(UUID().uuidString.prefix(12))"
        let deviceId = extracted?.deviceId ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()

        // Step 7: Create & store account in SQLite
        var newAccount = Account(
            email: email,
            password: password,
            bearerToken: token,
            clerkId: clerkId,
            deviceId: deviceId,
            containerId: containerId,
            isActive: true,
            isBanned: false
        )

        if let insertedId = DatabaseManager.shared.insertAccount(newAccount) {
            newAccount.id = insertedId
        }

        onStepUpdate(.completed)
        DatabaseManager.shared.insertLog(Log(
            accountId: newAccount.id,
            level: .info,
            action: .login,
            message: "Đăng ký thành công tài khoản [\(email)] trong container [\(containerId)]."
        ))

        return newAccount
    }
}
