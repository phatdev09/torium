import Foundation

/// Manages heartbeat signals between the ToriumBot app and the rootful Watchdog launch daemon
public final class WatchdogDaemon {
    public static let shared = WatchdogDaemon()
    public static let heartbeatPath = "/tmp/toriumbot.heartbeat"

    private var heartbeatTimer: Timer?

    private init() {}

    /// Starts writing a timestamp heartbeat every 15 seconds to notify the LaunchDaemon that app is healthy
    public func startHeartbeat() {
        heartbeatTimer?.invalidate()
        writeHeartbeat()

        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
                self?.writeHeartbeat()
            }
        }
    }

    public func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    private func writeHeartbeat() {
        let now = Date().timeIntervalSince1970
        let content = "\(now)"
        try? content.write(toFile: WatchdogDaemon.heartbeatPath, atomically: true, encoding: .utf8)
    }

    /// Checks if the watchdog plist is installed in /Library/LaunchDaemons
    public func isDaemonInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: "/Library/LaunchDaemons/com.toriumbot.watchdog.plist")
    }
}
