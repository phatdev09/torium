import Foundation

/// Executes the strict 3-step rewarded ad watch flow and updates database statistics
public final class AdWatcher {
    private let account: Account
    private let apiClient: ToriumAPIClient

    public init(account: Account) {
        self.account = account
        self.apiClient = ToriumAPIClient(account: account)
    }

    /// Executes complete 3-step ad flow:
    /// Step 1: POST /v1/mining/v2/rewarded-intents -> intentId
    /// Step 2: GET /v1/mining/v2/rewarded-intents/{intentId} -> verify (must be "verified")
    /// Step 3: POST /v1/mining/v2/boost -> claim boost
    public func watchAd() async throws -> BucketInfo {
        guard let accountId = account.id else {
            throw ToriumAPIError.networkError("Account ID missing")
        }

        DatabaseManager.shared.insertLog(Log(
            accountId: accountId,
            level: .info,
            action: .adWatch,
            message: "Bắt đầu xem ad cho [\(account.email)]..."
        ))

        // --- STEP 1: Create Rewarded Intent ---
        let intentRes = try await apiClient.createRewardedIntent()
        let intentId = intentRes.intentId
        DatabaseManager.shared.insertLog(Log(
            accountId: accountId,
            level: .info,
            action: .adWatch,
            message: "Bước 1 OK: Tạo IntentId [\(intentId)]"
        ))

        // Small simulation delay for video ad playback (3-5s)
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // --- STEP 2: Verify Rewarded Intent ---
        let verifyRes = try await apiClient.verifyRewardedIntent(intentId: intentId)
        guard verifyRes.status.lowercased() == "verified" else {
            let reason = verifyRes.failureReason ?? "Status: \(verifyRes.status)"
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .error,
                action: .adWatch,
                message: "Bước 2 thất bại: Ad chưa verified (\(reason))"
            ))
            throw ToriumAPIError.serverError(statusCode: 400, message: "Ad intent not verified: \(reason)")
        }

        DatabaseManager.shared.insertLog(Log(
            accountId: accountId,
            level: .info,
            action: .adWatch,
            message: "Bước 2 OK: Intent đã verified"
        ))

        // --- STEP 3: Claim Boost ---
        let boostRes = try await apiClient.boostMining(verifiedIntentId: intentId)
        let bucket = boostRes.bucket
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        // Check wallet balance to record accurate TOR amount
        let balanceRes = try? await apiClient.getWalletBalance()
        let currentBalance = balanceRes?.effectiveBalance ?? 0.0

        // Formulate current date key (UTC+7)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let todayDate = formatter.string(from: Date())

        // Fetch or create daily stats record
        var stats = DatabaseManager.shared.getStats(accountId: accountId, date: todayDate) ?? MiningStats(
            accountId: accountId,
            date: todayDate,
            adsWatched: 0,
            adsRemainingToday: bucket.dailyRemaining,
            adsRemainingHour: bucket.hourlyRemaining,
            torBalance: currentBalance,
            boostRate: boostRes.newRate ?? 0.704,
            lastAdAt: nowMs
        )

        stats.adsWatched += 1
        stats.adsRemainingToday = bucket.dailyRemaining
        stats.adsRemainingHour = bucket.hourlyRemaining
        stats.boostRate = boostRes.newRate ?? stats.boostRate
        if currentBalance > 0 { stats.torBalance = currentBalance }
        stats.lastAdAt = nowMs

        DatabaseManager.shared.upsertStats(stats)

        DatabaseManager.shared.insertLog(Log(
            accountId: accountId,
            level: .info,
            action: .adWatch,
            message: "Bước 3 OK: Boost thành công! Ad \(stats.adsWatched)/120, Rate: \(stats.boostRate), Hourly còn: \(bucket.hourlyRemaining)"
        ))

        // Enforce cooldown if cooldownRemainingMs > 0
        if bucket.cooldownRemainingMs > 0 {
            let cooldownSeconds = Double(bucket.cooldownRemainingMs) / 1000.0
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .info,
                action: .adWatch,
                message: "Cooldown \(cooldownSeconds)s theo server..."
            ))
            try? await Task.sleep(nanoseconds: UInt64(bucket.cooldownRemainingMs) * 1_000_000)
        }

        return bucket
    }
}
