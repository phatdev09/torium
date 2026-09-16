import Foundation

/// Handles passive Telegram notifications, error alerts, and periodic status reports
public final class TelegramReporter {
    public static let shared = TelegramReporter()

    private let session = URLSession(configuration: .ephemeral)
    private var reportTimer: Timer?

    private init() {}

    // MARK: - Date Formatting Helper

    private func currentUTC7String() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600) // UTC+7
        return "\(formatter.string(from: Date())) (UTC+7)"
    }

    private func formatTimestampUTC7(_ timestampMs: Int64?) -> String {
        guard let ts = timestampMs, ts > 0 else { return "Chưa có" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts) / 1000.0)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm dd/MM"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        return formatter.string(from: date)
    }

    // MARK: - Telegram Bot API Core (with 3x Retry)

    public func sendMessage(text: String) async -> Bool {
        guard let token = DatabaseManager.shared.getSetting(key: "telegram_bot_token"), !token.isEmpty,
              let chatId = DatabaseManager.shared.getSetting(key: "telegram_chat_id"), !chatId.isEmpty else {
            return false
        }

        let endpoint = "https://api.telegram.org/bot\(token)/sendMessage"
        guard let url = URL(string: endpoint) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "chat_id": chatId,
            "text": text,
            "parse_mode": "HTML"
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: body) else { return false }
        request.httpBody = bodyData

        for attempt in 1...3 {
            do {
                let (data, response) = try await session.data(for: request)
                if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                    return true
                }
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        return false
    }

    public func sendDocument(data: Data, filename: String, caption: String = "") async -> Bool {
        guard let token = DatabaseManager.shared.getSetting(key: "telegram_bot_token"), !token.isEmpty,
              let chatId = DatabaseManager.shared.getSetting(key: "telegram_chat_id"), !chatId.isEmpty else {
            return false
        }

        let endpoint = "https://api.telegram.org/bot\(token)/sendDocument"
        guard let url = URL(string: endpoint) else { return false }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // chat_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatId)\r\n".data(using: .utf8)!)

        // caption field
        if !caption.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)
        }

        // document file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"document\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        for attempt in 1...3 {
            do {
                let (_, response) = try await session.data(for: request)
                if let httpRes = response as? HTTPURLResponse, (200...299).contains(httpRes.statusCode) {
                    return true
                }
            } catch {
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                }
            }
        }
        return false
    }

    // MARK: - Immediate Alert Templates

    public func alertAccountError(email: String, errorMessage: String) {
        let text = """
        🔴 [ToriumBot] Account bị lỗi
        📧 Email: \(email)
        ❌ Lỗi: \(errorMessage)
        🔄 Đã retry 3 lần, tất cả thất bại
        ⏰ \(currentUTC7String())
        """
        Task { _ = await sendMessage(text: text) }
    }

    public func alertProxyDead(email: String, proxyHost: String, proxyPort: Int) {
        let text = """
        ⚠️ [ToriumBot] Proxy chết
        📧 Account: \(email)
        🌐 Proxy: \(proxyHost):\(proxyPort)
        ⏰ \(currentUTC7String())
        """
        Task { _ = await sendMessage(text: text) }
    }

    public func alertAccountBanned(email: String) {
        let text = """
        🚫 [ToriumBot] Account có thể bị ban
        📧 Email: \(email)
        📋 Response: 403 Forbidden
        ⏰ \(currentUTC7String())
        """
        Task { _ = await sendMessage(text: text) }
    }

    public func alertTokenNeedsRefresh(email: String) {
        let text = """
        🔑 [ToriumBot] Token cần refresh
        📧 Email: \(email)
        📋 Response: 401 Unauthorized
        ⏰ \(currentUTC7String())
        """
        Task { _ = await sendMessage(text: text) }
    }

    // MARK: - Periodic Status Report

    public func sendPeriodicReport() async {
        let accounts = DatabaseManager.shared.getAllAccounts()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let todayDate = formatter.string(from: Date())

        let summary = DatabaseManager.shared.getTodaySummary(date: todayDate)

        var details = ""
        for acc in accounts {
            guard let accId = acc.id else { continue }
            let stats = DatabaseManager.shared.getStats(accountId: accId, date: todayDate)
            let balance = stats?.torBalance ?? 0.0
            let adsWatched = stats?.adsWatched ?? 0
            let rate = stats?.boostRate ?? 0.0
            let nextAdStr = formatTimestampUTC7(stats?.nextAdAt)
            let statusStr = acc.isBanned ? "Bị Ban" : (acc.isActive ? "Active" : "Paused")

            details += """
            📧 \(acc.email)
            💰 TOR Balance: \(String(format: "%.3f", balance))
            📺 Ad hôm nay: \(adsWatched)/120
            ⚡ Boost Rate: \(String(format: "%.3f", rate))
            🕐 Ad tiếp theo: \(nextAdStr)
            ✅ Trạng thái: \(statusStr)
            ━━━━━━━━━━━━━━━━━━━━\n
            """
        }

        let reportMessage = """
        📊 [ToriumBot] Báo cáo \(currentUTC7String())

        ✅ Active: \(summary.totalActive) accounts
        ❌ Lỗi: \(summary.errorAccounts) accounts

        📋 Chi tiết từng account:
        ━━━━━━━━━━━━━━━━━━━━
        \(details)
        """

        _ = await sendMessage(text: reportMessage)
    }

    // MARK: - Periodic Timer Management

    public func startPeriodicReporting() {
        reportTimer?.invalidate()
        let intervalHoursStr = DatabaseManager.shared.getSetting(key: "report_interval_hours") ?? "6"
        let intervalHours = Double(intervalHoursStr) ?? 6.0
        let intervalSeconds = max(intervalHours * 3600.0, 300.0) // Minimum 5 mins

        DispatchQueue.main.async { [weak self] in
            self?.reportTimer = Timer.scheduledTimer(withTimeInterval: intervalSeconds, repeats: true) { _ in
                Task {
                    await TelegramReporter.shared.sendPeriodicReport()
                }
            }
        }
    }

    public func stopPeriodicReporting() {
        reportTimer?.invalidate()
        reportTimer = nil
    }
}
