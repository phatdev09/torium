import Foundation

// MARK: - API Response Data Models

public struct DeviceSessionRequest: Codable {
    public let platform: String
    public let deviceId: String
    public let deviceModel: String
    public let osVersion: String
    public let appVersion: String
    public let isRooted: Bool
    public let clerkId: String

    public init(deviceId: String, clerkId: String, profile: DeviceProfile, appVersion: String) {
        self.platform = profile.platform
        self.deviceId = deviceId
        self.deviceModel = profile.model
        self.osVersion = profile.osVersion
        self.appVersion = appVersion
        self.isRooted = false
        self.clerkId = clerkId
    }
}

public struct DeviceSessionResponse: Codable {
    public let success: Bool?
}

public struct SessionStatusResponse: Codable {
    public let status: String?
    public let rate: Double?
}

public struct WalletBalanceResponse: Codable {
    public let balance: Double?
    public let torBalance: Double?
    public let available: Double?

    public var effectiveBalance: Double {
        return balance ?? torBalance ?? available ?? 0.0
    }
}

public struct RewardedIntentResponse: Codable {
    public let intentId: String
}

public struct RewardedIntentStatusResponse: Codable {
    public let status: String           // e.g. "verified"
    public let verifiedAt: Int64?
    public let expiresAt: Int64?
    public let failureReason: String?
    public let consumedAt: Int64?
}

public struct AdRevenuePayload: Codable {
    public let currency: String         // "USD"
    public let precision: Int           // 3
    public let valueMicros: Int         // randomized 8,120 to 24,350
    public let occurredAt: Int64        // current timestamp ms
    public let localDateKey: String     // "YYYY-MM-DD"
    public let utcOffsetMinutes: Int    // calculated from proxy Geo-IP
}

public struct BoostRequest: Codable {
    public let verifiedIntentId: String
    public let adRevenue: AdRevenuePayload
}

public struct BucketInfo: Codable {
    public let hourlyRemaining: Int
    public let hourlyResetAt: Int64?
    public let dailyRemaining: Int
    public let dailyCap: Int
    public let hourlyCap: Int
    public let cooldownEndsAt: Int64?
    public let cooldownRemainingMs: Int
}

public struct BoostResponse: Codable {
    public let boostCount: Int?
    public let totalBoostRate: Double?
    public let newRate: Double?
    public let grantedSlots: Int?
    public let bucket: BucketInfo
}

// MARK: - Custom Errors

public enum ToriumAPIError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case rateLimited
    case networkError(String)
    case serverError(statusCode: Int, message: String)
    case invalidResponse
    case proxyDead

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "401 Unauthorized: Token hết hạn, cần refresh"
        case .forbidden:
            return "403 Forbidden: Account có thể đã bị ban"
        case .rateLimited:
            return "429 Too Many Requests: Vượt quá giới hạn rate limit"
        case .networkError(let msg):
            return "Lỗi mạng: \(msg)"
        case .serverError(let code, let msg):
            return "Lỗi Server (\(code)): \(msg)"
        case .invalidResponse:
            return "Phản hồi từ server không hợp lệ"
        case .proxyDead:
            return "Proxy không thể kết nối tới Torium Network"
        }
    }
}

// MARK: - ToriumAPIClient

public final class ToriumAPIClient {
    public static let baseURL = "https://api.torium.network"
    private static let defaultOtaVersion = "0a9f87c3-0a5f-4ed5-aefd-7a9004875813"
    private static let defaultAppVersion = "2.1.0"
    private static let userAgent = "okhttp/4.12.0"

    private let account: Account
    private let session: URLSession

    public init(account: Account) {
        self.account = account
        self.session = ProxyURLSession.createSession(account: account, timeoutInterval: 30.0)
    }

    private var activeBaseURL: String {
        return DatabaseManager.shared.getAPIBaseURL()
    }

    private var activeOtaVersion: String {
        return DatabaseManager.shared.getSetting(key: "x_ota_version") ?? ToriumAPIClient.defaultOtaVersion
    }

    private var activeAppVersion: String {
        return DatabaseManager.shared.getSetting(key: "x_app_version") ?? ToriumAPIClient.defaultAppVersion
    }

    // MARK: - Private Request Builder

    private func makeRequest(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        requiresAuth: Bool = true
    ) throws -> URLRequest {
        guard let url = URL(string: "\(activeBaseURL)\(path)") else {
            throw ToriumAPIError.networkError("Invalid URL: \(activeBaseURL)\(path)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // Required headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(ToriumAPIClient.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue(activeAppVersion, forHTTPHeaderField: "x-app-version")
        request.setValue(activeOtaVersion, forHTTPHeaderField: "x-ota-version")
        request.setValue("gzip", forHTTPHeaderField: "Accept-Encoding")

        if let deviceId = account.deviceId, !deviceId.isEmpty {
            request.setValue(deviceId, forHTTPHeaderField: "x-device-id")
        }

        if requiresAuth {
            guard let token = account.bearerToken, !token.isEmpty else {
                throw ToriumAPIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Robust Request Execution with 3x Retry

    private func executeWithRetry<T: Decodable>(
        _ request: URLRequest,
        maxRetries: Int = 3,
        decodeType: T.Type
    ) async throws -> T {
        var lastError: Error = ToriumAPIError.networkError("Request failed")

        for attempt in 1...maxRetries {
            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw ToriumAPIError.invalidResponse
                }

                if httpResponse.statusCode == 401 {
                    throw ToriumAPIError.unauthorized
                }
                if httpResponse.statusCode == 403 {
                    let errStr = String(data: data, encoding: .utf8) ?? "403 Forbidden"
                    if let aid = account.id {
                        DatabaseManager.shared.quarantineAccount(id: aid, reason: errStr)
                    }
                    throw ToriumAPIError.forbidden
                }
                if httpResponse.statusCode == 429 {
                    throw ToriumAPIError.rateLimited
                }

                let bodyStr = String(data: data, encoding: .utf8) ?? ""
                if bodyStr.contains("banned") || bodyStr.contains("suspended") || bodyStr.contains("sybil_detected") {
                    if let aid = account.id {
                        DatabaseManager.shared.quarantineAccount(id: aid, reason: bodyStr)
                    }
                    throw ToriumAPIError.forbidden
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    let errStr = bodyStr.isEmpty ? "Status \(httpResponse.statusCode)" : bodyStr
                    throw ToriumAPIError.serverError(statusCode: httpResponse.statusCode, message: errStr)
                }

                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)

            } catch let error as ToriumAPIError {
                if case .unauthorized = error { throw error }
                if case .forbidden = error { throw error }

                lastError = error
                let sleepSeconds = (attempt == 1) ? 5 : 10
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds) * 1_000_000_000)
            } catch {
                lastError = error
                let sleepSeconds = (attempt == 1) ? 5 : 10
                try? await Task.sleep(nanoseconds: UInt64(sleepSeconds) * 1_000_000_000)
            }
        }

        throw lastError
    }

    // MARK: - Endpoint 1: Register Device Session with Anti-Sybil Profiler

    public func registerDeviceSession() async throws -> Bool {
        let deviceId = account.deviceId ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let clerkId = account.clerkId ?? ""
        let profile = AntiSybilProfiler.shared.getProfile(for: account)

        let payload = DeviceSessionRequest(deviceId: deviceId, clerkId: clerkId, profile: profile, appVersion: activeAppVersion)
        let bodyData = try JSONEncoder().encode(payload)

        let req = try makeRequest(path: "/device/session", method: "POST", body: bodyData, requiresAuth: false)
        let res = try await executeWithRetry(req, decodeType: DeviceSessionResponse.self)
        return res.success ?? true
    }

    // MARK: - Endpoint 2: Check Mining Status

    public func getSessionStatus() async throws -> SessionStatusResponse {
        let path = DatabaseManager.shared.getAPIMiningStatusPath()
        let req = try makeRequest(path: path, method: "GET", requiresAuth: true)
        return try await executeWithRetry(req, decodeType: SessionStatusResponse.self)
    }

    // MARK: - Endpoint 3: Check Wallet Balance

    public func getWalletBalance() async throws -> WalletBalanceResponse {
        let req = try makeRequest(path: "/v1/wallet/balance", method: "GET", requiresAuth: true)
        return try await executeWithRetry(req, decodeType: WalletBalanceResponse.self)
    }

    // MARK: - Endpoint 4: Check Boost State

    public func getBoostState() async throws -> [String: AnyCodable] {
        let req = try makeRequest(path: "/v1/mining/boost-state?abVariant=unlimited", method: "GET", requiresAuth: true)
        return try await executeWithRetry(req, decodeType: [String: AnyCodable].self)
    }

    // MARK: - Endpoint 5: Rewarded Intent (Step 1 Ad)

    public func createRewardedIntent() async throws -> RewardedIntentResponse {
        let req = try makeRequest(path: "/v1/mining/v2/rewarded-intents", method: "POST", body: "{}".data(using: .utf8), requiresAuth: true)
        return try await executeWithRetry(req, decodeType: RewardedIntentResponse.self)
    }

    // MARK: - Endpoint 6: Verify Rewarded Intent (Step 2 Ad)

    public func verifyRewardedIntent(intentId: String) async throws -> RewardedIntentStatusResponse {
        let req = try makeRequest(path: "/v1/mining/v2/rewarded-intents/\(intentId)", method: "GET", requiresAuth: true)
        return try await executeWithRetry(req, decodeType: RewardedIntentStatusResponse.self)
    }

    // MARK: - Endpoint 7: Boost Mining with Anti-Sybil Micro-Revenue & Geo-IP matching

    public func boostMining(verifiedIntentId: String) async throws -> BoostResponse {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let offsetMinutes = AntiSybilProfiler.shared.calculateUtcOffsetMinutes(for: account)
        let localDateKey = AntiSybilProfiler.shared.getLocalDateKey(offsetMinutes: offsetMinutes)
        let randomValueMicros = AntiSybilProfiler.shared.generateRandomValueMicros()

        let revenue = AdRevenuePayload(
            currency: "USD",
            precision: 3,
            valueMicros: randomValueMicros,
            occurredAt: nowMs,
            localDateKey: localDateKey,
            utcOffsetMinutes: offsetMinutes
        )

        let payload = BoostRequest(verifiedIntentId: verifiedIntentId, adRevenue: revenue)
        let bodyData = try JSONEncoder().encode(payload)

        let path = DatabaseManager.shared.getAPIBoostPath()
        let req = try makeRequest(path: path, method: "POST", body: bodyData, requiresAuth: true)
        return try await executeWithRetry(req, decodeType: BoostResponse.self)
    }

    // MARK: - Endpoint 8: Activity Ticker (Keepalive)

    public func sendActivityTicker() async throws -> Bool {
        let req = try makeRequest(path: "/v1/activity/ticker", method: "GET", requiresAuth: true)
        let _ = try await executeWithRetry(req, decodeType: [String: AnyCodable].self)
        return true
    }
}

// MARK: - Type-safe JSON Any Value Wrapper for Generic Responses

public struct AnyCodable: Codable {
    public let value: Any

    public init(_ value: Any) {
        self.value = value
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([AnyCodable].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: AnyCodable].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            value = ""
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let stringVal = value as? String {
            try container.encode(stringVal)
        }
    }
}
