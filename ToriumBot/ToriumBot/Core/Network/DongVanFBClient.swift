import Foundation

/// Credentials extracted from dongvanfb account line
public struct DongVanCredential {
    public let email: String
    public let password: String
    public let refreshToken: String
    public let clientId: String

    public init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        if parts.count >= 4 {
            self.email = parts[0]
            self.password = parts[1]
            self.refreshToken = parts[2]
            self.clientId = parts[3]
        } else if parts.count == 3 {
            self.email = parts[0]
            if parts[1].count > 40 {
                // parts[1] is a long refresh token
                self.password = ""
                self.refreshToken = parts[1]
                self.clientId = parts[2]
            } else {
                self.password = parts[1]
                self.refreshToken = parts[2]
                self.clientId = "e9a300d1-1e54-41ea-84f9-29b82100e65e"
            }
        } else if parts.count == 2 {
            self.email = parts[0]
            self.password = ""
            self.refreshToken = parts[1]
            self.clientId = "e9a300d1-1e54-41ea-84f9-29b82100e65e"
        } else {
            return nil
        }
    }
}

/// Advanced secure generator for Torium farming accounts and passwords
public struct AccountGenerator {
    private static let upperChars = "ABCDEFGHJKLMNPQRSTUVWXYZ"
    private static let lowerChars = "abcdefghijkmnopqrstuvwxyz"
    private static let digitChars = "23456789"
    private static let specialChars = "!@#$%&*"

    /// Generates a strong, compliant random password (e.g. Torium#7xK9pL2!)
    public static func generateSecurePassword() -> String {
        var result = "Torium#"
        let allChars = upperChars + lowerChars + digitChars
        for _ in 0..<8 {
            if let randomChar = allChars.randomElement() {
                result.append(randomChar)
            }
        }
        result.append(specialChars.randomElement() ?? "!")
        return result
    }

    /// Generates a clean random alphanumeric identifier
    public static func generateRandomUsername() -> String {
        let prefixes = ["tor", "miner", "node", "farm", "bot", "core"]
        let prefix = prefixes.randomElement() ?? "tor"
        let randomNum = Int.random(in: 10000...99999)
        return "\(prefix)_\(randomNum)"
    }
}

/// Client to fetch verification OTP from Hotmail via dongvanfb.net OAuth2 API
public final class DongVanFBClient {
    public static let shared = DongVanFBClient()
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15.0
        self.session = URLSession(configuration: config)
    }

    /// Polls inbox for Torium verification code with 60-second timeout
    public func fetchToriumOTP(
        credential: DongVanCredential,
        timeoutSeconds: TimeInterval = 60.0
    ) async throws -> String {
        let startTime = Date()
        let pollInterval: UInt64 = 4_000_000_000 // 4 seconds

        while Date().timeIntervalSince(startTime) < timeoutSeconds {
            do {
                if let otp = try await queryMailboxForOTP(credential: credential) {
                    return otp
                }
            } catch {
                // Log and continue polling until timeout
            }

            try await Task.sleep(nanoseconds: pollInterval)
        }

        throw ToriumAPIError.networkError("Hết thời gian chờ OTP từ email (60s)")
    }

    /// Queries dongvanfb API or Microsoft Graph via refresh token
    private func queryMailboxForOTP(credential: DongVanCredential) async throws -> String? {
        // Step 1: Query dongvanfb API gateway
        let apiEndpoint = "https://api.dongvanfb.net/mail/read"
        guard let url = URL(string: apiEndpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyDict: [String: String] = [
            "email": credential.email,
            "password": credential.password,
            "refresh_token": credential.refreshToken,
            "client_id": credential.clientId
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) else { return nil }
        request.httpBody = bodyData

        do {
            let (data, response) = try await session.data(for: request)
            if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                if let contentString = String(data: data, encoding: .utf8) {
                    if let code = extractOTP(from: contentString) {
                        return code
                    }
                }
            }
        } catch {
            // If primary endpoint fails, fallback to direct MS Graph token exchange & read
            return try await queryGraphDirect(credential: credential)
        }

        return nil
    }

    /// Direct fallback via Microsoft OAuth2 token endpoint if dongvanfb gateway is unreachable
    private func queryGraphDirect(credential: DongVanCredential) async throws -> String? {
        guard let tokenUrl = URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token") else { return nil }

        var tokenReq = URLRequest(url: tokenUrl)
        tokenReq.httpMethod = "POST"
        tokenReq.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let params = [
            "client_id": credential.clientId,
            "refresh_token": credential.refreshToken,
            "grant_type": "refresh_token",
            "scope": "https://graph.microsoft.com/Mail.Read offline_access"
        ]

        let bodyString = params.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }.joined(separator: "&")
        tokenReq.httpBody = bodyString.data(using: .utf8)

        let (tokenData, tokenRes) = try await session.data(for: tokenReq)
        guard let httpRes = tokenRes as? HTTPURLResponse, (200...299).contains(httpRes.statusCode),
              let json = try? JSONSerialization.jsonObject(with: tokenData) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            return nil
        }

        // Fetch recent messages with 'Torium' in subject or body
        guard let messagesUrl = URL(string: "https://graph.microsoft.com/v1.0/me/messages?$top=5&$orderby=receivedDateTime%20desc") else { return nil }
        var msgReq = URLRequest(url: messagesUrl)
        msgReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (msgData, msgRes) = try await session.data(for: msgReq)
        guard let httpMsgRes = msgRes as? HTTPURLResponse, (200...299).contains(httpMsgRes.statusCode),
              let msgJson = try? JSONSerialization.jsonObject(with: msgData) as? [String: Any],
              let values = msgJson["value"] as? [[String: Any]] else {
            return nil
        }

        for msg in values {
            let subject = msg["subject"] as? String ?? ""
            let bodyPreview = msg["bodyPreview"] as? String ?? ""
            let combined = "\(subject) \(bodyPreview)"

            if combined.localizedCaseInsensitiveContains("torium") {
                if let otp = extractOTP(from: combined) {
                    return otp
                }
            }
        }

        return nil
    }

    /// Regex extraction of 6-digit numeric OTP code
    private func extractOTP(from text: String) -> String? {
        let pattern = "\\b[0-9]{6}\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        if let first = results.first {
            return nsString.substring(with: first.range)
        }
        return nil
    }
}
