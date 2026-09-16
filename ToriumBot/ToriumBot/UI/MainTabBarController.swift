import UIKit

/// Root TabBarController hosting Dashboard, Accounts, Settings, and Logs
public final class MainTabBarController: UITabBarController {

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupViewControllers()
    }

    private func setupAppearance() {
        view.backgroundColor = ToriumTheme.background

        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = ToriumTheme.background

        appearance.stackedLayoutAppearance.normal.iconColor = ToriumTheme.textMuted
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: ToriumTheme.textMuted]

        appearance.stackedLayoutAppearance.selected.iconColor = ToriumTheme.accentGold
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: ToriumTheme.accentGold]

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        tabBar.tintColor = ToriumTheme.accentGold
    }

    private func setupViewControllers() {
        let dashboardVC = UINavigationController(rootViewController: DashboardViewController())
        dashboardVC.tabBarItem = UITabBarItem(title: "Dashboard", image: UIImage(systemName: "house.fill"), tag: 0)

        let accountsVC = UINavigationController(rootViewController: AccountsViewController())
        accountsVC.tabBarItem = UITabBarItem(title: "Accounts", image: UIImage(systemName: "person.2.fill"), tag: 1)

        let settingsVC = UINavigationController(rootViewController: SettingsViewController())
        settingsVC.tabBarItem = UITabBarItem(title: "Settings", image: UIImage(systemName: "gearshape.fill"), tag: 2)

        let logsVC = UINavigationController(rootViewController: LogsViewController())
        logsVC.tabBarItem = UITabBarItem(title: "Logs", image: UIImage(systemName: "list.bullet.rectangle"), tag: 3)

        // Apply dark navigation bar styling to all navigation controllers
        for nav in [dashboardVC, accountsVC, settingsVC, logsVC] {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = ToriumTheme.background
            navBarAppearance.titleTextAttributes = [
                .foregroundColor: ToriumTheme.textPrimary,
                .font: UIFont.systemFont(ofSize: 18, weight: .bold)
            ]
            nav.navigationBar.standardAppearance = navBarAppearance
            nav.navigationBar.scrollEdgeAppearance = navBarAppearance
            nav.navigationBar.tintColor = ToriumTheme.accentGold
        }

        viewControllers = [dashboardVC, accountsVC, settingsVC, logsVC]
    }
}
