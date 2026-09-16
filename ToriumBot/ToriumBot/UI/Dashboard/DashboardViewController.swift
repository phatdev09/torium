import UIKit

/// Dashboard tab presenting overview cards, realtime automation controls, Mode Switch (Eco ⇄ Turbo), and live accounts
public final class DashboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let statusBadge = UILabel()
    private let toggleButton = UIButton(type: .system)

    // Mode Switch Control (Eco vs Turbo)
    private let modeSwitchContainer = UIView()
    private let modeSegmentedControl = UISegmentedControl(items: ["🟢 Eco (3 Workers)", "🚀 Turbo (Tối Đa)"])
    private let workerStatusLabel = UILabel()

    private let cardsStackView = UIStackView()
    private let activeAccountsCard = SummaryCardView(title: "Active Accounts", value: "0", icon: "person.crop.circle.badge.checkmark")
    private let torTodayCard = SummaryCardView(title: "TOR Today", value: "0.00", icon: "bitcoinsign.circle")
    private let adsWatchedCard = SummaryCardView(title: "Ads Watched", value: "0", icon: "play.rectangle.fill")
    private let errorAccountsCard = SummaryCardView(title: "Accounts Lỗi", value: "0", icon: "exclamationmark.triangle.fill", isAlert: true)

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var accounts: [Account] = []
    private var statsMap: [Int64: MiningStats] = [:]
    private var refreshTimer: Timer?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Dashboard"

        setupHeader()
        setupModeSwitch()
        setupCards()
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

    private func setupHeader() {
        headerContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerContainer)

        titleLabel.text = "ToriumBot"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .heavy)
        titleLabel.textColor = ToriumTheme.textPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        statusBadge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        statusBadge.layer.cornerRadius = 6
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        toggleButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        toggleButton.layer.cornerRadius = 8
        toggleButton.addTarget(self, action: #selector(toggleEngine), for: .touchUpInside)
        toggleButton.translatesAutoresizingMaskIntoConstraints = false

        headerContainer.addSubview(titleLabel)
        headerContainer.addSubview(statusBadge)
        headerContainer.addSubview(toggleButton)

        NSLayoutConstraint.activate([
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 4),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerContainer.heightAnchor.constraint(equalToConstant: 40),

            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),

            statusBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 68),

            toggleButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            toggleButton.heightAnchor.constraint(equalToConstant: 30),
            toggleButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        updateEngineStatusUI()
    }

    private func setupModeSwitch() {
        modeSwitchContainer.translatesAutoresizingMaskIntoConstraints = false
        modeSwitchContainer.backgroundColor = ToriumTheme.cardBackground
        modeSwitchContainer.layer.cornerRadius = 10
        modeSwitchContainer.layer.borderColor = ToriumTheme.border.cgColor
        modeSwitchContainer.layer.borderWidth = 1
        view.addSubview(modeSwitchContainer)

        modeSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        modeSegmentedControl.selectedSegmentIndex = (WorkerPoolManager.shared.currentMode == .eco) ? 0 : 1
        modeSegmentedControl.selectedSegmentTintColor = ToriumTheme.accent
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 12, weight: .bold)], for: .selected)
        modeSegmentedControl.setTitleTextAttributes([.foregroundColor: UIColor.lightGray, .font: UIFont.systemFont(ofSize: 12, weight: .medium)], for: .normal)
        modeSegmentedControl.addTarget(self, action: #selector(onModeChanged), for: .valueChanged)

        workerStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        workerStatusLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        workerStatusLabel.textColor = ToriumTheme.textSecondary
        workerStatusLabel.textAlignment = .right
        updateWorkerStatusLabel()

        modeSwitchContainer.addSubview(modeSegmentedControl)
        modeSwitchContainer.addSubview(workerStatusLabel)

        NSLayoutConstraint.activate([
            modeSwitchContainer.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 6),
            modeSwitchContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            modeSwitchContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            modeSwitchContainer.heightAnchor.constraint(equalToConstant: 38),

            modeSegmentedControl.centerYAnchor.constraint(equalTo: modeSwitchContainer.centerYAnchor),
            modeSegmentedControl.leadingAnchor.constraint(equalTo: modeSwitchContainer.leadingAnchor, constant: 6),
            modeSegmentedControl.widthAnchor.constraint(equalToConstant: 210),

            workerStatusLabel.centerYAnchor.constraint(equalTo: modeSwitchContainer.centerYAnchor),
            workerStatusLabel.trailingAnchor.constraint(equalTo: modeSwitchContainer.trailingAnchor, constant: -10),
            workerStatusLabel.leadingAnchor.constraint(equalTo: modeSegmentedControl.trailingAnchor, constant: 6)
        ])
    }

    @objc private func onModeChanged() {
        let newMode: WorkerMode = (modeSegmentedControl.selectedSegmentIndex == 0) ? .eco : .turbo
        WorkerPoolManager.shared.setMode(newMode)
        updateWorkerStatusLabel()
    }

    private func updateWorkerStatusLabel() {
        let active = WorkerPoolManager.shared.activeWorkers
        let mode = WorkerPoolManager.shared.currentMode
        if mode == .eco {
            workerStatusLabel.text = "⚡ Đang chạy: \(active)/\(WorkerPoolManager.shared.maxConcurrentWorkers)"
        } else {
            workerStatusLabel.text = "⚡ Đang chạy: \(active) (Không giới hạn)"
        }
    }

    private func setupCards() {
        cardsStackView.axis = .vertical
        cardsStackView.spacing = 8
        cardsStackView.distribution = .fillEqually
        cardsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardsStackView)

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
            cardsStackView.topAnchor.constraint(equalTo: modeSwitchContainer.bottomAnchor, constant: 8),
            cardsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardsStackView.heightAnchor.constraint(equalToConstant: 125)
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = ToriumTheme.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        tableView.register(AccountSummaryCell.self, forCellReuseIdentifier: AccountSummaryCell.reuseIdentifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: cardsStackView.bottomAnchor, constant: 10),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    // MARK: - Data Management & Realtime Refresh

    private func loadData() {
        accounts = DatabaseManager.shared.getAllAccounts()

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let today = formatter.string(from: Date())

        var totalTor = 0.0
        var totalAds = 0
        var activeCount = 0
        var errorCount = 0

        statsMap.removeAll()
        for acc in accounts {
            guard let id = acc.id else { continue }
            let s = DatabaseManager.shared.getStats(accountId: id, date: today)
            statsMap[id] = s

            if acc.isActive && !acc.isBanned {
                activeCount += 1
                totalTor += (s?.torBalance ?? 0.0)
                totalAds += (s?.adsWatched ?? 0)
            }
            if acc.isBanned || acc.bearerToken == nil {
                errorCount += 1
            }
        }

        activeAccountsCard.setValue("\(activeCount)")
        torTodayCard.setValue(String(format: "%.2f", totalTor))
        adsWatchedCard.setValue("\(totalAds)")
        errorAccountsCard.setValue("\(errorCount)")

        updateWorkerStatusLabel()
        tableView.reloadData()
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.loadData()
            self?.updateEngineStatusUI()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Automation Engine Toggle

    @objc private func toggleEngine() {
        if MiningEngine.shared.isRunning {
            MiningEngine.shared.stop()
        } else {
            MiningEngine.shared.start()
        }
        updateEngineStatusUI()
    }

    private func updateEngineStatusUI() {
        let isRunning = MiningEngine.shared.isRunning
        if isRunning {
            statusBadge.text = "RUNNING"
            statusBadge.backgroundColor = ToriumTheme.success.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.success

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
        cell.configure(account: account, stats: stats)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 74
    }
}
