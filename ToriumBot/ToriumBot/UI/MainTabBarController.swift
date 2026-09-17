import UIKit

/// Root TabBarController hosting Dashboard, Accounts, Settings, and Logs in a floating obsidian-gold capsule
public final class MainTabBarController: UITabBarController {

    private let floatingTabBar = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let itemsStack = UIStackView()
    private var itemButtons: [UIButton] = []

    private let tabs: [(title: String, icon: String, tag: Int)] = [
        ("Dashboard", "speedometer", 0),
        ("Accounts", "person.2.fill", 1),
        ("Settings", "gearshape.fill", 2),
        ("Logs", "terminal.fill", 3)
    ]

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        tabBar.isHidden = true

        setupViewControllers()
        setupFloatingTabBar()
        updateTabSelection(0, animated: false)
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tabBar.isHidden = true
        view.bringSubviewToFront(floatingTabBar)
    }

    private func setupViewControllers() {
        let dashboardVC = UINavigationController(rootViewController: DashboardViewController())
        let accountsVC = UINavigationController(rootViewController: AccountsViewController())
        let settingsVC = UINavigationController(rootViewController: SettingsViewController())
        let logsVC = UINavigationController(rootViewController: LogsViewController())

        for nav in [dashboardVC, accountsVC, settingsVC, logsVC] {
            let navBarAppearance = UINavigationBarAppearance()
            navBarAppearance.configureWithOpaqueBackground()
            navBarAppearance.backgroundColor = ToriumTheme.background
            navBarAppearance.titleTextAttributes = [
                .foregroundColor: ToriumTheme.textPrimary,
                .font: UIFont.systemFont(ofSize: 17, weight: .black)
            ]
            navBarAppearance.shadowColor = ToriumTheme.graphiteBorder
            nav.navigationBar.standardAppearance = navBarAppearance
            nav.navigationBar.scrollEdgeAppearance = navBarAppearance
            nav.navigationBar.compactAppearance = navBarAppearance
            nav.navigationBar.tintColor = ToriumTheme.accentGold

            // Ensure scrolling content clears the floating bar cleanly
            nav.additionalSafeAreaInsets = UIEdgeInsets(top: 0, left: 0, bottom: 64, right: 0)
        }

        viewControllers = [dashboardVC, accountsVC, settingsVC, logsVC]
    }

    private func setupFloatingTabBar() {
        floatingTabBar.translatesAutoresizingMaskIntoConstraints = false
        floatingTabBar.backgroundColor = ToriumTheme.graphiteCard.withAlphaComponent(0.85)
        floatingTabBar.layer.cornerRadius = 26
        floatingTabBar.layer.borderWidth = 1.2
        floatingTabBar.layer.borderColor = ToriumTheme.graphiteBorder.cgColor
        floatingTabBar.layer.shadowColor = UIColor.black.cgColor
        floatingTabBar.layer.shadowOffset = CGSize(width: 0, height: 8)
        floatingTabBar.layer.shadowRadius = 14
        floatingTabBar.layer.shadowOpacity = 0.60
        view.addSubview(floatingTabBar)

        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.layer.cornerRadius = 26
        blurView.clipsToBounds = true
        floatingTabBar.addSubview(blurView)

        itemsStack.translatesAutoresizingMaskIntoConstraints = false
        itemsStack.axis = .horizontal
        itemsStack.distribution = .fillEqually
        itemsStack.alignment = .center
        itemsStack.spacing = 4
        floatingTabBar.addSubview(itemsStack)

        NSLayoutConstraint.activate([
            floatingTabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            floatingTabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            floatingTabBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -6),
            floatingTabBar.heightAnchor.constraint(equalToConstant: 54),

            blurView.topAnchor.constraint(equalTo: floatingTabBar.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: floatingTabBar.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: floatingTabBar.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: floatingTabBar.bottomAnchor),

            itemsStack.topAnchor.constraint(equalTo: floatingTabBar.topAnchor, constant: 4),
            itemsStack.leadingAnchor.constraint(equalTo: floatingTabBar.leadingAnchor, constant: 6),
            itemsStack.trailingAnchor.constraint(equalTo: floatingTabBar.trailingAnchor, constant: -6),
            itemsStack.bottomAnchor.constraint(equalTo: floatingTabBar.bottomAnchor, constant: -4)
        ])

        for (index, tab) in tabs.enumerated() {
            let button = createTabButton(title: tab.title, iconName: tab.icon, index: index)
            itemButtons.append(button)
            itemsStack.addArrangedSubview(button)
        }
    }

    private func createTabButton(title: String, iconName: String, index: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = index
        btn.layer.cornerRadius = 18
        btn.clipsToBounds = true

        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tag = 101
        iconView.contentMode = .scaleAspectFit
        iconView.tintColor = ToriumTheme.textMuted
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.tag = 102
        label.text = title
        label.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        label.textColor = ToriumTheme.textMuted
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [iconView, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 2
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            stack.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: btn.centerYAnchor),
            btn.heightAnchor.constraint(equalToConstant: 46)
        ])

        btn.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        return btn
    }

    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        guard index != selectedIndex else { return }

        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()

        selectedIndex = index
        updateTabSelection(index, animated: true)
    }

    private func updateTabSelection(_ selected: Int, animated: Bool) {
        for (idx, btn) in itemButtons.enumerated() {
            let isSelected = (idx == selected)
            let iconView = btn.viewWithTag(101) as? UIImageView
            let label = btn.viewWithTag(102) as? UILabel

            let updates = {
                if isSelected {
                    btn.backgroundColor = ToriumTheme.accentGold.withAlphaComponent(0.12)
                    iconView?.tintColor = ToriumTheme.accentGold
                    label?.textColor = ToriumTheme.accentGold
                } else {
                    btn.backgroundColor = .clear
                    iconView?.tintColor = ToriumTheme.textMuted
                    label?.textColor = ToriumTheme.textMuted
                }
            }

            if animated {
                UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseOut], animations: updates)
            } else {
                updates()
            }
        }
    }

    public override var selectedIndex: Int {
        didSet {
            updateTabSelection(selectedIndex, animated: false)
        }
    }
}

