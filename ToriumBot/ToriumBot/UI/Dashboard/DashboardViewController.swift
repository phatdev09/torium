import UIKit

/// Executive Cinematic Control Center Dashboard for Torium Bot & Crane Containers
public final class DashboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // 1. Top HUD / Command Bar
    private let hudContainer = UIView()
    private let brandLogoImageView = UIImageView()
    private let brandTitleLabel = UILabel()
    private let engineStatusBadge = UILabel()
    private let batteryBadge = UILabel()
    private let hardwareProfileBadge = UILabel()
    private let ramBadge = UILabel()
    private let masterToggleButton = UIButton(type: .system)

    // 2. Real-time Live Activity Marquee Ticker
    private let tickerContainer = UIView()
    private let tickerDot = UIView()
    private let tickerLabel = UILabel()

    // 3. Circular Gauge Hero & Executive Stat Cards
    private let circularGaugeCard = UIView()
    private let circularGaugeView = CircularGaugeView()
    private let statCardsStack = UIStackView()
    private let activeContainersCard = ExecutiveKPICard(
        title: "CRANE CONTAINERS",
        mainValue: "0 / 0",
        subValue: "0 container đang chạy",
        iconName: "shippingbox.fill",
        accentColor: ToriumTheme.cyanHighlight
    )
    private let adsWatchedCard = ExecutiveKPICard(
        title: "XEM QUẢNG CÁO 24H",
        mainValue: "0 Ads",
        subValue: "Mục tiêu 120 ads/acc",
        iconName: "play.rectangle.fill",
        accentColor: ToriumTheme.toriumYellow
    )
    private let systemHealthCard = ExecutiveKPICard(
        title: "SỨC KHỎE HỆ THỐNG",
        mainValue: "100%",
        subValue: "0 Ban • 0 Lỗi Proxy",
        iconName: "checkmark.shield.fill",
        accentColor: ToriumTheme.miningGreen
    )

    // 4. Detailed Accounts & Containers Table Section
    private let tableSectionHeader = UIView()
    private let sectionTitleLabel = UILabel()
    private let sectionSubtitleLabel = UILabel()
    private let countPill = UILabel()
    private let filterSegmented = UISegmentedControl(items: ["Tất Cả", "Đang Đào", "Tạm Dừng", "Lỗi/Ban"])

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var tableViewHeightConstraint: NSLayoutConstraint?

    // Data Source
    private var allAccounts: [Account] = []
    private var filteredAccounts: [Account] = []
    private var statsMap: [Int64: MiningStats] = [:]
    private var activeMiningIds: Set<Int64> = []
    private var refreshTimer: Timer?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Torium Command Center"
        navigationController?.navigationBar.prefersLargeTitles = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gearshape.fill"),
            style: .plain,
            target: self,
            action: #selector(handleOpenSettings)
        )

        setupScrollView()
        setupHUD()
        setupActivityTicker()
        setupKPICards()
        setupTableSection()
        loadData()
    }

    @objc private func handleOpenSettings() {
        tabBarController?.selectedIndex = 2
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        startRefreshTimer()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopRefreshTimer()
    }

    // MARK: - UI Construction

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func setupHUD() {
        hudContainer.translatesAutoresizingMaskIntoConstraints = false
        hudContainer.backgroundColor = ToriumTheme.darkNavyCard
        hudContainer.layer.cornerRadius = 14
        hudContainer.layer.borderWidth = 1
        hudContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        contentView.addSubview(hudContainer)

        brandLogoImageView.image = UIImage.toriumLogo
        brandLogoImageView.contentMode = .scaleAspectFit
        brandLogoImageView.layer.cornerRadius = 5
        brandLogoImageView.clipsToBounds = true
        brandLogoImageView.layer.borderWidth = 0.8
        brandLogoImageView.layer.borderColor = ToriumTheme.accentGold.withAlphaComponent(0.4).cgColor
        brandLogoImageView.translatesAutoresizingMaskIntoConstraints = false
        brandLogoImageView.widthAnchor.constraint(equalToConstant: 22).isActive = true
        brandLogoImageView.heightAnchor.constraint(equalToConstant: 22).isActive = true

        brandTitleLabel.text = "TORIUM SYSTEM"
        brandTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .black)
        brandTitleLabel.textColor = ToriumTheme.accentGold
        brandTitleLabel.adjustsFontSizeToFitWidth = true
        brandTitleLabel.minimumScaleFactor = 0.85
        brandTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        engineStatusBadge.font = UIFont.systemFont(ofSize: 10, weight: .black)
        engineStatusBadge.layer.cornerRadius = 5
        engineStatusBadge.clipsToBounds = true
        engineStatusBadge.textAlignment = .center
        engineStatusBadge.adjustsFontSizeToFitWidth = true
        engineStatusBadge.minimumScaleFactor = 0.8
        engineStatusBadge.translatesAutoresizingMaskIntoConstraints = false

        batteryBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        batteryBadge.layer.cornerRadius = 5
        batteryBadge.clipsToBounds = true
        batteryBadge.textAlignment = .center
        batteryBadge.backgroundColor = ToriumTheme.darkNavy
        batteryBadge.textColor = ToriumTheme.textSecondary
        batteryBadge.adjustsFontSizeToFitWidth = true
        batteryBadge.minimumScaleFactor = 0.8
        batteryBadge.translatesAutoresizingMaskIntoConstraints = false
        UIDevice.current.isBatteryMonitoringEnabled = true

        hardwareProfileBadge.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .bold)
        hardwareProfileBadge.layer.cornerRadius = 4
        hardwareProfileBadge.clipsToBounds = true
        hardwareProfileBadge.textAlignment = .center
        hardwareProfileBadge.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.15)
        hardwareProfileBadge.textColor = ToriumTheme.cyanHighlight
        hardwareProfileBadge.adjustsFontSizeToFitWidth = true
        hardwareProfileBadge.minimumScaleFactor = 0.8
        hardwareProfileBadge.text = DatabaseManager.shared.getSetting(key: "hardware_profile_name") ?? "A9 ECO"
        hardwareProfileBadge.translatesAutoresizingMaskIntoConstraints = false

        ramBadge.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .semibold)
        ramBadge.layer.cornerRadius = 4
        ramBadge.clipsToBounds = true
        ramBadge.textAlignment = .center
        ramBadge.backgroundColor = ToriumTheme.darkNavy
        ramBadge.textColor = ToriumTheme.textMuted
        ramBadge.adjustsFontSizeToFitWidth = true
        ramBadge.minimumScaleFactor = 0.8
        ramBadge.text = "RAM: OK"
        ramBadge.translatesAutoresizingMaskIntoConstraints = false

        masterToggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        masterToggleButton.layer.cornerRadius = 8
        masterToggleButton.layer.borderWidth = 1
        masterToggleButton.addTarget(self, action: #selector(toggleEngine), for: .touchUpInside)
        masterToggleButton.translatesAutoresizingMaskIntoConstraints = false

        let brandTitleStack = UIStackView(arrangedSubviews: [brandLogoImageView, brandTitleLabel])
        brandTitleStack.axis = .horizontal
        brandTitleStack.spacing = 6
        brandTitleStack.alignment = .center
        brandTitleStack.translatesAutoresizingMaskIntoConstraints = false

        let brandRow = UIStackView(arrangedSubviews: [brandTitleStack, engineStatusBadge])
        brandRow.axis = .horizontal
        brandRow.distribution = .equalSpacing
        brandRow.alignment = .center
        brandRow.translatesAutoresizingMaskIntoConstraints = false

        let metricsRow = UIStackView(arrangedSubviews: [hardwareProfileBadge, ramBadge, batteryBadge])
        metricsRow.axis = .horizontal
        metricsRow.distribution = .fillEqually
        metricsRow.spacing = 6
        metricsRow.alignment = .center
        metricsRow.translatesAutoresizingMaskIntoConstraints = false

        hudContainer.addSubview(brandRow)
        hudContainer.addSubview(metricsRow)
        hudContainer.addSubview(masterToggleButton)

        NSLayoutConstraint.activate([
            hudContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            hudContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            hudContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            hudContainer.heightAnchor.constraint(equalToConstant: 116),

            brandRow.topAnchor.constraint(equalTo: hudContainer.topAnchor, constant: 10),
            brandRow.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor, constant: 12),
            brandRow.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -12),
            brandRow.heightAnchor.constraint(equalToConstant: 22),

            metricsRow.topAnchor.constraint(equalTo: brandRow.bottomAnchor, constant: 6),
            metricsRow.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor, constant: 12),
            metricsRow.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -12),
            metricsRow.heightAnchor.constraint(equalToConstant: 20),

            engineStatusBadge.heightAnchor.constraint(equalToConstant: 20),
            engineStatusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),
            hardwareProfileBadge.heightAnchor.constraint(equalToConstant: 20),
            ramBadge.heightAnchor.constraint(equalToConstant: 20),
            batteryBadge.heightAnchor.constraint(equalToConstant: 20),

            masterToggleButton.leadingAnchor.constraint(equalTo: hudContainer.leadingAnchor, constant: 12),
            masterToggleButton.trailingAnchor.constraint(equalTo: hudContainer.trailingAnchor, constant: -12),
            masterToggleButton.bottomAnchor.constraint(equalTo: hudContainer.bottomAnchor, constant: -10),
            masterToggleButton.heightAnchor.constraint(equalToConstant: 34)
        ])

        updateEngineStatusUI()
        updateBatteryStatusUI()
    }

    private func setupActivityTicker() {
        tickerContainer.translatesAutoresizingMaskIntoConstraints = false
        tickerContainer.backgroundColor = ToriumTheme.darkNavyCard.withAlphaComponent(0.8)
        tickerContainer.layer.cornerRadius = 10
        tickerContainer.layer.borderWidth = 1
        tickerContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        contentView.addSubview(tickerContainer)

        tickerDot.translatesAutoresizingMaskIntoConstraints = false
        tickerDot.backgroundColor = ToriumTheme.miningGreen
        tickerDot.layer.cornerRadius = 3.5
        tickerContainer.addSubview(tickerDot)

        tickerLabel.translatesAutoresizingMaskIntoConstraints = false
        tickerLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        tickerLabel.textColor = ToriumTheme.textSecondary
        tickerLabel.text = "ToriumBot Engine: Sẵn sàng điều phối các Crane container."
        tickerContainer.addSubview(tickerLabel)

        NSLayoutConstraint.activate([
            tickerContainer.topAnchor.constraint(equalTo: hudContainer.bottomAnchor, constant: 8),
            tickerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tickerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tickerContainer.heightAnchor.constraint(equalToConstant: 28),

            tickerDot.centerYAnchor.constraint(equalTo: tickerContainer.centerYAnchor),
            tickerDot.leadingAnchor.constraint(equalTo: tickerContainer.leadingAnchor, constant: 10),
            tickerDot.widthAnchor.constraint(equalToConstant: 7),
            tickerDot.heightAnchor.constraint(equalToConstant: 7),

            tickerLabel.centerYAnchor.constraint(equalTo: tickerContainer.centerYAnchor),
            tickerLabel.leadingAnchor.constraint(equalTo: tickerDot.trailingAnchor, constant: 8),
            tickerLabel.trailingAnchor.constraint(equalTo: tickerContainer.trailingAnchor, constant: -10)
        ])
    }

    private func setupKPICards() {
        // 1. Circular Gauge Hero Card
        circularGaugeCard.translatesAutoresizingMaskIntoConstraints = false
        ToriumTheme.applyCardStyle(to: circularGaugeCard, radius: ToriumTheme.radiusHero, hasGoldAccent: true)
        contentView.addSubview(circularGaugeCard)

        circularGaugeView.translatesAutoresizingMaskIntoConstraints = false
        circularGaugeCard.addSubview(circularGaugeView)

        NSLayoutConstraint.activate([
            circularGaugeCard.topAnchor.constraint(equalTo: tickerContainer.bottomAnchor, constant: 10),
            circularGaugeCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            circularGaugeCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            circularGaugeCard.heightAnchor.constraint(equalToConstant: 190),

            circularGaugeView.topAnchor.constraint(equalTo: circularGaugeCard.topAnchor, constant: 8),
            circularGaugeView.bottomAnchor.constraint(equalTo: circularGaugeCard.bottomAnchor, constant: -8),
            circularGaugeView.centerXAnchor.constraint(equalTo: circularGaugeCard.centerXAnchor),
            circularGaugeView.widthAnchor.constraint(equalTo: circularGaugeView.heightAnchor)
        ])

        // 2. 3 Key Stat Cards Stack (Container full row + Ads/Health 2-column row)
        statCardsStack.axis = .vertical
        statCardsStack.spacing = 8
        statCardsStack.distribution = .fill
        statCardsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statCardsStack)

        activeContainersCard.translatesAutoresizingMaskIntoConstraints = false
        activeContainersCard.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let subRow = UIStackView(arrangedSubviews: [adsWatchedCard, systemHealthCard])
        subRow.axis = .horizontal
        subRow.spacing = 8
        subRow.distribution = .fillEqually
        subRow.translatesAutoresizingMaskIntoConstraints = false
        subRow.heightAnchor.constraint(equalToConstant: 68).isActive = true

        statCardsStack.addArrangedSubview(activeContainersCard)
        statCardsStack.addArrangedSubview(subRow)

        NSLayoutConstraint.activate([
            statCardsStack.topAnchor.constraint(equalTo: circularGaugeCard.bottomAnchor, constant: 10),
            statCardsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statCardsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    private func setupTableSection() {
        tableSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableSectionHeader)

        sectionTitleLabel.text = "DANH SÁCH CHI TIẾT TÀI KHOẢN & CONTAINER"
        sectionTitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        sectionTitleLabel.textColor = ToriumTheme.textPrimary
        sectionTitleLabel.adjustsFontSizeToFitWidth = true
        sectionTitleLabel.minimumScaleFactor = 0.8
        sectionTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        sectionTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        countPill.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        countPill.textColor = ToriumTheme.cyanHighlight
        countPill.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.15)
        countPill.layer.cornerRadius = 4
        countPill.clipsToBounds = true
        countPill.textAlignment = .center
        countPill.text = " 0 ACCOUNTS "
        countPill.setContentCompressionResistancePriority(.required, for: .horizontal)
        countPill.setContentHuggingPriority(.required, for: .horizontal)
        countPill.translatesAutoresizingMaskIntoConstraints = false

        sectionSubtitleLabel.text = "Quản lý chi tiết từng tài khoản kèm trạng thái Crane Container tương ứng"
        sectionSubtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        sectionSubtitleLabel.textColor = ToriumTheme.textMuted
        sectionSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Filter segmented control
        filterSegmented.selectedSegmentIndex = 0
        ToriumTheme.styleSegmentedControl(filterSegmented)
        filterSegmented.addTarget(self, action: #selector(handleFilterChanged), for: .valueChanged)
        filterSegmented.translatesAutoresizingMaskIntoConstraints = false

        tableSectionHeader.addSubview(sectionTitleLabel)
        tableSectionHeader.addSubview(countPill)
        tableSectionHeader.addSubview(sectionSubtitleLabel)
        tableSectionHeader.addSubview(filterSegmented)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isScrollEnabled = false
        tableView.register(AccountSummaryCell.self, forCellReuseIdentifier: AccountSummaryCell.reuseIdentifier)
        contentView.addSubview(tableView)

        let heightConstraint = tableView.heightAnchor.constraint(equalToConstant: 200)
        self.tableViewHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            tableSectionHeader.topAnchor.constraint(equalTo: statCardsStack.bottomAnchor, constant: 14),
            tableSectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableSectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            sectionTitleLabel.topAnchor.constraint(equalTo: tableSectionHeader.topAnchor),
            sectionTitleLabel.leadingAnchor.constraint(equalTo: tableSectionHeader.leadingAnchor),
            sectionTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: countPill.leadingAnchor, constant: -8),

            countPill.centerYAnchor.constraint(equalTo: sectionTitleLabel.centerYAnchor),
            countPill.trailingAnchor.constraint(equalTo: tableSectionHeader.trailingAnchor),
            countPill.heightAnchor.constraint(equalToConstant: 18),

            sectionSubtitleLabel.topAnchor.constraint(equalTo: sectionTitleLabel.bottomAnchor, constant: 2),
            sectionSubtitleLabel.leadingAnchor.constraint(equalTo: tableSectionHeader.leadingAnchor),
            sectionSubtitleLabel.trailingAnchor.constraint(equalTo: tableSectionHeader.trailingAnchor),

            filterSegmented.topAnchor.constraint(equalTo: sectionSubtitleLabel.bottomAnchor, constant: 8),
            filterSegmented.leadingAnchor.constraint(equalTo: tableSectionHeader.leadingAnchor),
            filterSegmented.trailingAnchor.constraint(equalTo: tableSectionHeader.trailingAnchor),
            filterSegmented.heightAnchor.constraint(equalToConstant: 28),
            filterSegmented.bottomAnchor.constraint(equalTo: tableSectionHeader.bottomAnchor),

            tableView.topAnchor.constraint(equalTo: tableSectionHeader.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            heightConstraint
        ])
    }

    // MARK: - Data Loading & Filtering

    public func loadData() {
        allAccounts = DatabaseManager.shared.getAllAccounts()
        activeMiningIds = MiningEngine.shared.getActiveAccountIds()

        var totalTor: Double = 0.0
        var totalAds: Int = 0
        var totalBoostRate: Double = 0.0
        var activeAccountsCount = 0
        var errorCount = 0
        let containers = CraneManager.shared.fetchContainers()

        for acc in allAccounts {
            if let id = acc.id, let stats = DatabaseManager.shared.getMiningStats(accountId: id) {
                statsMap[id] = stats
                totalTor += stats.torBalance
                totalAds += stats.adsWatched
                if acc.isActive && !acc.isBanned {
                    totalBoostRate += (stats.boostRate > 0 ? stats.boostRate : 0.4)
                }
            } else if acc.isActive && !acc.isBanned {
                totalBoostRate += 0.4
            }
            if acc.isActive && !acc.isBanned {
                activeAccountsCount += 1
            }
            if !acc.isActive || acc.isBanned {
                errorCount += 1
            }
        }

        // Update Circular Gauge: dynamic progress and speed
        let progress = totalTor > 0 ? min(1.0, CGFloat(totalTor / 5.0)) : (activeAccountsCount > 0 ? 0.25 : 0.0)
        circularGaugeView.update(
            balance: String(format: "%.4f", totalTor),
            speed: String(format: "Tốc độ: +%.3f TOR/h", totalBoostRate),
            progress: progress
        )

        let runningInContainersCount = activeMiningIds.count
        activeContainersCard.update(
            main: "\(containers.count) Containers",
            sub: "\(runningInContainersCount) đang cày ngầm"
        )

        adsWatchedCard.update(
            main: "\(totalAds) Ads",
            sub: "Tổng lượt xem hôm nay"
        )

        let healthPercent = allAccounts.isEmpty ? 100 : Int((Double(activeAccountsCount) / Double(allAccounts.count)) * 100)
        systemHealthCard.update(
            main: "\(healthPercent)% OK",
            sub: "\(errorCount) cần kiểm tra"
        )

        countPill.text = " \(allAccounts.count) ACCOUNTS "

        // Update Activity Ticker with latest log or live mining status
        if runningInContainersCount > 0 {
            tickerLabel.text = "⚡ Đang cày song song \(runningInContainersCount) container trong background..."
        } else if let latestLog = DatabaseManager.shared.getRecentLogs(limit: 1).first {
            tickerLabel.text = "[\(formatTime(latestLog.createdAt))] \(latestLog.message)"
        }

        updateEngineStatusUI()
        updateBatteryStatusUI()
        applyFilter()
    }

    @objc private func handleFilterChanged() {
        applyFilter()
    }

    private func applyFilter() {
        let index = filterSegmented.selectedSegmentIndex
        switch index {
        case 1: // Đang Đào
            filteredAccounts = allAccounts.filter { $0.isActive && !$0.isBanned }
        case 2: // Tạm Dừng
            filteredAccounts = allAccounts.filter { !$0.isActive && !$0.isBanned }
        case 3: // Lỗi / Ban
            filteredAccounts = allAccounts.filter { $0.isBanned }
        default: // Tất Cả
            filteredAccounts = allAccounts
        }

        let cellHeight: CGFloat = 132.0
        let newTableHeight = max(1, CGFloat(filteredAccounts.count)) * cellHeight
        tableViewHeightConstraint?.constant = newTableHeight

        tableView.reloadData()
    }

    private func formatTime(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp / 1000))
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    // MARK: - Automation Engine Toggle

    @objc private func toggleEngine() {
        if MiningEngine.shared.isRunning {
            MiningEngine.shared.stop()
        } else {
            MiningEngine.shared.start()
        }
        updateEngineStatusUI()
        updateBatteryStatusUI()
    }

    private func updateEngineStatusUI() {
        let isRunning = MiningEngine.shared.isRunning
        if isRunning {
            engineStatusBadge.text = " 🟢 LIVE "
            engineStatusBadge.backgroundColor = ToriumTheme.miningGreen.withAlphaComponent(0.2)
            engineStatusBadge.textColor = ToriumTheme.miningGreen

            masterToggleButton.setTitle("⏹ DỪNG TẤT CẢ CONTAINER", for: .normal)
            masterToggleButton.backgroundColor = ToriumTheme.error.withAlphaComponent(0.18)
            masterToggleButton.setTitleColor(ToriumTheme.error, for: .normal)
            masterToggleButton.layer.borderColor = ToriumTheme.error.withAlphaComponent(0.5).cgColor

            tickerDot.backgroundColor = ToriumTheme.miningGreen
        } else {
            engineStatusBadge.text = " ⏸ STANDBY "
            engineStatusBadge.backgroundColor = ToriumTheme.textMuted.withAlphaComponent(0.18)
            engineStatusBadge.textColor = ToriumTheme.textSecondary

            masterToggleButton.setTitle("⚡ KÍCH HOẠT HỆ THỐNG ĐÀO", for: .normal)
            masterToggleButton.backgroundColor = ToriumTheme.accentGold
            masterToggleButton.setTitleColor(UIColor.black, for: .normal)
            masterToggleButton.layer.borderColor = ToriumTheme.accentGold.cgColor

            tickerDot.backgroundColor = ToriumTheme.warning
        }
    }

    private func updateBatteryStatusUI() {
        let level = UIDevice.current.batteryLevel
        let state = UIDevice.current.batteryState
        let percent = level >= 0 ? Int(level * 100) : 100
        let isCharging = (state == .charging || state == .full)
        let icon = isCharging ? "⚡" : "🔋"

        batteryBadge.text = "\(icon) \(percent)%"
        if percent <= 20 && !isCharging {
            batteryBadge.textColor = ToriumTheme.error
            batteryBadge.backgroundColor = ToriumTheme.error.withAlphaComponent(0.15)
        } else {
            batteryBadge.textColor = ToriumTheme.textSecondary
            batteryBadge.backgroundColor = ToriumTheme.darkNavy
        }
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.loadData()
            self?.updateEngineStatusUI()
            self?.updateBatteryStatusUI()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - UITableViewDataSource & Delegate

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredAccounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AccountSummaryCell.reuseIdentifier, for: indexPath) as? AccountSummaryCell else {
            return UITableViewCell()
        }
        let account = filteredAccounts[indexPath.row]
        let stats = account.id != nil ? statsMap[account.id!] : nil
        let isMining = account.id != nil && activeMiningIds.contains(account.id!)
        cell.configure(with: account, stats: stats, isCurrentlyMining: isMining)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 132.0
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let account = filteredAccounts[indexPath.row]
        let actionSheet = UIAlertController(
            title: "Quản Lý: \(account.email)",
            message: "Crane Container: \(account.containerId ?? "default")",
            preferredStyle: .actionSheet
        )

        let toggleTitle = account.isActive ? "⏸ Tạm Dừng Account Này" : "▶️ Kích Hoạt Lại Account"
        actionSheet.addAction(UIAlertAction(title: toggleTitle, style: .default, handler: { [weak self] _ in
            var updated = account
            updated.isActive = !account.isActive
            DatabaseManager.shared.updateAccount(updated)
            self?.loadData()
        }))

        actionSheet.addAction(UIAlertAction(title: "⚡ Cày Ngay Lập Tức (Force Mine)", style: .default, handler: { [weak self] _ in
            if let id = account.id {
                MiningEngine.shared.forceMineAccount(accountId: id)
                self?.loadData()
            }
        }))

        actionSheet.addAction(UIAlertAction(title: "📦 Mở Container Trong Torium", style: .default, handler: { _ in
            if let cId = account.containerId {
                CraneManager.shared.switchAndLaunch(containerId: cId)
            }
        }))

        actionSheet.addAction(UIAlertAction(title: "🔍 Chi Tiết Tài Khoản", style: .default, handler: { [weak self] _ in
            let detailVC = AccountDetailViewController(account: account)
            self?.navigationController?.pushViewController(detailVC, animated: true)
        }))

        actionSheet.addAction(UIAlertAction(title: "Đóng", style: .cancel))
        present(actionSheet, animated: true)
    }
}

// MARK: - Dedicated Circular Gauge Hero View

public final class CircularGaugeView: UIView {
    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let centerStack = UIStackView()
    private let coinIconView = UIImageView()
    private let titleLabel = UILabel()
    private let balanceLabel = UILabel()
    private let speedLabel = UILabel()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
        setupContent()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
        setupContent()
    }

    private func setupLayers() {
        backgroundColor = .clear

        trackLayer.fillColor = UIColor.clear.cgColor
        trackLayer.strokeColor = ToriumTheme.graphiteElevated.cgColor
        trackLayer.lineWidth = 12.0
        trackLayer.lineCap = .round
        layer.addSublayer(trackLayer)

        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = ToriumTheme.accentGold.cgColor
        progressLayer.lineWidth = 12.0
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0.0
        layer.addSublayer(progressLayer)
    }

    private func setupContent() {
        coinIconView.image = UIImage(systemName: "bitcoinsign.circle.fill")
        coinIconView.tintColor = ToriumTheme.accentGold
        coinIconView.contentMode = .scaleAspectFit
        coinIconView.translatesAutoresizingMaskIntoConstraints = false
        coinIconView.widthAnchor.constraint(equalToConstant: 24).isActive = true
        coinIconView.heightAnchor.constraint(equalToConstant: 24).isActive = true

        titleLabel.text = "TỔNG TOR ĐÃ ĐÀO"
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .heavy)
        titleLabel.textColor = ToriumTheme.textSecondary
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontSizeToFitWidth = true

        balanceLabel.text = "0.0000"
        balanceLabel.font = UIFont.monospacedSystemFont(ofSize: 30, weight: .black)
        balanceLabel.textColor = ToriumTheme.textPrimary
        balanceLabel.textAlignment = .center
        balanceLabel.adjustsFontSizeToFitWidth = true
        balanceLabel.minimumScaleFactor = 0.7

        speedLabel.text = "Tốc độ: +0.000 TOR/h"
        speedLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        speedLabel.textColor = ToriumTheme.accentGold
        speedLabel.textAlignment = .center
        speedLabel.adjustsFontSizeToFitWidth = true

        centerStack.axis = .vertical
        centerStack.alignment = .center
        centerStack.spacing = 2
        centerStack.translatesAutoresizingMaskIntoConstraints = false
        centerStack.addArrangedSubview(coinIconView)
        centerStack.addArrangedSubview(titleLabel)
        centerStack.addArrangedSubview(balanceLabel)
        centerStack.addArrangedSubview(speedLabel)

        addSubview(centerStack)

        NSLayoutConstraint.activate([
            centerStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            centerStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            centerStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            centerStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28)
        ])
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = max(10, min(bounds.width, bounds.height) / 2 - 16)

        // 270 degree arc from 135 deg (3*pi/4) to 405 deg (9*pi/4)
        let startAngle: CGFloat = CGFloat.pi * 0.75
        let endAngle: CGFloat = CGFloat.pi * 2.25

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
    }

    public func update(balance: String, speed: String, progress: CGFloat) {
        balanceLabel.text = balance
        speedLabel.text = speed
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.35)
        progressLayer.strokeEnd = max(0.0, min(1.0, progress))
        CATransaction.commit()
    }
}

// MARK: - Dedicated Executive KPI Card View

public final class ExecutiveKPICard: UIView {
    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let mainValueLabel = UILabel()
    private let subValueLabel = UILabel()

    public init(title: String, mainValue: String, subValue: String, iconName: String, accentColor: UIColor) {
        super.init(frame: .zero)
        setupView(title: title, mainValue: mainValue, subValue: subValue, iconName: iconName, accentColor: accentColor)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setupView(title: String, mainValue: String, subValue: String, iconName: String, accentColor: UIColor) {
        ToriumTheme.applyCardStyle(to: self, radius: ToriumTheme.radiusCard)

        iconImageView.image = UIImage(systemName: iconName)
        iconImageView.tintColor = accentColor
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 10, weight: .heavy)
        titleLabel.textColor = ToriumTheme.textMuted
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.8
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        mainValueLabel.text = mainValue
        mainValueLabel.font = UIFont.systemFont(ofSize: 16, weight: .black)
        mainValueLabel.textColor = ToriumTheme.textPrimary
        mainValueLabel.adjustsFontSizeToFitWidth = true
        mainValueLabel.minimumScaleFactor = 0.75
        mainValueLabel.translatesAutoresizingMaskIntoConstraints = false

        subValueLabel.text = subValue
        subValueLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        subValueLabel.textColor = accentColor
        subValueLabel.adjustsFontSizeToFitWidth = true
        subValueLabel.minimumScaleFactor = 0.75
        subValueLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconImageView)
        addSubview(titleLabel)
        addSubview(mainValueLabel)
        addSubview(subValueLabel)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.centerYAnchor.constraint(equalTo: iconImageView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 6),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            mainValueLabel.topAnchor.constraint(equalTo: iconImageView.bottomAnchor, constant: 4),
            mainValueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            mainValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),

            subValueLabel.topAnchor.constraint(equalTo: mainValueLabel.bottomAnchor, constant: 2),
            subValueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            subValueLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            subValueLabel.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -8)
        ])
    }

    public func update(main: String, sub: String) {
        mainValueLabel.text = main
        subValueLabel.text = sub
    }
}
