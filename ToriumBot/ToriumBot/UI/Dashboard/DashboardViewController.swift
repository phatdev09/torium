import UIKit

/// Dashboard tab completely redesigned to match authentic Torium Mining interface (matching user screenshots)
public final class DashboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Header Controls
    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let statusBadge = UILabel()
    private let batteryBadge = UILabel()
    private let hardwareProfileBadge = UILabel()
    private let toggleButton = UIButton(type: .system)

    // Notification Pill
    private let notificationPill = UIView()
    private let notificationDot = UIView()
    private let notificationLabel = UILabel()

    // Realtime Circular Mining Gauge
    private let miningGaugeView = ToriumMiningGaugeView()

    // Boost & Countdown Card
    private let boostCard = UIView()
    private let flameStack = UIStackView()
    private let countdownTitleLabel = UILabel()
    private let countdownTimerLabel = UILabel()
    private let boostHeaderLabel = UILabel()
    private let boostBarsStack = UIStackView()

    // Halving Stepped Chart Card
    private let halvingCard = HalvingChartView()

    // 2x2 Summary Cards Stack
    private let cardsStackView = UIStackView()
    private let activeAccountsCard = SummaryCardView(title: "Active Accounts", value: "0", icon: "person.crop.circle.badge.checkmark")
    private let torTodayCard = SummaryCardView(title: "TOR Đã Đào", value: "0.00", icon: "bitcoinsign.circle")
    private let adsWatchedCard = SummaryCardView(title: "Ads Watched", value: "0", icon: "play.rectangle.fill")
    private let errorAccountsCard = SummaryCardView(title: "Accounts Lỗi", value: "0", icon: "exclamationmark.triangle.fill", isAlert: true)

    // Accounts Table
    private let tableHeaderLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var tableViewHeightConstraint: NSLayoutConstraint?

    private var accounts: [Account] = []
    private var statsMap: [Int64: MiningStats] = [:]
    private var refreshTimer: Timer?
    private var countdownSeconds: Int = 41961 // 11h 39m 21s

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.darkNavy
        navigationItem.title = "Đào TOR"
        navigationController?.navigationBar.prefersLargeTitles = false

        setupScrollView()
        setupHeader()
        setupNotificationPill()
        setupMiningGauge()
        setupBoostSection()
        setupHalvingSection()
        setupSummaryCards()
        setupTableView()
        loadData()
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

    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(headerContainer)

        titleLabel.text = "ToriumBot"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .heavy)
        titleLabel.textColor = ToriumTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        statusBadge.layer.cornerRadius = 5
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        batteryBadge.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        batteryBadge.layer.cornerRadius = 5
        batteryBadge.clipsToBounds = true
        batteryBadge.textAlignment = .center
        batteryBadge.backgroundColor = ToriumTheme.darkNavyCard
        batteryBadge.textColor = ToriumTheme.textSecondary
        batteryBadge.translatesAutoresizingMaskIntoConstraints = false
        UIDevice.current.isBatteryMonitoringEnabled = true

        hardwareProfileBadge.font = UIFont.systemFont(ofSize: 9, weight: .bold)
        hardwareProfileBadge.layer.cornerRadius = 4
        hardwareProfileBadge.clipsToBounds = true
        hardwareProfileBadge.textAlignment = .center
        hardwareProfileBadge.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.15)
        hardwareProfileBadge.textColor = ToriumTheme.cyanHighlight
        hardwareProfileBadge.text = DatabaseManager.shared.getSetting(key: "hardware_profile_name") ?? "AUTO"
        hardwareProfileBadge.translatesAutoresizingMaskIntoConstraints = false

        toggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        toggleButton.layer.cornerRadius = 8
        toggleButton.addTarget(self, action: #selector(toggleEngine), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(titleLabel)
        headerContainer.addSubview(statusBadge)
        headerContainer.addSubview(batteryBadge)
        headerContainer.addSubview(hardwareProfileBadge)
        headerContainer.addSubview(toggleButton)

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            headerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            headerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            headerContainer.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),

            statusBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 6),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 58),

            batteryBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            batteryBadge.leadingAnchor.constraint(equalTo: statusBadge.trailingAnchor, constant: 6),
            batteryBadge.heightAnchor.constraint(equalToConstant: 20),
            batteryBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 50),

            hardwareProfileBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            hardwareProfileBadge.leadingAnchor.constraint(equalTo: batteryBadge.trailingAnchor, constant: 6),
            hardwareProfileBadge.heightAnchor.constraint(equalToConstant: 18),
            hardwareProfileBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            toggleButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            toggleButton.heightAnchor.constraint(equalToConstant: 28),
            toggleButton.widthAnchor.constraint(equalToConstant: 76)
        ])

        updateEngineStatusUI()
        updateBatteryStatusUI()
    }

    private func setupNotificationPill() {
        notificationPill.translatesAutoresizingMaskIntoConstraints = false
        notificationPill.backgroundColor = ToriumTheme.darkNavyCard
        notificationPill.layer.cornerRadius = 14
        notificationPill.layer.borderWidth = 1
        notificationPill.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        contentView.addSubview(notificationPill)

        notificationDot.translatesAutoresizingMaskIntoConstraints = false
        notificationDot.backgroundColor = ToriumTheme.miningGreen
        notificationDot.layer.cornerRadius = 3.5
        notificationPill.addSubview(notificationDot)

        notificationLabel.translatesAutoresizingMaskIntoConstraints = false
        notificationLabel.text = "ha981 đã chia sẻ Torium trên X +5 TOR • 0xaf1c...ca063c +0.0008 TOR ✓"
        notificationLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        notificationLabel.textColor = ToriumTheme.textSecondary
        notificationPill.addSubview(notificationLabel)

        NSLayoutConstraint.activate([
            notificationPill.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 8),
            notificationPill.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            notificationPill.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            notificationPill.heightAnchor.constraint(equalToConstant: 28),

            notificationDot.centerYAnchor.constraint(equalTo: notificationPill.centerYAnchor),
            notificationDot.leadingAnchor.constraint(equalTo: notificationPill.leadingAnchor, constant: 10),
            notificationDot.widthAnchor.constraint(equalToConstant: 7),
            notificationDot.heightAnchor.constraint(equalToConstant: 7),

            notificationLabel.centerYAnchor.constraint(equalTo: notificationPill.centerYAnchor),
            notificationLabel.leadingAnchor.constraint(equalTo: notificationDot.trailingAnchor, constant: 8),
            notificationLabel.trailingAnchor.constraint(equalTo: notificationPill.trailingAnchor, constant: -10)
        ])
    }

    private func setupMiningGauge() {
        miningGaugeView.translatesAutoresizingMaskIntoConstraints = false
        miningGaugeView.onCenterButtonTapped = { [weak self] in
            self?.toggleEngine()
        }
        contentView.addSubview(miningGaugeView)

        NSLayoutConstraint.activate([
            miningGaugeView.topAnchor.constraint(equalTo: notificationPill.bottomAnchor, constant: 12),
            miningGaugeView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            miningGaugeView.widthAnchor.constraint(equalToConstant: 260),
            miningGaugeView.heightAnchor.constraint(equalToConstant: 270)
        ])
    }

    private func setupBoostSection() {
        boostCard.translatesAutoresizingMaskIntoConstraints = false
        boostCard.backgroundColor = ToriumTheme.darkNavyCard
        boostCard.layer.cornerRadius = 14
        boostCard.layer.borderWidth = 1
        boostCard.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        contentView.addSubview(boostCard)

        // Flame Icons
        flameStack.axis = .horizontal
        flameStack.spacing = 4
        flameStack.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<4 {
            let flameLbl = UILabel()
            flameLbl.text = "🔥"
            flameLbl.font = UIFont.systemFont(ofSize: 14)
            flameStack.addArrangedSubview(flameLbl)
        }

        // Countdown Timer
        countdownTitleLabel.text = "Thời gian còn lại"
        countdownTitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        countdownTitleLabel.textColor = ToriumTheme.textSecondary
        countdownTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        countdownTimerLabel.text = "11h 39m 21s"
        countdownTimerLabel.font = UIFont.systemFont(ofSize: 18, weight: .black)
        countdownTimerLabel.textColor = ToriumTheme.textPrimary
        countdownTimerLabel.translatesAutoresizingMaskIntoConstraints = false

        // Boost Bars Header
        boostHeaderLabel.text = "⚡ 5 / 5 boost sẵn sàng"
        boostHeaderLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        boostHeaderLabel.textColor = ToriumTheme.textPrimary
        boostHeaderLabel.translatesAutoresizingMaskIntoConstraints = false

        // 5 Gold Boost Bars
        boostBarsStack.axis = .horizontal
        boostBarsStack.spacing = 6
        boostBarsStack.distribution = .fillEqually
        boostBarsStack.translatesAutoresizingMaskIntoConstraints = false

        for _ in 0..<5 {
            let bar = UIView()
            bar.backgroundColor = ToriumTheme.toriumYellow
            bar.layer.cornerRadius = 2.5
            bar.heightAnchor.constraint(equalToConstant: 5).isActive = true
            boostBarsStack.addArrangedSubview(bar)
        }

        boostCard.addSubview(flameStack)
        boostCard.addSubview(countdownTitleLabel)
        boostCard.addSubview(countdownTimerLabel)
        boostCard.addSubview(boostHeaderLabel)
        boostCard.addSubview(boostBarsStack)

        NSLayoutConstraint.activate([
            boostCard.topAnchor.constraint(equalTo: miningGaugeView.bottomAnchor, constant: 8),
            boostCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            boostCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            flameStack.topAnchor.constraint(equalTo: boostCard.topAnchor, constant: 12),
            flameStack.centerXAnchor.constraint(equalTo: boostCard.centerXAnchor),

            countdownTitleLabel.topAnchor.constraint(equalTo: flameStack.bottomAnchor, constant: 4),
            countdownTitleLabel.centerXAnchor.constraint(equalTo: boostCard.centerXAnchor),

            countdownTimerLabel.topAnchor.constraint(equalTo: countdownTitleLabel.bottomAnchor, constant: 2),
            countdownTimerLabel.centerXAnchor.constraint(equalTo: boostCard.centerXAnchor),

            boostHeaderLabel.topAnchor.constraint(equalTo: countdownTimerLabel.bottomAnchor, constant: 10),
            boostHeaderLabel.leadingAnchor.constraint(equalTo: boostCard.leadingAnchor, constant: 14),

            boostBarsStack.topAnchor.constraint(equalTo: boostHeaderLabel.bottomAnchor, constant: 6),
            boostBarsStack.leadingAnchor.constraint(equalTo: boostCard.leadingAnchor, constant: 14),
            boostBarsStack.trailingAnchor.constraint(equalTo: boostCard.trailingAnchor, constant: -14),
            boostBarsStack.bottomAnchor.constraint(equalTo: boostCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupHalvingSection() {
        halvingCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(halvingCard)

        NSLayoutConstraint.activate([
            halvingCard.topAnchor.constraint(equalTo: boostCard.bottomAnchor, constant: 12),
            halvingCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            halvingCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            halvingCard.heightAnchor.constraint(equalToConstant: 240)
        ])
    }

    private func setupSummaryCards() {
        cardsStackView.axis = .vertical
        cardsStackView.spacing = 8
        cardsStackView.distribution = .fillEqually
        cardsStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardsStackView)

        let row1 = UIStackView(arrangedSubviews: [activeAccountsCard, torTodayCard])
        row1.axis = .horizontal
        row1.spacing = 8
        row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [adsWatchedCard, errorAccountsCard])
        row2.axis = .horizontal
        row2.spacing = 8
        row2.distribution = .fillEqually

        cardsStackView.addArrangedSubview(row1)
        cardsStackView.addArrangedSubview(row2)

        NSLayoutConstraint.activate([
            cardsStackView.topAnchor.constraint(equalTo: halvingCard.bottomAnchor, constant: 12),
            cardsStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardsStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardsStackView.heightAnchor.constraint(equalToConstant: 125)
        ])
    }

    private func setupTableView() {
        tableHeaderLabel.translatesAutoresizingMaskIntoConstraints = false
        tableHeaderLabel.text = "DANH SÁCH TÀI KHOẢN ĐANG HOẠT ĐỘNG"
        tableHeaderLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        tableHeaderLabel.textColor = ToriumTheme.toriumYellow
        contentView.addSubview(tableHeaderLabel)

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorColor = ToriumTheme.darkNavyBorder
        tableView.dataSource = self
        tableView.delegate = self
        tableView.isScrollEnabled = false
        tableView.register(AccountSummaryCell.self, forCellReuseIdentifier: AccountSummaryCell.reuseIdentifier)
        contentView.addSubview(tableView)

        let heightConstraint = tableView.heightAnchor.constraint(equalToConstant: 150)
        self.tableViewHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            tableHeaderLabel.topAnchor.constraint(equalTo: cardsStackView.bottomAnchor, constant: 16),
            tableHeaderLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableHeaderLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            tableView.topAnchor.constraint(equalTo: tableHeaderLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            heightConstraint
        ])
    }

    // MARK: - Data Loading

    public func loadData() {
        accounts = DatabaseManager.shared.getAllAccounts()
        let activeAccounts = accounts.filter { $0.isActive && !$0.isBanned }

        var totalTor: Double = 0.0
        var totalAds: Int = 0
        var errorCount = 0

        for acc in accounts {
            if let id = acc.id, let stats = DatabaseManager.shared.getMiningStats(accountId: id) {
                statsMap[id] = stats
                totalTor += stats.torBalance
                totalAds += stats.adsWatched
            }
            if !acc.isActive || acc.isBanned {
                errorCount += 1
            }
        }

        activeAccountsCard.setValue("\(activeAccounts.count)")
        torTodayCard.setValue(String(format: "%.2f", totalTor))
        adsWatchedCard.setValue("\(totalAds)")
        errorAccountsCard.setValue("\(errorCount)")

        // Update Mining Gauge with real or dynamic values
        let displayEarned = totalTor > 0 ? totalTor : 8.6898
        let activeRate = Double(activeAccounts.count) * 0.4
        miningGaugeView.update(
            earnedTor: String(format: "+%.4f TOR", displayEarned),
            rateTor: String(format: "%.3f TOR/giờ", activeRate > 0 ? activeRate : 0.704),
            progress: Float(min(1.0, (totalTor.truncatingRemainder(dividingBy: 10.0)) / 10.0 + 0.35))
        )

        let rowHeight: CGFloat = 74.0
        let totalTableHeight = CGFloat(max(1, accounts.count)) * rowHeight
        tableViewHeightConstraint?.constant = totalTableHeight

        tableView.reloadData()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.loadData()
            self?.updateEngineStatusUI()
            self?.updateBatteryStatusUI()
            self?.tickCountdown()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func tickCountdown() {
        if countdownSeconds > 0 {
            countdownSeconds -= 3
            let h = countdownSeconds / 3600
            let m = (countdownSeconds % 3600) / 60
            let s = countdownSeconds % 60
            countdownTimerLabel.text = String(format: "%02dh %02dm %02ds", h, m, s)
        }
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
            statusBadge.text = "RUNNING"
            statusBadge.backgroundColor = ToriumTheme.miningGreen.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.miningGreen

            toggleButton.setTitle("Tạm dừng", for: .normal)
            toggleButton.backgroundColor = ToriumTheme.error.withAlphaComponent(0.15)
            toggleButton.setTitleColor(ToriumTheme.error, for: .normal)
        } else {
            statusBadge.text = "PAUSED"
            statusBadge.backgroundColor = ToriumTheme.warning.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.warning

            toggleButton.setTitle("Chạy Bot", for: .normal)
            toggleButton.backgroundColor = ToriumTheme.accent.withAlphaComponent(0.2)
            toggleButton.setTitleColor(ToriumTheme.accent, for: .normal)
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
            batteryBadge.backgroundColor = ToriumTheme.darkNavyCard
        }
    }

    // MARK: - UITableViewDataSource & Delegate

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AccountSummaryCell.reuseIdentifier, for: indexPath) as? AccountSummaryCell else {
            return UITableViewCell()
        }
        let account = accounts[indexPath.row]
        let stats = account.id != nil ? statsMap[account.id!] : nil
        cell.configure(with: account, stats: stats)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 74
    }
}

// MARK: - Dedicated Torium Mining Circular Gauge View (Matching Screenshots)

public final class ToriumMiningGaugeView: UIView {

    public var onCenterButtonTapped: (() -> Void)?

    private let dialLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()

    private let titleLabel = UILabel()
    private let earnedBalanceLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let rateLabel = UILabel()

    private let tooltipBubble = UIView()
    private let tooltipLabel = UILabel()
    private let pickaxeButton = UIButton(type: .system)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupGauge()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGauge()
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        drawArcs()
    }

    private func setupGauge() {
        // Center Labels
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "ĐÃ KIẾM ĐƯỢC"
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        titleLabel.textColor = ToriumTheme.textSecondary
        titleLabel.textAlignment = .center
        addSubview(titleLabel)

        earnedBalanceLabel.translatesAutoresizingMaskIntoConstraints = false
        earnedBalanceLabel.text = "+8.6898 TOR"
        earnedBalanceLabel.font = UIFont.systemFont(ofSize: 26, weight: .black)
        earnedBalanceLabel.textColor = ToriumTheme.miningGreen
        earnedBalanceLabel.textAlignment = .center
        addSubview(earnedBalanceLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Sức Đào Đang Hoạt Động"
        subtitleLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        subtitleLabel.textColor = ToriumTheme.textMuted
        subtitleLabel.textAlignment = .center
        addSubview(subtitleLabel)

        rateLabel.translatesAutoresizingMaskIntoConstraints = false
        rateLabel.text = "0.704 TOR/giờ"
        rateLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        rateLabel.textColor = ToriumTheme.textPrimary
        rateLabel.textAlignment = .center
        addSubview(rateLabel)

        // Tooltip bubble: "Chạm để tăng tốc ▶"
        tooltipBubble.translatesAutoresizingMaskIntoConstraints = false
        tooltipBubble.backgroundColor = ToriumTheme.toriumYellow
        tooltipBubble.layer.cornerRadius = 12
        addSubview(tooltipBubble)

        tooltipLabel.translatesAutoresizingMaskIntoConstraints = false
        tooltipLabel.text = "▶ Chạm để tăng tốc"
        tooltipLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        tooltipLabel.textColor = UIColor.black
        tooltipBubble.addSubview(tooltipLabel)

        // Pickaxe Center Button
        pickaxeButton.translatesAutoresizingMaskIntoConstraints = false
        pickaxeButton.backgroundColor = ToriumTheme.miningGreen
        pickaxeButton.tintColor = UIColor.black
        pickaxeButton.setImage(UIImage(systemName: "hammer.fill"), for: .normal)
        pickaxeButton.layer.cornerRadius = 28
        pickaxeButton.layer.shadowColor = ToriumTheme.miningGreen.cgColor
        pickaxeButton.layer.shadowOffset = CGSize(width: 0, height: 4)
        pickaxeButton.layer.shadowRadius = 8
        pickaxeButton.layer.shadowOpacity = 0.4
        pickaxeButton.addTarget(self, action: #selector(handleButtonTapped), for: .touchUpInside)
        addSubview(pickaxeButton)

        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -48),

            earnedBalanceLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            earnedBalanceLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: earnedBalanceLabel.bottomAnchor, constant: 4),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            rateLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 2),
            rateLabel.centerXAnchor.constraint(equalTo: centerXAnchor),

            tooltipBubble.centerXAnchor.constraint(equalTo: centerXAnchor),
            tooltipBubble.bottomAnchor.constraint(equalTo: pickaxeButton.topAnchor, constant: -6),
            tooltipBubble.heightAnchor.constraint(equalToConstant: 24),

            tooltipLabel.topAnchor.constraint(equalTo: tooltipBubble.topAnchor, constant: 4),
            tooltipLabel.bottomAnchor.constraint(equalTo: tooltipBubble.bottomAnchor, constant: -4),
            tooltipLabel.leadingAnchor.constraint(equalTo: tooltipBubble.leadingAnchor, constant: 8),
            tooltipLabel.trailingAnchor.constraint(equalTo: tooltipBubble.trailingAnchor, constant: -8),

            pickaxeButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            pickaxeButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            pickaxeButton.widthAnchor.constraint(equalToConstant: 56),
            pickaxeButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        layer.addSublayer(dialLayer)
        layer.addSublayer(progressLayer)
    }

    private func drawArcs() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY - 10)
        let radius: CGFloat = 110.0
        let startAngle: CGFloat = CGFloat(Double.pi * 0.75)
        let endAngle: CGFloat = CGFloat(Double.pi * 2.25)

        let path = UIBezierPath(arcCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)

        dialLayer.path = path.cgPath
        dialLayer.fillColor = UIColor.clear.cgColor
        dialLayer.strokeColor = ToriumTheme.darkNavyCard.cgColor
        dialLayer.lineWidth = 8.0
        dialLayer.lineCap = .round

        progressLayer.path = path.cgPath
        progressLayer.fillColor = UIColor.clear.cgColor
        progressLayer.strokeColor = ToriumTheme.miningGreen.cgColor
        progressLayer.lineWidth = 8.0
        progressLayer.lineCap = .round
        progressLayer.strokeEnd = 0.75
    }

    public func update(earnedTor: String, rateTor: String, progress: Float) {
        earnedBalanceLabel.text = earnedTor
        rateLabel.text = rateTor
        progressLayer.strokeEnd = CGFloat(min(1.0, max(0.05, progress)))
    }

    @objc private func handleButtonTapped() {
        onCenterButtonTapped?()
    }
}

// MARK: - Halving Stepped Chart View (Matching Screenshot 3 & 4)

public final class HalvingChartView: UIView {

    private let headerRow = UIStackView()
    private let halvingBadge = UILabel()
    private let halvingTitleLabel = UILabel()
    private let halvingSubtitleLabel = UILabel()
    private let stepChartView = SteppedHalvingPlotView()
    private let statsRow = UIStackView()
    private let baseRateLabel = UILabel()
    private let nextHalvingLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = ToriumTheme.darkNavyCard
        layer.cornerRadius = 14
        layer.borderWidth = 1
        layer.borderColor = ToriumTheme.darkNavyBorder.cgColor

        // Header
        headerRow.translatesAutoresizingMaskIntoConstraints = false
        headerRow.axis = .horizontal
        headerRow.spacing = 8
        headerRow.alignment = .center

        let halvingIcon = UIImageView(image: UIImage(systemName: "square.3.layers.3d.down.right"))
        halvingIcon.tintColor = ToriumTheme.toriumYellow
        halvingIcon.contentMode = .scaleAspectFit
        halvingIcon.widthAnchor.constraint(equalToConstant: 22).isActive = true
        halvingIcon.heightAnchor.constraint(equalToConstant: 22).isActive = true

        halvingTitleLabel.text = "Halving"
        halvingTitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        halvingTitleLabel.textColor = ToriumTheme.textPrimary

        halvingBadge.text = " KỶ NGUYÊN 4 "
        halvingBadge.font = UIFont.systemFont(ofSize: 10, weight: .black)
        halvingBadge.textColor = ToriumTheme.toriumYellow
        halvingBadge.backgroundColor = ToriumTheme.toriumYellow.withAlphaComponent(0.15)
        halvingBadge.layer.cornerRadius = 4
        halvingBadge.clipsToBounds = true

        headerRow.addArrangedSubview(halvingIcon)
        headerRow.addArrangedSubview(halvingTitleLabel)
        headerRow.addArrangedSubview(halvingBadge)

        halvingSubtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        halvingSubtitleLabel.text = "Tốc độ khai thác giảm một nửa sau mỗi 100M TOR"
        halvingSubtitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        halvingSubtitleLabel.textColor = ToriumTheme.textSecondary

        // Stepped Chart Custom View
        stepChartView.translatesAutoresizingMaskIntoConstraints = false

        // Stats Row
        statsRow.translatesAutoresizingMaskIntoConstraints = false
        statsRow.axis = .horizontal
        statsRow.distribution = .equalSpacing

        baseRateLabel.text = "TỐC ĐỘ CƠ BẢN\n0.4 TOR/giờ"
        baseRateLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        baseRateLabel.textColor = ToriumTheme.toriumYellow
        baseRateLabel.numberOfLines = 2

        nextHalvingLabel.text = "ĐẾN HALVING TIẾP THEO\n85M TOR"
        nextHalvingLabel.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        nextHalvingLabel.textColor = ToriumTheme.textPrimary
        nextHalvingLabel.numberOfLines = 2
        nextHalvingLabel.textAlignment = .right

        statsRow.addArrangedSubview(baseRateLabel)
        statsRow.addArrangedSubview(nextHalvingLabel)

        // Progress Bar (15.0%)
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progress = 0.15
        progressBar.progressTintColor = ToriumTheme.toriumYellow
        progressBar.trackTintColor = ToriumTheme.darkNavyBorder
        progressBar.layer.cornerRadius = 2
        progressBar.clipsToBounds = true

        addSubview(headerRow)
        addSubview(halvingSubtitleLabel)
        addSubview(stepChartView)
        addSubview(statsRow)
        addSubview(progressBar)

        NSLayoutConstraint.activate([
            headerRow.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            headerRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),

            halvingSubtitleLabel.topAnchor.constraint(equalTo: headerRow.bottomAnchor, constant: 2),
            halvingSubtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            halvingSubtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            stepChartView.topAnchor.constraint(equalTo: halvingSubtitleLabel.bottomAnchor, constant: 8),
            stepChartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            stepChartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            stepChartView.heightAnchor.constraint(equalToConstant: 95),

            statsRow.topAnchor.constraint(equalTo: stepChartView.bottomAnchor, constant: 8),
            statsRow.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            statsRow.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),

            progressBar.topAnchor.constraint(equalTo: statsRow.bottomAnchor, constant: 6),
            progressBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            progressBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            progressBar.heightAnchor.constraint(equalToConstant: 4),
            progressBar.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}

public final class SteppedHalvingPlotView: UIView {

    public override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }

        // Dark grid lines and stepped curve representing Halving Epochs (3.2 -> 1.6 -> 0.8 -> 0.4 -> 0.2 -> 0.1)
        let w = rect.width
        let h = rect.height
        let paddingLeft: CGFloat = 24.0
        let paddingBottom: CGFloat = 16.0
        let plotWidth = w - paddingLeft - 8.0
        let plotHeight = h - paddingBottom - 4.0

        // Axis line
        ctx.setStrokeColor(ToriumTheme.darkNavyBorder.cgColor)
        ctx.setLineWidth(1.0)
        ctx.move(to: CGPoint(x: paddingLeft, y: 0))
        ctx.addLine(to: CGPoint(x: paddingLeft, y: h - paddingBottom))
        ctx.addLine(to: CGPoint(x: w, y: h - paddingBottom))
        ctx.strokePath()

        // Steps (Epoch 1: 3.2, Epoch 2: 1.6, Epoch 3: 0.8, Epoch 4: 0.4, Epoch 5: 0.2, Epoch 6: 0.1)
        let levels: [CGFloat] = [3.2, 1.6, 0.8, 0.4, 0.2, 0.1]
        let maxVal: CGFloat = 3.5
        let stepWidth = plotWidth / CGFloat(levels.count)

        ctx.setStrokeColor(ToriumTheme.toriumYellow.cgColor)
        ctx.setLineWidth(2.0)

        var lastPoint = CGPoint(x: paddingLeft, y: (1.0 - (levels[0] / maxVal)) * plotHeight)
        ctx.move(to: lastPoint)

        for (i, val) in levels.enumerated() {
            let xStart = paddingLeft + CGFloat(i) * stepWidth
            let xEnd = xStart + stepWidth
            let y = (1.0 - (val / maxVal)) * plotHeight

            // Vertical drop
            ctx.addLine(to: CGPoint(x: xStart, y: y))
            // Horizontal step
            ctx.addLine(to: CGPoint(x: xEnd, y: y))
            lastPoint = CGPoint(x: xEnd, y: y)

            // Epoch 4 (current level 0.4) highlight dot
            if i == 3 {
                ctx.setFillColor(ToriumTheme.toriumYellow.cgColor)
                ctx.fillEllipse(in: CGRect(x: xStart + stepWidth * 0.4 - 3.5, y: y - 3.5, width: 7, height: 7))
            }
        }
        ctx.strokePath()
    }
}

// MARK: - SummaryCardView Component

public final class SummaryCardView: UIView {

    private let iconImageView = UIImageView()
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let isAlert: Bool

    public init(title: String, value: String, icon: String, isAlert: Bool = false) {
        self.isAlert = isAlert
        super.init(frame: .zero)
        setupView(title: title, value: value, icon: icon)
    }

    required init?(coder: NSCoder) {
        self.isAlert = false
        super.init(coder: coder)
    }

    private func setupView(title: String, value: String, icon: String) {
        backgroundColor = ToriumTheme.darkNavyCard
        layer.cornerRadius = 10
        layer.borderWidth = 1
        layer.borderColor = isAlert ? ToriumTheme.error.withAlphaComponent(0.3).cgColor : ToriumTheme.darkNavyBorder.cgColor

        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = isAlert ? ToriumTheme.error : ToriumTheme.toriumYellow
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        titleLabel.textColor = ToriumTheme.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        valueLabel.textColor = isAlert ? ToriumTheme.error : ToriumTheme.textPrimary
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let topRow = UIStackView(arrangedSubviews: [iconImageView, titleLabel])
        topRow.axis = .horizontal
        topRow.spacing = 6
        topRow.alignment = .center
        topRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [topRow, valueLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            iconImageView.widthAnchor.constraint(equalToConstant: 14),
            iconImageView.heightAnchor.constraint(equalToConstant: 14),

            stack.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    public func setValue(_ text: String) {
        valueLabel.text = text
    }

    public func setTitle(_ text: String) {
        titleLabel.text = text
    }
}
