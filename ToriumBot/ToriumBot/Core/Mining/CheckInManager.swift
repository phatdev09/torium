import Foundation

/// Manages daily check-ins (every 24 hours ±30 mins jitter, UTC+7 timezone)
public final class CheckInManager {
    private let account: Account
    private let apiClient: ToriumAPIClient

    public init(account: Account) {
        self.account = account
        self.apiClient = ToriumAPIClient(account: account)
    }

    /// Performs daily check-in and computes next checkin timestamp with ±30m random jitter
    public func performCheckIn() async throws -> Int64 {
        guard let accountId = account.id else {
            throw ToriumAPIError.networkError("Account ID missing")
        }

        DatabaseManager.shared.insertLog(Log(
            accountId: accountId,
            level: .info,
            action: .checkin,
            message: "Bắt đầu check-in cho [\(account.email)]..."
        ))

        // 1. Register device session (keepalive)
        let sessionOk = try await apiClient.registerDeviceSession()
        if !sessionOk {
            throw ToriumAPIError.networkError("Device session registration failed")
        }

        // 2. Ping activity ticker
        _ = try? await apiClient.sendActivityTicker()

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        // 3. Compute next checkin time: 24h + random(-30m, +30m)
        let twentyFourHoursMs: Int64 = 24 * 60 * 60 * 1000
        let randomJitterMinutes = Int.random(in: -30...30)
        let jitterMs = Int64(randomJitterMinutes * 60 * 1000)
        let nextCheckinMs = nowMs + twentyFourHoursMs + jitterMs

        // 4. Update today's mining stats record
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let todayDate = formatter.string(from: Date())

        var stats = DatabaseManager.shared.getStats(accountId: accountId, date: todayDate) ?? MiningStats(
            accountId: accountId,
            date: todayDate
        )

        stats.lastCheckinAt = nowMs
        stats.nextCheckinAt = nextCheckinMs
        DatabaseManager.shared.upsertStats(stats)

        let nextDate = Date(timeIntervalSince1970: TimeInterval(nextCheckinMs) / 1000.0)
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        timeFormatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let nextStr = timeFormatter.string(from: nextDate)

        DatabaseManager.shared.insertLog(Log(
            accountId: accountId,
            level: .info,
            action: .checkin,
            message: "Check-in thành công! Lần tiếp theo dự kiến: \(nextStr) (UTC+7)"
        ))

        return nextCheckinMs
    }
}
