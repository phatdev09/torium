import Foundation
import SQLite3

public struct ProxyPoolItem: Codable, Identifiable {
    public var id: Int64?
    public var host: String
    public var port: Int
    public var username: String?
    public var password: String?
    public var proto: String
    public var isActive: Bool
    public var lastUsedAt: Int64?

    public init(
        id: Int64? = nil,
        host: String,
        port: Int,
        username: String? = nil,
        password: String? = nil,
        proto: String = "socks5",
        isActive: Bool = true,
        lastUsedAt: Int64? = nil
    ) {
        self.id = id
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.proto = proto
        self.isActive = isActive
        self.lastUsedAt = lastUsedAt
    }
}

/// Thread-safe SQLite Database Manager for ToriumBot
public final class DatabaseManager {
    public static let shared = DatabaseManager()

    private var db: OpaquePointer?
    private let dbQueue = DispatchQueue(label: "com.toriumbot.database", qos: .userInitiated)
    private let dbPath: String

    public var onNewLogAdded: ((Log) -> Void)?

    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent("toriumbot.db")
        self.dbPath = fileURL.path

        openDatabase()
        runMigrations()
        insertDefaultSettings()
    }

    deinit {
        if db != nil {
            sqlite3_close(db)
        }
    }

    // MARK: - Setup & Migrations

    private func openDatabase() {
        if sqlite3_open(dbPath, &db) != SQLITE_OK {
            print("ERROR: Unable to open database at \(dbPath)")
        } else {
            // Enable WAL mode for concurrent reads & crash resistance
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA journal_mode=WAL;", -1, &stmt, nil) == SQLITE_OK {
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    private func runMigrations() {
        let createAccountsTable = """
        CREATE TABLE IF NOT EXISTS accounts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT NOT NULL UNIQUE,
            password TEXT NOT NULL,
            bearer_token TEXT,
            clerk_id TEXT,
            device_id TEXT,
            proxy_host TEXT,
            proxy_port INTEGER,
            proxy_username TEXT,
            proxy_password TEXT,
            proxy_protocol TEXT,
            container_id TEXT,
            referral_code TEXT,
            is_active INTEGER DEFAULT 1,
            is_banned INTEGER DEFAULT 0,
            created_at INTEGER,
            last_seen_at INTEGER
        );
        """

        let createMiningStatsTable = """
        CREATE TABLE IF NOT EXISTS mining_stats (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER REFERENCES accounts(id) ON DELETE CASCADE,
            date TEXT NOT NULL,
            ads_watched INTEGER DEFAULT 0,
            ads_remaining_today INTEGER DEFAULT 120,
            ads_remaining_hour INTEGER DEFAULT 5,
            tor_balance REAL DEFAULT 0.0,
            boost_rate REAL DEFAULT 0.0,
            last_ad_at INTEGER,
            last_checkin_at INTEGER,
            next_ad_at INTEGER,
            next_checkin_at INTEGER,
            UNIQUE(account_id, date)
        );
        """

        let createLogsTable = """
        CREATE TABLE IF NOT EXISTS logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            account_id INTEGER REFERENCES accounts(id) ON DELETE SET NULL,
            level TEXT,
            action TEXT,
            message TEXT,
            created_at INTEGER
        );
        """

        let createSettingsTable = """
        CREATE TABLE IF NOT EXISTS settings (
            key TEXT PRIMARY KEY,
            value TEXT
        );
        """

        let createProxyPoolTable = """
        CREATE TABLE IF NOT EXISTS proxy_pool (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            host TEXT NOT NULL,
            port INTEGER NOT NULL,
            username TEXT,
            password TEXT,
            protocol TEXT DEFAULT 'socks5',
            is_active INTEGER DEFAULT 1,
            last_used_at INTEGER
        );
        """

        execute(query: createAccountsTable)
        // Migration: add referral_code to accounts if table already existed without it
        execute(query: "ALTER TABLE accounts ADD COLUMN referral_code TEXT;")
        execute(query: createMiningStatsTable)
        execute(query: createLogsTable)
        execute(query: createSettingsTable)
        execute(query: createProxyPoolTable)
    }

    private func insertDefaultSettings() {
        let defaults: [String: String] = [
            "telegram_bot_token": "",
            "telegram_chat_id": "",
            "report_interval_hours": "6",
            "timezone_offset": "420",
            "default_ad_interval_hours": "2",
            "human_delay_enabled": "true",
            "auto_restart_enabled": "true",
            "master_referral_code": "",
            "worker_mode": "eco",
            "max_concurrent_workers": "3",
            "sleep_simulator_enabled": "false",
            "sleep_start_hour": "1",
            "sleep_end_hour": "5",
            "x_ota_version": "0a9f87c3-0a5f-4ed5-aefd-7a9004875813",
            "x_app_version": "2.1.0",
            "max_ad_yield_enabled": "true"
        ]

        for (key, val) in defaults {
            if getSetting(key: key) == nil {
                setSetting(key: key, value: val)
            }
        }
    }

    private func execute(query: String) {
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, query, nil, nil, &errMsg) != SQLITE_OK {
            if let error = errMsg {
                sqlite3_free(error)
            }
        }
    }

    // MARK: - Account CRUD

    public func getAllAccounts() -> [Account] {
        return dbQueue.sync {
            var accounts: [Account] = []
            let query = "SELECT id, email, password, bearer_token, clerk_id, device_id, proxy_host, proxy_port, proxy_username, proxy_password, proxy_protocol, container_id, referral_code, is_active, is_banned, created_at, last_seen_at FROM accounts ORDER BY id ASC;"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    accounts.append(parseAccountRow(stmt: stmt))
                }
            }
            sqlite3_finalize(stmt)
            return accounts
        }
    }

    public func getActiveAccounts() -> [Account] {
        return dbQueue.sync {
            var accounts: [Account] = []
            let query = "SELECT id, email, password, bearer_token, clerk_id, device_id, proxy_host, proxy_port, proxy_username, proxy_password, proxy_protocol, container_id, referral_code, is_active, is_banned, created_at, last_seen_at FROM accounts WHERE is_active = 1 AND is_banned = 0 ORDER BY id ASC;"
            var stmt: OpaquePointer?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    accounts.append(parseAccountRow(stmt: stmt))
                }
            }
            sqlite3_finalize(stmt)
            return accounts
        }
    }

    public func getAccount(id: Int64) -> Account? {
        return dbQueue.sync {
            let query = "SELECT id, email, password, bearer_token, clerk_id, device_id, proxy_host, proxy_port, proxy_username, proxy_password, proxy_protocol, container_id, referral_code, is_active, is_banned, created_at, last_seen_at FROM accounts WHERE id = ? LIMIT 1;"
            var stmt: OpaquePointer?
            var account: Account?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, id)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    account = parseAccountRow(stmt: stmt)
                }
            }
            sqlite3_finalize(stmt)
            return account
        }
    }

    public func getAccount(email: String) -> Account? {
        return dbQueue.sync {
            let query = "SELECT id, email, password, bearer_token, clerk_id, device_id, proxy_host, proxy_port, proxy_username, proxy_password, proxy_protocol, container_id, referral_code, is_active, is_banned, created_at, last_seen_at FROM accounts WHERE email = ? LIMIT 1;"
            var stmt: OpaquePointer?
            var account: Account?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (email as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    account = parseAccountRow(stmt: stmt)
                }
            }
            sqlite3_finalize(stmt)
            return account
        }
    }

    @discardableResult
    public func insertAccount(_ acc: Account) -> Int64? {
        return dbQueue.sync {
            let query = """
            INSERT INTO accounts (email, password, bearer_token, clerk_id, device_id, proxy_host, proxy_port, proxy_username, proxy_password, proxy_protocol, container_id, referral_code, is_active, is_banned, created_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            var stmt: OpaquePointer?
            var insertedId: Int64?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (acc.email as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (acc.password as NSString).utf8String, -1, nil)
                bindOptionalText(stmt, 3, acc.bearerToken)
                bindOptionalText(stmt, 4, acc.clerkId)
                bindOptionalText(stmt, 5, acc.deviceId)
                bindOptionalText(stmt, 6, acc.proxyHost)
                if let port = acc.proxyPort {
                    sqlite3_bind_int(stmt, 7, Int32(port))
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                bindOptionalText(stmt, 8, acc.proxyUsername)
                bindOptionalText(stmt, 9, acc.proxyPassword)
                bindOptionalText(stmt, 10, acc.proxyProtocol)
                bindOptionalText(stmt, 11, acc.containerId)
                bindOptionalText(stmt, 12, acc.referralCode)
                sqlite3_bind_int(stmt, 13, acc.isActive ? 1 : 0)
                sqlite3_bind_int(stmt, 14, acc.isBanned ? 1 : 0)
                sqlite3_bind_int64(stmt, 15, acc.createdAt)
                sqlite3_bind_int64(stmt, 16, acc.lastSeenAt)

                if sqlite3_step(stmt) == SQLITE_DONE {
                    insertedId = sqlite3_last_insert_rowid(db)
                }
            }
            sqlite3_finalize(stmt)
            return insertedId
        }
    }

    public func updateAccount(_ acc: Account) {
        guard let id = acc.id else { return }
        dbQueue.sync {
            let query = """
            UPDATE accounts SET email = ?, password = ?, bearer_token = ?, clerk_id = ?, device_id = ?,
            proxy_host = ?, proxy_port = ?, proxy_username = ?, proxy_password = ?, proxy_protocol = ?,
            container_id = ?, referral_code = ?, is_active = ?, is_banned = ?, last_seen_at = ? WHERE id = ?;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (acc.email as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (acc.password as NSString).utf8String, -1, nil)
                bindOptionalText(stmt, 3, acc.bearerToken)
                bindOptionalText(stmt, 4, acc.clerkId)
                bindOptionalText(stmt, 5, acc.deviceId)
                bindOptionalText(stmt, 6, acc.proxyHost)
                if let port = acc.proxyPort {
                    sqlite3_bind_int(stmt, 7, Int32(port))
                } else {
                    sqlite3_bind_null(stmt, 7)
                }
                bindOptionalText(stmt, 8, acc.proxyUsername)
                bindOptionalText(stmt, 9, acc.proxyPassword)
                bindOptionalText(stmt, 10, acc.proxyProtocol)
                bindOptionalText(stmt, 11, acc.containerId)
                bindOptionalText(stmt, 12, acc.referralCode)
                sqlite3_bind_int(stmt, 13, acc.isActive ? 1 : 0)
                sqlite3_bind_int(stmt, 14, acc.isBanned ? 1 : 0)
                sqlite3_bind_int64(stmt, 15, acc.lastSeenAt)
                sqlite3_bind_int64(stmt, 16, id)

                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func updateTokens(id: Int64, token: String, clerkId: String, deviceId: String) {
        dbQueue.sync {
            let query = "UPDATE accounts SET bearer_token = ?, clerk_id = ?, device_id = ?, last_seen_at = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (token as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (clerkId as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (deviceId as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 4, Int64(Date().timeIntervalSince1970 * 1000))
                sqlite3_bind_int64(stmt, 5, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func updateProxy(id: Int64, host: String?, port: Int?, username: String?, password: String?, proto: String?) {
        dbQueue.sync {
            let query = "UPDATE accounts SET proxy_host = ?, proxy_port = ?, proxy_username = ?, proxy_password = ?, proxy_protocol = ? WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                bindOptionalText(stmt, 1, host)
                if let p = port {
                    sqlite3_bind_int(stmt, 2, Int32(p))
                } else {
                    sqlite3_bind_null(stmt, 2)
                }
                bindOptionalText(stmt, 3, username)
                bindOptionalText(stmt, 4, password)
                bindOptionalText(stmt, 5, proto)
                sqlite3_bind_int64(stmt, 6, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func deleteAccount(id: Int64) {
        dbQueue.sync {
            let query = "DELETE FROM accounts WHERE id = ?;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, id)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - MiningStats CRUD

    public func getStats(accountId: Int64, date: String) -> MiningStats? {
        return dbQueue.sync {
            let query = "SELECT id, account_id, date, ads_watched, ads_remaining_today, ads_remaining_hour, tor_balance, boost_rate, last_ad_at, last_checkin_at, next_ad_at, next_checkin_at FROM mining_stats WHERE account_id = ? AND date = ? LIMIT 1;"
            var stmt: OpaquePointer?
            var stats: MiningStats?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, accountId)
                sqlite3_bind_text(stmt, 2, (date as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    stats = parseMiningStatsRow(stmt: stmt)
                }
            }
            sqlite3_finalize(stmt)
            return stats
        }
    }

    public func upsertStats(_ stats: MiningStats) {
        dbQueue.sync {
            let query = """
            INSERT INTO mining_stats (account_id, date, ads_watched, ads_remaining_today, ads_remaining_hour, tor_balance, boost_rate, last_ad_at, last_checkin_at, next_ad_at, next_checkin_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(account_id, date) DO UPDATE SET
                ads_watched = excluded.ads_watched,
                ads_remaining_today = excluded.ads_remaining_today,
                ads_remaining_hour = excluded.ads_remaining_hour,
                tor_balance = excluded.tor_balance,
                boost_rate = excluded.boost_rate,
                last_ad_at = excluded.last_ad_at,
                last_checkin_at = excluded.last_checkin_at,
                next_ad_at = excluded.next_ad_at,
                next_checkin_at = excluded.next_checkin_at;
            """
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_int64(stmt, 1, stats.accountId)
                sqlite3_bind_text(stmt, 2, (stats.date as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 3, Int32(stats.adsWatched))
                sqlite3_bind_int(stmt, 4, Int32(stats.adsRemainingToday))
                sqlite3_bind_int(stmt, 5, Int32(stats.adsRemainingHour))
                sqlite3_bind_double(stmt, 6, stats.torBalance)
                sqlite3_bind_double(stmt, 7, stats.boostRate)
                bindOptionalInt64(stmt, 8, stats.lastAdAt)
                bindOptionalInt64(stmt, 9, stats.lastCheckinAt)
                bindOptionalInt64(stmt, 10, stats.nextAdAt)
                bindOptionalInt64(stmt, 11, stats.nextCheckinAt)

                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Logs CRUD

    public func insertLog(_ log: Log) {
        dbQueue.sync {
            let query = "INSERT INTO logs (account_id, level, action, message, created_at) VALUES (?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                if let aid = log.accountId {
                    sqlite3_bind_int64(stmt, 1, aid)
                } else {
                    sqlite3_bind_null(stmt, 1)
                }
                sqlite3_bind_text(stmt, 2, (log.level.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 3, (log.action.rawValue as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 4, (log.message as NSString).utf8String, -1, nil)
                sqlite3_bind_int64(stmt, 5, log.createdAt)

                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)

            onNewLogAdded?(log)
        }
    }

    public func getRecentLogs(limit: Int = 100, level: LogLevel? = nil) -> [Log] {
        return dbQueue.sync {
            var logs: [Log] = []
            var query = "SELECT id, account_id, level, action, message, created_at FROM logs"
            if let lvl = level {
                query += " WHERE level = '\(lvl.rawValue)'"
            }
            query += " ORDER BY id DESC LIMIT \(limit);"

            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    logs.append(parseLogRow(stmt: stmt))
                }
            }
            sqlite3_finalize(stmt)
            return logs
        }
    }

    public func clearLogs() {
        dbQueue.sync {
            execute(query: "DELETE FROM logs;")
        }
    }

    // MARK: - Proxy Pool CRUD

    public func getAvailableBackupProxy() -> ProxyPoolItem? {
        return dbQueue.sync {
            let query = "SELECT id, host, port, username, password, protocol, is_active, last_used_at FROM proxy_pool WHERE is_active = 1 ORDER BY last_used_at ASC LIMIT 1;"
            var stmt: OpaquePointer?
            var item: ProxyPoolItem?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                if sqlite3_step(stmt) == SQLITE_ROW {
                    let id = sqlite3_column_int64(stmt, 0)
                    let host = String(cString: sqlite3_column_text(stmt, 1)!)
                    let port = Int(sqlite3_column_int(stmt, 2))
                    let user = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
                    let pass = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
                    let proto = String(cString: sqlite3_column_text(stmt, 5)!)
                    let isActive = sqlite3_column_int(stmt, 6) == 1
                    let lastUsed = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? sqlite3_column_int64(stmt, 7) : nil
                    item = ProxyPoolItem(id: id, host: host, port: port, username: user, password: pass, proto: proto, isActive: isActive, lastUsedAt: lastUsed)
                }
            }
            sqlite3_finalize(stmt)
            return item
        }
    }

    public func insertBackupProxy(_ item: ProxyPoolItem) {
        dbQueue.sync {
            let query = "INSERT INTO proxy_pool (host, port, username, password, protocol, is_active, last_used_at) VALUES (?, ?, ?, ?, ?, ?, ?);"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (item.host as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 2, Int32(item.port))
                bindOptionalText(stmt, 3, item.username)
                bindOptionalText(stmt, 4, item.password)
                sqlite3_bind_text(stmt, 5, (item.proto as NSString).utf8String, -1, nil)
                sqlite3_bind_int(stmt, 6, item.isActive ? 1 : 0)
                bindOptionalInt64(stmt, 7, item.lastUsedAt)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Settings CRUD

    public func getSetting(key: String) -> String? {
        return dbQueue.sync {
            let query = "SELECT value FROM settings WHERE key = ? LIMIT 1;"
            var stmt: OpaquePointer?
            var val: String?

            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                if sqlite3_step(stmt) == SQLITE_ROW {
                    if let text = sqlite3_column_text(stmt, 0) {
                        val = String(cString: text)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return val
        }
    }

    public func setSetting(key: String, value: String) {
        dbQueue.sync {
            let query = "INSERT INTO settings (key, value) VALUES (?, ?) ON CONFLICT(key) DO UPDATE SET value = excluded.value;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
                sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)
                sqlite3_step(stmt)
            }
            sqlite3_finalize(stmt)
        }
    }

    public func getAllSettings() -> [String: String] {
        return dbQueue.sync {
            var dict: [String: String] = [:]
            let query = "SELECT key, value FROM settings;"
            var stmt: OpaquePointer?
            if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let kStr = sqlite3_column_text(stmt, 0), let vStr = sqlite3_column_text(stmt, 1) {
                        dict[String(cString: kStr)] = String(cString: vStr)
                    }
                }
            }
            sqlite3_finalize(stmt)
            return dict
        }
    }

    // MARK: - Parsing Helpers

    private func parseAccountRow(stmt: OpaquePointer?) -> Account {
        let id = sqlite3_column_int64(stmt, 0)
        let email = String(cString: sqlite3_column_text(stmt, 1)!)
        let password = String(cString: sqlite3_column_text(stmt, 2)!)
        let bearerToken = sqlite3_column_text(stmt, 3).map { String(cString: $0) }
        let clerkId = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let deviceId = sqlite3_column_text(stmt, 5).map { String(cString: $0) }
        let proxyHost = sqlite3_column_text(stmt, 6).map { String(cString: $0) }
        let proxyPort = sqlite3_column_type(stmt, 7) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 7)) : nil
        let proxyUsername = sqlite3_column_text(stmt, 8).map { String(cString: $0) }
        let proxyPassword = sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        let proxyProtocol = sqlite3_column_text(stmt, 10).map { String(cString: $0) }
        let containerId = sqlite3_column_text(stmt, 11).map { String(cString: $0) }
        let referralCode = sqlite3_column_text(stmt, 12).map { String(cString: $0) }
        let isActive = sqlite3_column_int(stmt, 13) == 1
        let isBanned = sqlite3_column_int(stmt, 14) == 1
        let createdAt = sqlite3_column_int64(stmt, 15)
        let lastSeenAt = sqlite3_column_int64(stmt, 16)

        return Account(
            id: id,
            email: email,
            password: password,
            bearerToken: bearerToken,
            clerkId: clerkId,
            deviceId: deviceId,
            proxyHost: proxyHost,
            proxyPort: proxyPort,
            proxyUsername: proxyUsername,
            proxyPassword: proxyPassword,
            proxyProtocol: proxyProtocol,
            containerId: containerId,
            referralCode: referralCode,
            isActive: isActive,
            isBanned: isBanned,
            createdAt: createdAt,
            lastSeenAt: lastSeenAt
        )
    }

    private func parseMiningStatsRow(stmt: OpaquePointer?) -> MiningStats {
        let id = sqlite3_column_int64(stmt, 0)
        let accountId = sqlite3_column_int64(stmt, 1)
        let date = String(cString: sqlite3_column_text(stmt, 2)!)
        let adsWatched = Int(sqlite3_column_int(stmt, 3))
        let adsRemainingToday = Int(sqlite3_column_int(stmt, 4))
        let adsRemainingHour = Int(sqlite3_column_int(stmt, 5))
        let torBalance = sqlite3_column_double(stmt, 6)
        let boostRate = sqlite3_column_double(stmt, 7)
        let lastAdAt = sqlite3_column_type(stmt, 8) != SQLITE_NULL ? sqlite3_column_int64(stmt, 8) : nil
        let lastCheckinAt = sqlite3_column_type(stmt, 9) != SQLITE_NULL ? sqlite3_column_int64(stmt, 9) : nil
        let nextAdAt = sqlite3_column_type(stmt, 10) != SQLITE_NULL ? sqlite3_column_int64(stmt, 10) : nil
        let nextCheckinAt = sqlite3_column_type(stmt, 11) != SQLITE_NULL ? sqlite3_column_int64(stmt, 11) : nil

        return MiningStats(
            id: id,
            accountId: accountId,
            date: date,
            adsWatched: adsWatched,
            adsRemainingToday: adsRemainingToday,
            adsRemainingHour: adsRemainingHour,
            torBalance: torBalance,
            boostRate: boostRate,
            lastAdAt: lastAdAt,
            lastCheckinAt: lastCheckinAt,
            nextAdAt: nextAdAt,
            nextCheckinAt: nextCheckinAt
        )
    }

    private func parseLogRow(stmt: OpaquePointer?) -> Log {
        let id = sqlite3_column_int64(stmt, 0)
        let accountId = sqlite3_column_type(stmt, 1) != SQLITE_NULL ? sqlite3_column_int64(stmt, 1) : nil
        let levelStr = String(cString: sqlite3_column_text(stmt, 2)!)
        let actionStr = String(cString: sqlite3_column_text(stmt, 3)!)
        let message = String(cString: sqlite3_column_text(stmt, 4)!)
        let createdAt = sqlite3_column_int64(stmt, 5)

        return Log(
            id: id,
            accountId: accountId,
            level: LogLevel(rawValue: levelStr) ?? .info,
            action: LogAction(rawValue: actionStr) ?? .general,
            message: message,
            createdAt: createdAt
        )
    }

    private func bindOptionalText(_ stmt: OpaquePointer?, _ index: Int32, _ val: String?) {
        if let v = val {
            sqlite3_bind_text(stmt, index, (v as NSString).utf8String, -1, nil)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalInt64(_ stmt: OpaquePointer?, _ index: Int32, _ val: Int64?) {
        if let v = val {
            sqlite3_bind_int64(stmt, index, v)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }
}
