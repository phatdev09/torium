import Foundation

/// Per-account scheduler managing ad watch cycles and check-in schedules
public final class Scheduler {

    /// Determines the next ad timestamp based on bucket state and user settings
    public static func calculateNextAdTimestamp(
        bucket: BucketInfo,
        intervalHours: Double = 2.0,
        humanDelayEnabled: Bool = true
    ) -> Int64 {
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)

        // Case 1: Reached daily cap of 120 ads -> schedule at 00:01 next day UTC+7
        if bucket.dailyRemaining <= 0 {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
            if let tomorrow = cal.date(byAdding: .day, value: 1, to: Date()),
               let startOfTomorrow = cal.date(bySettingHour: 0, minute: 1, second: 0, of: tomorrow) {
                return Int64(startOfTomorrow.timeIntervalSince1970 * 1000)
            }
            return nowMs + 24 * 3600 * 1000
        }

        // Case 2: Reached hourly cap of 5 ads -> schedule at hourlyResetAt
        if bucket.hourlyRemaining <= 0 {
            if let resetAt = bucket.hourlyResetAt, resetAt > nowMs {
                return resetAt + (humanDelayEnabled ? Int64(Int.random(in: 5...30) * 1000) : 0)
            }
            return nowMs + 60 * 60 * 1000
        }

        // Case 3: Still has hourlyRemaining (> 0).
        // Wait user interval (e.g. 2 hours) or cooldown + human delay
        var delayMs = Int64(intervalHours * 3600 * 1000)
        if humanDelayEnabled {
            let randomSec = Int.random(in: 10...60)
            delayMs += Int64(randomSec * 1000)
        }

        return nowMs + delayMs
    }

    /// Checks whether an ad execution is currently due
    public static func isAdDue(stats: MiningStats?) -> Bool {
        guard let s = stats else { return true }
        guard let nextAdAt = s.nextAdAt else { return true }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        return nowMs >= nextAdAt
    }

    /// Checks whether a check-in is currently due
    public static func isCheckinDue(stats: MiningStats?) -> Bool {
        guard let s = stats else { return true }
        guard let nextCheckinAt = s.nextCheckinAt else { return true }
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        return nowMs >= nextCheckinAt
    }
}
