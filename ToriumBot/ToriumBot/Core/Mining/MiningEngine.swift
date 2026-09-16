import Foundation

/// Core automation engine orchestrating concurrent background mining and check-ins
public final class MiningEngine {
    public static let shared = MiningEngine()

    public private(set) var isRunning: Bool = false
    private var isProcessing: Bool = false
    private var engineTimer: Timer?

    private let processingQueue = DispatchQueue(label: "com.toriumbot.miningengine", attributes: .concurrent)
    private var activeTasks: [Int64: Task<Void, Never>] = [:]
    private let tasksLock = NSLock()

    private init() {}

    // MARK: - Engine Lifecycle

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "🚀 Mining Engine đã khởi động."
        ))

        TelegramReporter.shared.startPeriodicReporting()

        DispatchQueue.main.async { [weak self] in
            // Tick every 15 seconds to evaluate due accounts
            self?.engineTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
                self?.evaluateAccounts()
            }
            self?.evaluateAccounts()
        }
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false
        engineTimer?.invalidate()
        engineTimer = nil

        tasksLock.lock()
        for (_, task) in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
        tasksLock.unlock()

        TelegramReporter.shared.stopPeriodicReporting()

        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "⏸ Mining Engine đã tạm dừng."
        ))
    }

    // MARK: - Account Evaluation Loop

    private func evaluateAccounts() {
        guard isRunning, !isProcessing else { return }
        isProcessing = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            let accounts = DatabaseManager.shared.getActiveAccounts()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
            let todayDate = formatter.string(from: Date())

            for account in accounts {
                guard let accountId = account.id else { continue }

                // Skip if this account is currently running a task
                self.tasksLock.lock()
                if self.activeTasks[accountId] != nil {
                    self.tasksLock.unlock()
                    continue
                }
                self.tasksLock.unlock()

                let stats = DatabaseManager.shared.getStats(accountId: accountId, date: todayDate)

                let adDue = Scheduler.isAdDue(stats: stats)
                let checkinDue = Scheduler.isCheckinDue(stats: stats)

                if adDue || checkinDue {
                    let task = Task.detached(priority: .utility) {
                        await self.processAccount(account: account, adDue: adDue, checkinDue: checkinDue, todayDate: todayDate)
                        self.tasksLock.lock()
                        self.activeTasks.removeValue(forKey: accountId)
                        self.tasksLock.unlock()
                    }

                    self.tasksLock.lock()
                    self.activeTasks[accountId] = task
                    self.tasksLock.unlock()
                }
            }
        }
    }

    // MARK: - Process Individual Account

    private func processAccount(account: Account, adDue: Bool, checkinDue: Bool, todayDate: String) async {
        guard let accountId = account.id else { return }

        // Step 1: Mandatory Proxy Verification
        if let host = account.proxyHost, !host.isEmpty, let port = account.proxyPort {
            let proxyAlive = await ProxyManager.shared.verifyProxy(account: account)
            if !proxyAlive {
                DatabaseManager.shared.insertLog(Log(
                    accountId: accountId,
                    level: .error,
                    action: .proxyChange,
                    message: "Proxy chết (\(host):\(port))! Bỏ qua account [\(account.email)]."
                ))
                TelegramReporter.shared.alertProxyDead(email: account.email, proxyHost: host, proxyPort: port)
                return // Do NOT send request if proxy is dead
            }
        }

        // Step 2: Perform Check-in if due
        if checkinDue {
            do {
                let checkinMgr = CheckInManager(account: account)
                _ = try await checkinMgr.performCheckIn()
            } catch let err as ToriumAPIError {
                handleToriumError(err, account: account)
            } catch {
                DatabaseManager.shared.insertLog(Log(
                    accountId: accountId,
                    level: .error,
                    action: .checkin,
                    message: "Lỗi check-in: \(error.localizedDescription)"
                ))
            }
        }

        // Step 3: Perform Ad Watch if due
        if adDue {
            do {
                let watcher = AdWatcher(account: account)
                let bucket = try await watcher.watchAd()

                // Calculate and record next ad schedule
                let intervalStr = DatabaseManager.shared.getSetting(key: "default_ad_interval_hours") ?? "2"
                let intervalHours = Double(intervalStr) ?? 2.0
                let humanDelayEnabled = DatabaseManager.shared.getSetting(key: "human_delay_enabled") == "true"

                let nextAdMs = Scheduler.calculateNextAdTimestamp(
                    bucket: bucket,
                    intervalHours: intervalHours,
                    humanDelayEnabled: humanDelayEnabled
                )

                if var stats = DatabaseManager.shared.getStats(accountId: accountId, date: todayDate) {
                    stats.nextAdAt = nextAdMs
                    DatabaseManager.shared.upsertStats(stats)
                }

            } catch let err as ToriumAPIError {
                handleToriumError(err, account: account)
            } catch {
                DatabaseManager.shared.insertLog(Log(
                    accountId: accountId,
                    level: .error,
                    action: .adWatch,
                    message: "Lỗi xem ad: \(error.localizedDescription)"
                ))
                TelegramReporter.shared.alertAccountError(email: account.email, errorMessage: error.localizedDescription)
            }
        }
    }

    // MARK: - Specialized Error Handling

    private func handleToriumError(_ error: ToriumAPIError, account: Account) {
        guard let accountId = account.id else { return }

        switch error {
        case .unauthorized:
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .error,
                action: .login,
                message: "Token 401 Unauthorized. Cần refresh token!"
            ))
            TelegramReporter.shared.alertTokenNeedsRefresh(email: account.email)

        case .forbidden:
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .error,
                action: .general,
                message: "Response 403 Forbidden. Account có thể bị ban!"
            ))
            var updated = account
            updated.isBanned = true
            DatabaseManager.shared.updateAccount(updated)
            TelegramReporter.shared.alertAccountBanned(email: account.email)

        default:
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .error,
                action: .general,
                message: error.localizedDescription
            ))
            TelegramReporter.shared.alertAccountError(email: account.email, errorMessage: error.localizedDescription)
        }
    }
}
