import Foundation

/// Verifies and manages proxy connectivity per account with retry, cooldown, and backup pool failover
public final class ProxyManager {
    public static let shared = ProxyManager()

    // Tracks cooldown timestamps for dead proxies: accountId -> timestamp ms
    private var proxyCooldowns: [Int64: Int64] = [:]
    private let lock = NSLock()

    private init() {}

    /// Checks if an account is currently in a 30-minute proxy cooldown window
    public func isProxyInCooldown(accountId: Int64) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let until = proxyCooldowns[accountId] {
            let now = Int64(Date().timeIntervalSince1970 * 1000)
            if now < until {
                return true
            } else {
                proxyCooldowns.removeValue(forKey: accountId)
            }
        }
        return false
    }

    /// Sets a 30-minute cooldown on a dead proxy
    public func setProxyCooldown(accountId: Int64, minutes: Int = 30) {
        lock.lock()
        defer { lock.unlock() }
        let until = Int64(Date().timeIntervalSince1970 * 1000) + Int64(minutes * 60 * 1000)
        proxyCooldowns[accountId] = until
    }

    /// Verifies if the account's configured proxy is alive with 2x retry and failover to Backup Proxy Pool
    public func verifyProxyWithFailover(account: Account) async -> Bool {
        guard let accountId = account.id else { return true }

        // Skip testing if in cooldown
        if isProxyInCooldown(accountId: accountId) {
            return false
        }

        // Attempt 1
        var isAlive = await testSinglePing(account: account)
        if !isAlive {
            // Attempt 2 after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            isAlive = await testSinglePing(account: account)
        }

        if isAlive {
            return true
        }

        // Proxy is confirmed dead. Check if a backup proxy is available in database pool
        if let backup = DatabaseManager.shared.getAvailableBackupProxy() {
            DatabaseManager.shared.insertLog(Log(
                accountId: accountId,
                level: .warn,
                action: .proxyChange,
                message: "Proxy cũ chết (\(account.proxyHost ?? "")). Tự động hoán đổi sang Backup Proxy (\(backup.host):\(backup.port))."
            ))

            var updated = account
            updated.proxyHost = backup.host
            updated.proxyPort = backup.port
            updated.proxyUsername = backup.username
            updated.proxyPassword = backup.password
            updated.proxyProtocol = backup.proto
            DatabaseManager.shared.updateAccount(updated)

            // Test backup proxy
            let backupAlive = await testSinglePing(account: updated)
            if backupAlive {
                return true
            }
        }

        // No backup or backup also dead: trigger 30m cooldown
        setProxyCooldown(accountId: accountId, minutes: 30)
        return false
    }

    private func testSinglePing(account: Account) async -> Bool {
        guard let host = account.proxyHost, !host.isEmpty, account.proxyPort != nil else {
            return true
        }

        let session = ProxyURLSession.createSession(account: account, timeoutInterval: 10.0)
        guard let url = URL(string: "https://api.torium.network/v1/mining/v2/session-status") else {
            return false
        }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("okhttp/4.12.0", forHTTPHeaderField: "User-Agent")

        if let token = account.bearerToken, !token.isEmpty {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (_, response) = try await session.data(for: req)
            if let httpRes = response as? HTTPURLResponse {
                return httpRes.statusCode > 0
            }
            return false
        } catch {
            return false
        }
    }
}
