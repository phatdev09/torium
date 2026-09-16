import Foundation

/// Represents a Torium farming account with authentication, container, proxy, and referral details.
public struct Account: Codable, Identifiable, Equatable {
    public var id: Int64?
    public var email: String
    public var password: String
    public var bearerToken: String?
    public var clerkId: String?
    public var deviceId: String?
    public var proxyHost: String?
    public var proxyPort: Int?
    public var proxyUsername: String?
    public var proxyPassword: String?
    public var proxyProtocol: String? // "http", "https", "socks4", "socks5"
    public var containerId: String?   // Crane container identifier
    public var referralCode: String?  // Optional referral code used on registration
    public var isActive: Bool
    public var isBanned: Bool
    public var createdAt: Int64
    public var lastSeenAt: Int64

    public init(
        id: Int64? = nil,
        email: String,
        password: String,
        bearerToken: String? = nil,
        clerkId: String? = nil,
        deviceId: String? = nil,
        proxyHost: String? = nil,
        proxyPort: Int? = nil,
        proxyUsername: String? = nil,
        proxyPassword: String? = nil,
        proxyProtocol: String? = nil,
        containerId: String? = nil,
        referralCode: String? = nil,
        isActive: Bool = true,
        isBanned: Bool = false,
        createdAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000),
        lastSeenAt: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) {
        self.id = id
        self.email = email
        self.password = password
        self.bearerToken = bearerToken
        self.clerkId = clerkId
        self.deviceId = deviceId
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.proxyUsername = proxyUsername
        self.proxyPassword = proxyPassword
        self.proxyProtocol = proxyProtocol
        self.containerId = containerId
        self.referralCode = referralCode
        self.isActive = isActive
        self.isBanned = isBanned
        self.createdAt = createdAt
        self.lastSeenAt = lastSeenAt
    }

    /// Formats proxy string for display or configuration
    public var proxyString: String? {
        guard let host = proxyHost, let port = proxyPort, !host.isEmpty else { return nil }
        let proto = proxyProtocol ?? "socks5"
        if let user = proxyUsername, !user.isEmpty, let pass = proxyPassword, !pass.isEmpty {
            return "\(proto)://\(user):\(pass)@\(host):\(port)"
        }
        return "\(proto)://\(host):\(port)"
    }

    /// Generates standard backup string:
    /// email|password|bearer_token|clerk_id|device_id|proxy_protocol|proxy_host|proxy_port|proxy_username|proxy_password|referral_code
    public var backupLine: String {
        let bToken = bearerToken ?? ""
        let cId = clerkId ?? ""
        let dId = deviceId ?? ""
        let pProto = proxyProtocol ?? ""
        let pHost = proxyHost ?? ""
        let pPort = proxyPort != nil ? String(proxyPort!) : ""
        let pUser = proxyUsername ?? ""
        let pPass = proxyPassword ?? ""
        let ref = referralCode ?? ""
        return "\(email)|\(password)|\(bToken)|\(cId)|\(dId)|\(pProto)|\(pHost)|\(pPort)|\(pUser)|\(pPass)|\(ref)"
    }
}
