import UIKit

public class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    public var window: UIWindow?

    public func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.backgroundColor = ToriumTheme.darkNavy

        let scannerVC = HardwareScannerViewController()
        window.rootViewController = scannerVC
        self.window = window
        window.makeKeyAndVisible()
    }

    public func sceneDidDisconnect(_ scene: UIScene) {}

    public func sceneDidBecomeActive(_ scene: UIScene) {
        // Ping heartbeat
        WatchdogDaemon.shared.startHeartbeat()
    }

    public func sceneWillResignActive(_ scene: UIScene) {}

    public func sceneWillEnterForeground(_ scene: UIScene) {}

    public func sceneDidEnterBackground(_ scene: UIScene) {
        // App backgrounded: Heartbeat and POSIX daemon will ensure mining stays alive
    }
}
