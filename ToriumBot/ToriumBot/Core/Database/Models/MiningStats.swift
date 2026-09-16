import Foundation

/// Represents daily mining statistics, limits, and timers for an account.
public struct MiningStats: Codable, Identifiable, Equatable {
    public var id: Int64?
    public var accountId: Int64
    public var date: String              // Format: YYYY-MM-DD (UTC+7)
    public var adsWatched: Int           // Daily watched count (max 120)
    public var adsRemainingToday: Int    // Remaining daily allowance
    public var adsRemainingHour: Int     // Remaining hourly allowance (max 5)
    public var torBalance: Double        // Total TOR token balance
    public var boostRate: Double         // Current mining boost rate (e.g., 0.704)
    public var lastAdAt: Int64?          // Timestamp ms
    public var lastCheckinAt: Int64?     // Timestamp ms
    public var nextAdAt: Int64?          // Timestamp ms (scheduled next execution)
    public var nextCheckinAt: Int64?     // Timestamp ms (scheduled next execution)

    public init(
        id: Int64? = nil,
        accountId: Int64,
        date: String,
        adsWatched: Int = 0,
        adsRemainingToday: Int = 120,
        adsRemainingHour: Int = 5,
        torBalance: Double = 0.0,
        boostRate: Double = 0.0,
        lastAdAt: Int64? = nil,
        lastCheckinAt: Int64? = nil,
        nextAdAt: Int64? = nil,
        nextCheckinAt: Int64? = nil
    ) {
        self.id = id
        self.accountId = accountId
        self.date = date
        self.adsWatched = adsWatched
        self.adsRemainingToday = adsRemainingToday
        self.adsRemainingHour = adsRemainingHour
        self.torBalance = torBalance
        self.boostRate = boostRate
        self.lastAdAt = lastAdAt
        self.lastCheckinAt = lastCheckinAt
        self.nextAdAt = nextAdAt
        self.nextCheckinAt = nextCheckinAt
    }
}
