import Foundation
import UIKit

/// Represents a Crane container on a jailbroken device
public struct CraneContainer: Identifiable, Equatable {
    public let id: String                 // Container identifier (UUID or clone ID)
    public let name: String               // Display name
    public let bundleIdentifier: String   // Target app bundle id (e.g. network.torium.app)
    public let containerPath: String      // Absolute path to container directory

    public init(id: String, name: String, bundleIdentifier: String, containerPath: String) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.containerPath = containerPath
    }
}

/// Manages interaction with the Crane jailbreak tweak and container directories
public final class CraneManager {
    public static let shared = CraneManager()
    public static let toriumBundleId = "network.torium.app"

    private let craneBaseDir = "/var/mobile/Library/Application Support/Crane/Containers"

    private init() {}

    /// Discovers all available Crane containers for Torium app from rootful jailbreak filesystem
    public func fetchContainers() -> [CraneContainer] {
        var results: [CraneContainer] = []

        // In rootful jailbreak with no-container entitlement, we can read Crane configs
        let fileManager = FileManager.default
        let appSupportCrane = "/var/mobile/Library/Application Support/Crane"
        let plistPath = "\(appSupportCrane)/Preferences.plist"

        if let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any],
           let apps = dict["Applications"] as? [String: Any],
           let toriumConfig = apps[CraneManager.toriumBundleId] as? [String: Any],
           let containers = toriumConfig["Containers"] as? [[String: Any]] {

            for item in containers {
                let id = item["Identifier"] as? String ?? UUID().uuidString
                let name = item["Name"] as? String ?? "Container \(id.prefix(6))"
                let path = "\(craneBaseDir)/\(id)"
                results.append(CraneContainer(
                    id: id,
                    name: name,
                    bundleIdentifier: CraneManager.toriumBundleId,
                    containerPath: path
                ))
            }
        }

        // Fallback: If no preference file exists yet, check direct filesystem directory
        if results.isEmpty, fileManager.fileExists(atPath: craneBaseDir) {
            if let dirs = try? fileManager.contentsOfDirectory(atPath: craneBaseDir) {
                for dir in dirs {
                    let fullPath = "\(craneBaseDir)/\(dir)"
                    results.append(CraneContainer(
                        id: dir,
                        name: "Container \(dir.prefix(6))",
                        bundleIdentifier: CraneManager.toriumBundleId,
                        containerPath: fullPath
                    ))
                }
            }
        }

        // Fallback default container if running without extra Crane containers
        if results.isEmpty {
            results.append(CraneContainer(
                id: "default",
                name: "Default Container",
                bundleIdentifier: CraneManager.toriumBundleId,
                containerPath: "/var/mobile/Containers/Data/Application"
            ))
        }

        return results
    }

    /// Launches Torium inside the specified Crane container via Crane CLI or URL scheme
    public func launchContainer(containerId: String) {
        // Method 1: Using Crane command line tool `crane launch <bundleId> <containerId>` via posix_spawn
        let cmd = "crane launch \(CraneManager.toriumBundleId) \(containerId)"
        var pid: pid_t = 0
        let args: [UnsafeMutablePointer<CChar>?] = [
            strdup("/bin/sh"),
            strdup("-c"),
            strdup(cmd),
            nil
        ]
        posix_spawn(&pid, "/bin/sh", nil, nil, args, nil)
        var status: Int32 = 0
        waitpid(pid, &status, 0)
        for ptr in args { if let p = ptr { free(p) } }

        // Method 2: Fallback via Crane URL Scheme `crane://launch?bundle=...&container=...`
        if let url = URL(string: "crane://launch?bundle=\(CraneManager.toriumBundleId)&container=\(containerId)") {
            DispatchQueue.main.async {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        }
    }
}
