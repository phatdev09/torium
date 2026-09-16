import Foundation

/// Extracts authentication credentials (static Bearer token, clerkId, deviceId) from a Torium container
public final class TokenExtractor {
    public static let shared = TokenExtractor()

    private init() {}

    public struct ExtractedAuth {
        public let token: String
        public let clerkId: String
        public let deviceId: String
    }

    /// Scans container directory (Preferences, Keychain, local storage) to locate static Bearer token & session IDs
    public func extractAuth(for containerId: String) -> ExtractedAuth? {
        let fileManager = FileManager.default

        // Path to container Preferences
        let prefPath = "/var/mobile/Library/Application Support/Crane/Containers/\(containerId)/Library/Preferences/network.torium.app.plist"
        let sharedPrefPath = "/var/mobile/Library/Application Support/Crane/Containers/\(containerId)/Library/Preferences/group.network.torium.app.plist"

        var token: String?
        var clerkId: String?
        var deviceId: String?

        // Check container Preferences plists
        for path in [prefPath, sharedPrefPath] {
            if fileManager.fileExists(atPath: path),
               let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {

                for (key, value) in dict {
                    let k = key.lowercased()
                    if k.contains("token") || k.contains("jwt") || k.contains("bearer") || k.contains("clerk") {
                        if let str = value as? String, str.count > 20 {
                            token = str.replacingOccurrences(of: "Bearer ", with: "")
                        }
                    }
                    if k.contains("clerkid") || k.contains("user_id") {
                        if let str = value as? String, str.hasPrefix("user_") {
                            clerkId = str
                        }
                    }
                    if k.contains("deviceid") || k.contains("device_id") {
                        if let str = value as? String, !str.isEmpty {
                            deviceId = str
                        }
                    }
                }
            }
        }

        // Fallback: Check local SQLite or JSON storage in container Documents
        let docPath = "/var/mobile/Library/Application Support/Crane/Containers/\(containerId)/Documents"
        if let files = try? fileManager.contentsOfDirectory(atPath: docPath) {
            for file in files {
                if file.hasSuffix(".json") || file.hasSuffix(".txt") {
                    let filePath = "\(docPath)/\(file)"
                    if let content = try? String(contentsOfFile: filePath, encoding: .utf8) {
                        if token == nil, let t = extractRegex(pattern: "Bearer\\s+([A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+\\.[A-Za-z0-9-_=]+)", from: content) {
                            token = t
                        }
                        if clerkId == nil, let c = extractRegex(pattern: "(user_[A-Za-z0-9]+)", from: content) {
                            clerkId = c
                        }
                        if deviceId == nil, let d = extractRegex(pattern: "\"deviceId\":\\s*\"([^\"]+)\"", from: content) {
                            deviceId = d
                        }
                    }
                }
            }
        }

        guard let validToken = token, !validToken.isEmpty else {
            return nil
        }

        let finalDeviceId = deviceId ?? UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let finalClerkId = clerkId ?? "user_\(UUID().uuidString.prefix(12))"

        return ExtractedAuth(token: validToken, clerkId: finalClerkId, deviceId: finalDeviceId)
    }

    private func extractRegex(pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let results = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        if let match = results.first, match.numberOfRanges > 1 {
            let range = match.range(at: 1)
            return nsString.substring(with: range)
        }
        return nil
    }
}
