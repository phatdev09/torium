import Foundation

public enum LogLevel: String, Codable, CaseIterable {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

public enum LogAction: String, Codable, CaseIterable {
    case adWatch = "AD_WATCH"
    case checkin = "CHECKIN"
    case login = "LOGIN"
    case proxyChange = "PROXY_CHANGE"
    case error = "ERROR"
    case general = "GENERAL"
}

/// Represents an operational log entry stored in the database.
public struct Log: Codable, Identifiable, Equatable {
    public var id: Int64?
    public var accountId: Int64?
    public var level: LogLevel
    public var action: LogAction
    public var message: String
    public var createdAt: Int64          // Timestamp ms

    public init(
        id: Int64? = nil,
        accountId: Int64? = nil,
        level: LogLevel = .info,
        action: LogAction = .general,
        message: String,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.accountId = accountId
        self.level = level
        self.action = action
        self.message = message
        self.createdAt = createdAt
    }

    /// Formatted date string for UI display
    public var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdAt) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600) // UTC+7
        return formatter.string(from: date)
    }
}
