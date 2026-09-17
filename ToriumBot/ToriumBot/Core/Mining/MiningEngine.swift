import Foundation
import Network

/// Core automation engine orchestrating concurrent background mining, worker pool regulation, and network resilience
public final class MiningEngine {
    public static let shared = MiningEngine()

    public private(set) var isRunning: Bool = false
    private var isProcessing: Bool = false
    private var engineTimer: Timer?

    private let networkMonitor = NWPathMonitor()
    public private(set) var isNetworkAvailable: Bool = true

    private let processingQueue = DispatchQueue(label: "com.toriumbot.miningengine", attributes: .concurrent)
    private var activeTasks: [Int64: Task<Void, Never>] = [:]
    private let tasksLock = NSLock()

    private init() {
        setupNetworkMonitoring()
    }

    // MARK: - Network Resilience (Apple NWPathMonitor)

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            let available = (path.status == .satisfied)
            if self?.isNetworkAvailable != available {
                self?.isNetworkAvailable = available
                if available {
                    DatabaseManager.shared.insertLog(Log(
                        level: .info,
                        action: .general,
                        message: "🌐 Mạng Internet đã kết nối trở lại. Tự động tiếp tục chu trình cày."
                    ))
                } else {
                    DatabaseManager.shared.insertLog(Log(
                        level: .warn,
                        action: .general,
                        message: "⚠️ iPhone mất kết nối WiFi/4G! Tự động đóng băng các tác vụ cày ngầm."
                    ))
                }
            }
        }
        let queue = DispatchQueue(label: "com.toriumbot.networkmonitor")
        networkMonitor.start(queue: queue)
    }

    // MARK: - Engine Lifecycle

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        WorkerPoolManager.shared.reloadSettings()

        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "🚀 Mining Engine đã khởi động [Chế độ: \(WorkerPoolManager.shared.currentMode == .eco ? "Eco 3-5 workers" : "Turbo")]."
        ))

        TelegramReporter.shared.startPeriodicReporting()

        DispatchQueue.main.async { [weak self] in
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

    // MARK: - Active Account Query & Manual Trigger

    /// Checks if a specific account is actively executing a mining task right now
    public func isAccountMining(accountId: Int64) -> Bool {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        return activeTasks[accountId] != nil
    }

    /// Returns set of account IDs that are currently running background workers
    public func getActiveAccountIds() -> Set<Int64> {
        tasksLock.lock()
        defer { tasksLock.unlock() }
        return Set(activeTasks.keys)
    }

    /// Immediately forces a mining cycle (ad watch & checkin) for a specific account
    public func forceMineAccount(accountId: Int64) {
        guard let account = DatabaseManager.shared.getAccount(id: accountId), account.isActive, !account.isBanned else { return }
        tasksLock.lock()
        if activeTasks[accountId] != nil {
            tasksLock.unlock()
            return
        }
        tasksLock.unlock()

        let offset = AntiSybilProfiler.shared.calculateUtcOffsetMinutes(for: account)
        let todayDate = AntiSybilProfiler.shared.getLocalDateKey(offsetMinutes: offset)

        let task = Task.detached(priority: .userInitiated) {
            await WorkerPoolManager.shared.acquireWorkerSlot()
            defer {
                WorkerPoolManager.shared.releaseWorkerSlot()
                self.tasksLock.lock()
                self.activeTasks.removeValue(forKey: accountId)
                self.tasksLock.unlock()
            }
            await self.processAccount(account: account, adDue: true, checkinDue: true, todayDate: todayDate)
        }

        tasksLock.lock()
        activeTasks[accountId] = task
        tasksLock.unlock()
    }

    // MARK: - Account Evaluation Loop

    private var lastHousekeepingDate: String = ""

    private func checkHousekeeping() {
        let now = Date()
        let hour = Calendar.current.component(.hour, from: now)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: now)

        if hour == 3 && lastHousekeepingDate != today {
            lastHousekeepingDate = today
            DatabaseManager.shared.performDatabaseHousekeeping()
        }
    }

    private func evaluateAccounts() {
        guard isRunning, !isProcessing else { return }
        // Do not process accounts if entire device is offline
        guard isNetworkAvailable else { return }

        checkHousekeeping()

        isProcessing = true

        processingQueue.async { [weak self] in
            guard let self = self else { return }
            defer { self.isProcessing = false }

            let accounts = DatabaseManager.shared.getActiveAccounts()

            for account in accounts {
                guard let accountId = account.id else { continue }

                // Skip if this account is currently running a task
                self.tasksLock.lock()
                if self.activeTasks[accountId] != nil {
                    self.tasksLock.unlock()
                    continue
                }
                self.tasksLock.unlock()

                // Calculate today's date based on proxy offset
                let offset = AntiSybilProfiler.shared.calculateUtcOffsetMinutes(for: account)
                let todayDate = AntiSybilProfiler.shared.getLocalDateKey(offsetMinutes: offset)

                let stats = DatabaseManager.shared.getStats(accountId: accountId, date: todayDate)

                let adDue = Scheduler.isAdDue(stats: stats)
                let checkinDue = Scheduler.isCheckinDue(stats: stats)

                if adDue || checkinDue {
                    // Check if worker slot can be acquired according to WorkerPool mode
                    let task = Task.detached(priority: .utility) {
                        await WorkerPoolManager.shared.acquireWorkerSlot()
                        defer {
                            WorkerPoolManager.shared.releaseWorkerSlot()
                            self.tasksLock.lock()
                            self.activeTasks.removeValue(forKey: accountId)
                            self.tasksLock.unlock()
                        }

                        await self.processAccount(account: account, adDue: adDue, checkinDue: checkinDue, todayDate: todayDate)
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

        // Step 1: Proxy Verification with Auto-Failover to Backup Pool
        if let host = account.proxyHost, !host.isEmpty, account.proxyPort != nil {
            let proxyAlive = await ProxyManager.shared.verifyProxyWithFailover(account: account)
            if !proxyAlive {
                DatabaseManager.shared.insertLog(Log(
                    accountId: accountId,
                    level: .error,
                    action: .proxyChange,
                    message: "Proxy chết (\(host))! Tạm hoãn 30 phút cho account [\(account.email)]."
                ))
                TelegramReporter.shared.alertProxyDead(email: account.email, proxyHost: host, proxyPort: account.proxyPort ?? 0)
                return
            }
        }

        // Step 2: Perform Check-in if due
        if checkinDue {
            do {
                let checkinMgr = CheckInManager(account: account)
                _ = try await checkinMgr.performCheckIn()
            } catch let err as ToriumAPIError {
                await handleToriumError(err, account: account)
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
                await handleToriumError(err, account: account)
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

    // MARK: - Specialized Error Handling & Auto Re-Login

    private func handleToriumError(_ error: ToriumAPIError, account: Account) async {
        guard let accountId = account.id else { return }

        switch error {
        case .unauthorized:
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .warn,
                action: .login,
                message: "Token 401 Unauthorized [\(account.email)]. Bắt đầu quy trình Auto Re-Login..."
            ))

            // Attempt Auto Re-login
            let reloginSuccess = await AccountRegistrar.shared.performAutoRelogin(account: account)
            if !reloginSuccess {
                TelegramReporter.shared.alertTokenNeedsRefresh(email: account.email)
            }

        case .forbidden:
            DatabaseManager.shared.quarantineAccount(id: accountId, reason: "Response 403 Forbidden")
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
