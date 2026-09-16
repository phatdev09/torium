import Foundation

public struct ParsedImportAccount: Identifiable, Equatable {
    public var id: String { email }
    public let email: String
    public let password: String
    public let refreshToken: String?
    public let clientId: String?
    public let bearerToken: String?
    public let clerkId: String?
    public let deviceId: String?
    public let proxyHost: String?
    public let proxyPort: Int?
    public let proxyUsername: String?
    public let proxyPassword: String?
    public let proxyProtocol: String?
    public let referralCode: String?
    public var containerId: String?
    public var isDuplicate: Bool = false

    public var isReadyToFarm: Bool {
        return bearerToken != nil && !bearerToken!.isEmpty
    }
}

public struct ImportPreviewResult {
    public var validAccounts: [ParsedImportAccount]
    public var duplicateAccounts: [ParsedImportAccount]
    public var invalidLines: [(line: Int, text: String, reason: String)]

    public var totalValid: Int { validAccounts.count }
    public var totalDuplicates: Int { duplicateAccounts.count }
    public var totalInvalid: Int { invalidLines.count }
}

/// Robust multi-format parser for account importing with auto-delimiter detection and validation
public final class ImportParser {
    public static let shared = ImportParser()

    private init() {}

    /// Parses raw imported text into a preview result
    public func parseText(_ text: String) -> ImportPreviewResult {
        var valids: [ParsedImportAccount] = []
        var duplicates: [ParsedImportAccount] = []
        var invalids: [(line: Int, text: String, reason: String)] = []

        let existingAccounts = DatabaseManager.shared.getAllAccounts()
        let existingEmails = Set(existingAccounts.map { $0.email.lowercased().trimmingCharacters(in: .whitespaces) })
        let masterRefCode = DatabaseManager.shared.getSetting(key: "master_referral_code")

        let lines = text.components(separatedBy: .newlines)
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty && !line.hasPrefix("#") else { continue }

            guard let account = parseLine(line, masterRefCode: masterRefCode) else {
                invalids.append((line: index + 1, text: line, reason: "Sai định dạng tài khoản hoặc thiếu Email/Password"))
                continue
            }

            if existingEmails.contains(account.email.lowercased()) {
                var dup = account
                dup.isDuplicate = true
                duplicates.append(dup)
            } else {
                valids.append(account)
            }
        }

        return ImportPreviewResult(
            validAccounts: valids,
            duplicateAccounts: duplicates,
            invalidLines: invalids
        )
    }

    private func parseLine(_ line: String, masterRefCode: String?) -> ParsedImportAccount? {
        // Detect delimiter: pipe, tab, colon
        var parts: [String] = []
        if line.contains("|") {
            parts = line.components(separatedBy: "|")
        } else if line.contains("\t") {
            parts = line.components(separatedBy: "\t")
        } else if line.contains(",") {
            parts = line.components(separatedBy: ",")
        } else {
            // Fallback colon
            parts = line.components(separatedBy: ":")
        }

        parts = parts.map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 2 else { return nil }

        let email = parts[0]
        let password = parts[1]
        guard email.contains("@"), !password.isEmpty else { return nil }

        var refreshToken: String?
        var clientId: String?
        var bearerToken: String?
        var clerkId: String?
        var deviceId: String?
        var proxyHost: String?
        var proxyPort: Int?
        var proxyUser: String?
        var proxyPass: String?
        var proxyProto: String? = "socks5"
        var referralCode: String? = masterRefCode?.isEmpty == false ? masterRefCode : nil

        // Case 1: email|pass|refresh_token|client_id (dongvanfb OAuth standard)
        if parts.count >= 4 && parts[2].count > 15 && parts[3].count > 10 && !parts[2].contains(".") {
            refreshToken = parts[2]
            clientId = parts[3]

            // If proxy is appended at parts[4]
            if parts.count >= 5 {
                let proxyPart = parts[4]
                let parsedProxy = parseProxyString(proxyPart)
                proxyHost = parsedProxy.host
                proxyPort = parsedProxy.port
                proxyUser = parsedProxy.user
                proxyPass = parsedProxy.pass
                proxyProto = parsedProxy.proto
            }
            // If ref code is appended at parts[5]
            if parts.count >= 6 && !parts[5].isEmpty {
                referralCode = parts[5]
            }
        }
        // Case 2: email|pass|bearer_token|clerk_id|device_id|proxy
        else if parts.count >= 5 && (parts[2].hasPrefix("ey") || parts[2].contains(".")) {
            bearerToken = parts[2]
            clerkId = parts[3]
            deviceId = parts[4]

            if parts.count >= 6 {
                let parsedProxy = parseProxyString(parts[5])
                proxyHost = parsedProxy.host
                proxyPort = parsedProxy.port
                proxyUser = parsedProxy.user
                proxyPass = parsedProxy.pass
                proxyProto = parsedProxy.proto
            }
            if parts.count >= 7 && !parts[6].isEmpty {
                referralCode = parts[6]
            }
        }
        // Case 3: email|pass|proxy
        else if parts.count >= 3 {
            let parsedProxy = parseProxyString(parts[2])
            if parsedProxy.host != nil {
                proxyHost = parsedProxy.host
                proxyPort = parsedProxy.port
                proxyUser = parsedProxy.user
                proxyPass = parsedProxy.pass
                proxyProto = parsedProxy.proto
            }
            if parts.count >= 4 && !parts[3].isEmpty {
                referralCode = parts[3]
            }
        }

        return ParsedImportAccount(
            email: email,
            password: password,
            refreshToken: refreshToken,
            clientId: clientId,
            bearerToken: bearerToken,
            clerkId: clerkId,
            deviceId: deviceId,
            proxyHost: proxyHost,
            proxyPort: proxyPort,
            proxyUsername: proxyUser,
            proxyPassword: proxyPass,
            proxyProtocol: proxyProto,
            referralCode: referralCode,
            containerId: nil,
            isDuplicate: false
        )
    }

    private func parseProxyString(_ str: String) -> (host: String?, port: Int?, user: String?, pass: String?, proto: String?) {
        let trimmed = str.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return (nil, nil, nil, nil, nil) }

        // URL format: http://user:pass@host:port or socks5://...
        if let url = URL(string: trimmed), let host = url.host, let port = url.port {
            let proto = url.scheme ?? "socks5"
            return (host, port, url.user, url.password, proto)
        }

        // Delimited format: host:port:user:pass or host:port
        let segments = trimmed.components(separatedBy: ":")
        if segments.count >= 2 {
            let host = segments[0]
            if let port = Int(segments[1]) {
                var user: String?
                var pass: String?
                if segments.count >= 4 {
                    user = segments[2]
                    pass = segments[3]
                }
                return (host, port, user, pass, "socks5")
            }
        }

        return (nil, nil, nil, nil, nil)
    }

    /// Commits valid parsed accounts into SQLite and provisions Crane containers
    public func commitImport(accounts: [ParsedImportAccount], autoProvisionCrane: Bool = true) -> Int {
        var successCount = 0
        let currentAccountsCount = DatabaseManager.shared.getAllAccounts().count

        for (idx, parsed) in accounts.enumerated() {
            var containerId = parsed.containerId

            if autoProvisionCrane && (containerId == nil || containerId!.isEmpty) {
                let accountIndex = currentAccountsCount + idx + 1
                containerId = CraneManager.shared.provisionContainer(forEmail: parsed.email, index: accountIndex)
            }

            let newAccount = Account(
                email: parsed.email,
                password: parsed.password,
                bearerToken: parsed.bearerToken,
                clerkId: parsed.clerkId,
                deviceId: parsed.deviceId,
                proxyHost: parsed.proxyHost,
                proxyPort: parsed.proxyPort,
                proxyUsername: parsed.proxyUsername,
                proxyPassword: parsed.proxyPassword,
                proxyProtocol: parsed.proxyProtocol,
                containerId: containerId,
                referralCode: parsed.referralCode,
                isActive: true,
                isBanned: false
            )

            if DatabaseManager.shared.insertAccount(newAccount) != nil {
                successCount += 1
            }
        }

        // Trigger Auto-Backup to Telegram
        TelegramReporter.shared.sendManualBackup()

        return successCount
    }
}
