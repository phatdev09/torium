import Foundation
import UIKit

/// Represents a Crane container on a jailbroken device
public struct CraneContainer: Identifiable, Equatable {
    public let id: String                 // Container identifier (UUID or clone ID)
    public let name: String               // Display name
    public let bundleIdentifier: String   // Target app bundle id (e.g. network.torium.app)
    public let containerPath: String?     // Absolute path to container directory if resolved

    public init(id: String, name: String, bundleIdentifier: String, containerPath: String? = nil) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.containerPath = containerPath
    }
}

/// Manages interaction with the Crane jailbreak tweak via native libCrane API (opa334)
public final class CraneManager {
    public static let shared = CraneManager()
    public static let toriumBundleId = "network.torium.app"

    private init() {}

    /// Discovers all available Crane containers for Torium app
    public func fetchContainers() -> [CraneContainer] {
        let containerIds = CraneBridge.getContainers(forApp: CraneManager.toriumBundleId)
        
        if !containerIds.isEmpty {
            return containerIds.map { cid in
                let paths = CraneBridge.getContainerPaths(cid, forApp: CraneManager.toriumBundleId)
                let appPath = paths[0] as? String
                return CraneContainer(
                    id: cid,
                    name: "Container \(cid.prefix(6))",
                    bundleIdentifier: CraneManager.toriumBundleId,
                    containerPath: appPath
                )
            }
        }

        // Fallback: Default container if Crane has not created extra containers yet
        return [
            CraneContainer(
                id: "default",
                name: "Default Container",
                bundleIdentifier: CraneManager.toriumBundleId,
                containerPath: "/var/mobile/Containers/Data/Application"
            )
        ]
    }

    /// Auto-provisions a new container with formatted display name: '01. user@hotmail.com'
    @discardableResult
    public func provisionContainer(forEmail email: String, index: Int) -> String? {
        let displayName = String(format: "%02d. %@", index, email)
        if let newContainerId = CraneBridge.createContainer(named: displayName, forApp: CraneManager.toriumBundleId) {
            DatabaseManager.shared.insertLog(Log(
                level: .info,
                action: .general,
                message: "Crane: Đã tự động tạo container [\(displayName)] (ID: \(newContainerId))."
            ))
            return newContainerId
        }
        return nil
    }

    /// Safely switches active container and launches Torium app
    public func switchAndLaunch(containerId: String) {
        // 1. Terminate old instance & switch container in libCrane
        CraneBridge.switchContainer(containerId, forApp: CraneManager.toriumBundleId)

        // 2. Launch application directly via system workspace
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let success = CraneBridge.launchApplication(withIdentifier: CraneManager.toriumBundleId)
            if !success {
                // Fallback URL scheme
                if let url = URL(string: "crane://launch?bundle=\(CraneManager.toriumBundleId)&container=\(containerId)") {
                    if UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                }
            }
        }
    }

    /// Cleans WebKit & Caches of container after token extraction to preserve disk space
    public func optimizeContainerStorage(containerId: String) {
        CraneBridge.cleanContainerCaches(containerId, forApp: CraneManager.toriumBundleId)
        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "Crane: Đã dọn dẹp WebKit/Caches cho container [\(containerId)]."
        ))
    }

    /// Deletes container in Crane when an account is deleted from bot
    public func removeContainer(containerId: String) {
        CraneBridge.deleteContainer(containerId, forApp: CraneManager.toriumBundleId)
        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "Crane: Đã xoá container [\(containerId)] khỏi hệ thống."
        ))
    }
}
