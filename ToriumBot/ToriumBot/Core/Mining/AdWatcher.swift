import Foundation

/// Executes the strict 3-step rewarded ad watch flow with Max Airdrop Yield & Anti-Sybil humanization
public final class AdWatcher {
    private let account: Account
    private let apiClient: ToriumAPIClient

    public init(account: Account) {
        self.account = account
        self.apiClient = ToriumAPIClient(account: account)
    }

    /// Executes complete ad flow. In Max Yield mode, watches all available hourly slots with human jitter
    public func watchAd() async throws -> BucketInfo {
        guard let accountId = account.id else {
            throw ToriumAPIError.networkError("Account ID missing")
        }

        // Check Night Sleep Simulator
        if AntiSybilProfiler.shared.isSleepTimeNow() {
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .info,
                action: .adWatch,
                message: "🌙 Chế độ Mô Phỏng Giấc Ngủ đang bật. Tạm hoãn xem ad cho [\(account.email)] đến sáng."
            ))
            return BucketInfo(hourlyRemaining: 0, hourlyResetAt: nil, dailyRemaining: 120, dailyCap: 120, hourlyCap: 5, cooldownEndsAt: nil, cooldownRemainingMs: 0)
        }

        let isMaxYieldEnabled = DatabaseManager.shared.getSetting(key: "max_ad_yield_enabled") != "false"
        var lastBucket: BucketInfo?

        repeat {
            lastBucket = try await executeSingleAdStep()
            guard let bucket = lastBucket else { break }

            // If max yield is disabled, or hourly remaining is exhausted, or daily limit reached, break
            if !isMaxYieldEnabled || bucket.hourlyRemaining <= 0 || bucket.dailyRemaining <= 0 {
                break
            }

            // Cooldown 10s + 5-15s random human jitter before next ad in the same hour
            let jitterSeconds = Int.random(in: 5...15)
            let totalWaitMs = max(bucket.cooldownRemainingMs, 10000) + (jitterSeconds * 1000)
            let waitSeconds = Double(totalWaitMs) / 1000.0

            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .info,
                action: .adWatch,
                message: "Max Yield: Còn \(bucket.hourlyRemaining) ad trong giờ này. Giãn cách an toàn \(String(format: "%.1f", waitSeconds))s trước ad tiếp theo..."
            ))

            try? await Task.sleep(nanoseconds: UInt64(totalWaitMs) * 1_000_000)

        } while isMaxYieldEnabled && (lastBucket?.hourlyRemaining ?? 0) > 0

        return lastBucket ?? BucketInfo(hourlyRemaining: 0, hourlyResetAt: nil, dailyRemaining: 120, dailyCap: 120, hourlyCap: 5, cooldownEndsAt: nil, cooldownRemainingMs: 0)
    }

    private func executeSingleAdStep() async throws -> BucketInfo {
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

        // Simulation delay for video playback (3-5s)
        try? await Task.sleep(nanoseconds: UInt64.random(in: 3_000_000_000...5_000_000_000))

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

        // --- STEP 3: Claim Boost ---
        let boostRes = try await apiClient.boostMining(verifiedIntentId: intentId)
        let bucket = boostRes.bucket
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        // Wallet Balance check
        let balanceRes = try? await apiClient.getWalletBalance()
        let currentBalance = balanceRes?.effectiveBalance ?? 0.0

        let offsetMinutes = AntiSybilProfiler.shared.calculateUtcOffsetMinutes(for: account)
        let todayDate = AntiSybilProfiler.shared.getLocalDateKey(offsetMinutes: offsetMinutes)

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
            message: "Bước 3 OK: Boost thành công! Ad \(stats.adsWatched)/120, Rate: \(stats.boostRate), Giờ này còn: \(bucket.hourlyRemaining)"
        ))

        return bucket
    }
}
