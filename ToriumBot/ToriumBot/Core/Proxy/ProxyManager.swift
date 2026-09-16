import Foundation

/// Verifies and manages proxy connectivity per account
public final class ProxyManager {
    public static let shared = ProxyManager()

    private init() {}

    /// Verifies if the account's configured proxy is alive and can reach Torium Network
    /// Timeout: 10 seconds
    public func verifyProxy(account: Account) async -> Bool {
        // If account has no proxy, it connects directly
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
                // Any response from api.torium.network (even 401/403/200) proves the proxy reached the server
                return httpRes.statusCode > 0
            }
            return false
        } catch {
            return false
        }
    }
}
