import Foundation

/// Handles exporting account credentials into standard pipe-delimited format and dispatching to Telegram
public final class BackupManager {
    public static let shared = BackupManager()

    private init() {}

    /// Exports all accounts to a formatted text file and sends it via Telegram Bot
    public func backupAllAccounts() async -> (success: Bool, message: String) {
        let accounts = DatabaseManager.shared.getAllAccounts()
        guard !accounts.isEmpty else {
            return (false, "Không có tài khoản nào trong database để backup.")
        }

        let lines = accounts.map { $0.backupLine }
        let content = lines.joined(separator: "\n")
        guard let fileData = content.data(using: .utf8) else {
            return (false, "Không thể mã hóa dữ liệu backup.")
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let dateStr = formatter.string(from: Date())
        let fileName = "toriumbot_backup_\(dateStr).txt"

        let caption = "📁 [ToriumBot] File backup toàn bộ \(accounts.count) accounts (\(dateStr) UTC+7)"
        let sent = await TelegramReporter.shared.sendDocument(data: fileData, filename: fileName, caption: caption)

        if sent {
            DatabaseManager.shared.insertLog(Log(
                level: .info,
                action: .general,
                message: "Đã tạo và gửi file backup \(fileName) (\(accounts.count) accounts) qua Telegram."
            ))
            return (true, "Đã gửi file backup (\(accounts.count) accounts) qua Telegram!")
        } else {
            DatabaseManager.shared.insertLog(Log(
                level: .error,
                action: .error,
                message: "Gửi file backup qua Telegram thất bại. Vui lòng kiểm tra cài đặt Telegram Bot."
            ))
            return (false, "Gửi file backup thất bại. Vui lòng kiểm tra cài đặt Bot Token và Chat ID.")
        }
    }

    /// Sends a single account's details via Telegram
    public func backupSingleAccount(account: Account) async -> (success: Bool, message: String) {
        let text = """
        📁 [ToriumBot] Backup Account đơn lẻ
        ━━━━━━━━━━━━━━━━━━━━
        \(account.backupLine)
        ━━━━━━━━━━━━━━━━━━━━
        ⏰ UTC+7
        """
        let sent = await TelegramReporter.shared.sendMessage(text: text)
        return (sent, sent ? "Đã gửi thông tin account qua Telegram." : "Gửi thất bại. Kiểm tra cài đặt Telegram.")
    }
}
