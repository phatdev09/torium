import Foundation
import CFNetwork

/// Custom session delegate to handle HTTP 407 Proxy Authentication challenges
final class ProxyAuthDelegate: NSObject, URLSessionTaskDelegate {
    private let account: Account

    init(account: Account) {
        self.account = account
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.isProxy ||
           challenge.protectionSpace.authenticationMethod == "NSURLAuthenticationMethodHTTPProxy" ||
           challenge.protectionSpace.authenticationMethod == "NSURLAuthenticationMethodHTTPSProxy" {
            if let user = account.proxyUsername, let pass = account.proxyPassword, !user.isEmpty {
                let credential = URLCredential(user: user, password: pass, persistence: .none)
                completionHandler(.useCredential, credential)
                return
            }
        }
        completionHandler(.performDefaultHandling, nil)
    }
}

/// Factory and utility for creating URLSessions routed cleanly through account-specific proxies with zero DNS leaks
public final class ProxyURLSession {

    /// Creates a URLSession configured with proxy settings and authentication handler
    public static func createSession(
        account: Account,
        timeoutInterval: TimeInterval = 30.0
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval

        guard let host = account.proxyHost, !host.isEmpty, let port = account.proxyPort else {
            return URLSession(configuration: configuration)
        }

        var proxyDict: [AnyHashable: Any] = [:]
        let proto = (account.proxyProtocol ?? "socks5").lowercased()

        let effectiveUser = getEffectiveUsername(for: account)

        if proto == "socks4" || proto == "socks5" || proto == "socks" {
            proxyDict[kCFStreamPropertySOCKSProxyHost as String] = host
            proxyDict[kCFStreamPropertySOCKSProxyPort as String] = port
            proxyDict[kCFStreamPropertySOCKSVersion as String] = (proto == "socks4") ? kCFStreamSocketSOCKSVersion4 : kCFStreamSocketSOCKSVersion5

            if let user = effectiveUser, !user.isEmpty {
                proxyDict[kCFStreamPropertySOCKSUser as String] = user
            }
            if let pass = account.proxyPassword, !pass.isEmpty {
                proxyDict[kCFStreamPropertySOCKSPassword as String] = pass
            }
        } else {
            // HTTP / HTTPS
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = port

            proxyDict["HTTPSEnable"] = 1
            proxyDict["HTTPSProxy"] = host
            proxyDict["HTTPSPort"] = port

            if let user = effectiveUser, !user.isEmpty {
                proxyDict[kCFProxyUsernameKey as String] = user
            }
            if let pass = account.proxyPassword, !pass.isEmpty {
                proxyDict[kCFProxyPasswordKey as String] = pass
            }
        }

        configuration.connectionProxyDictionary = proxyDict
        let delegate = ProxyAuthDelegate(account: account)
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    /// Generates sticky session username for rotating proxies (e.g. user_session-acc12_lifetime-30m)
    public static func getEffectiveUsername(for account: Account) -> String? {
        guard let user = account.proxyUsername, !user.isEmpty else { return nil }
        if user.contains("session") { return user }
        if let aid = account.id {
            return "\(user)_session-acc\(aid)_lifetime-30m"
        }
        return user
    }
}
