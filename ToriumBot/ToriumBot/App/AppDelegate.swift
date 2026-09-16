import UIKit

@main
public class AppDelegate: UIResponder, UIApplicationDelegate {

    public var window: UIWindow?

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Initialize SQLite Database and schema migrations
        _ = DatabaseManager.shared

        // Start heartbeat signaling for rootful Watchdog daemon
        WatchdogDaemon.shared.startHeartbeat()

        // Automatically start MiningEngine if enabled in settings
        let autoRestart = DatabaseManager.shared.getSetting(key: "auto_restart_enabled") ?? "true"
        if autoRestart == "true" {
            MiningEngine.shared.start()
        }

        // Start periodic reporting if configured
        TelegramReporter.shared.startPeriodicReporting()

        return true
    }

    // MARK: UISceneSession Lifecycle

    public func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    public func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {}

    public func applicationWillTerminate(_ application: UIApplication) {
        // Keep heartbeat or log clean termination
        DatabaseManager.shared.insertLog(Log(
            level: .info,
            action: .general,
            message: "Ứng dụng ToriumBot chuẩn bị dừng."
        ))
    }
}
