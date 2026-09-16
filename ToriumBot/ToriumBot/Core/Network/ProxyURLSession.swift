import Foundation
import CFNetwork

/// Factory and utility for creating URLSessions routed through account-specific proxies
public final class ProxyURLSession {

    /// Creates a URLSession configured with proxy settings for an Account
    public static func createSession(
        account: Account,
        timeoutInterval: TimeInterval = 30.0
    ) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval

        guard let host = account.proxyHost, !host.isEmpty, let port = account.proxyPort else {
            // Direct connection if no proxy configured
            return URLSession(configuration: configuration)
        }

        var proxyDict: [AnyHashable: Any] = [:]
        let proto = (account.proxyProtocol ?? "socks5").lowercased()

        if proto == "socks4" || proto == "socks5" || proto == "socks" {
            // Configure SOCKS Proxy
            proxyDict[kCFStreamPropertySOCKSProxyHost as String] = host
            proxyDict[kCFStreamPropertySOCKSProxyPort as String] = port
            proxyDict[kCFStreamPropertySOCKSVersion as String] = (proto == "socks4") ? kCFStreamSocketSOCKSVersion4 : kCFStreamSocketSOCKSVersion5

            if let user = account.proxyUsername, !user.isEmpty {
                proxyDict[kCFStreamPropertySOCKSUser as String] = user
            }
            if let pass = account.proxyPassword, !pass.isEmpty {
                proxyDict[kCFStreamPropertySOCKSPassword as String] = pass
            }
        } else if proto == "https" {
            // Configure HTTPS Proxy
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = port

            proxyDict["HTTPSEnable"] = 1
            proxyDict["HTTPSProxy"] = host
            proxyDict["HTTPSPort"] = port

            if let user = account.proxyUsername, !user.isEmpty {
                proxyDict[kCFProxyUsernameKey as String] = user
            }
            if let pass = account.proxyPassword, !pass.isEmpty {
                proxyDict[kCFProxyPasswordKey as String] = pass
            }
        } else {
            // Default: HTTP Proxy
            proxyDict[kCFNetworkProxiesHTTPEnable as String] = 1
            proxyDict[kCFNetworkProxiesHTTPProxy as String] = host
            proxyDict[kCFNetworkProxiesHTTPPort as String] = port

            if let user = account.proxyUsername, !user.isEmpty {
                proxyDict[kCFProxyUsernameKey as String] = user
            }
            if let pass = account.proxyPassword, !pass.isEmpty {
                proxyDict[kCFProxyPasswordKey as String] = pass
            }
        }

        configuration.connectionProxyDictionary = proxyDict
        return URLSession(configuration: configuration)
    }
}
