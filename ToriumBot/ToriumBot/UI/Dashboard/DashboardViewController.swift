import UIKit

/// Dashboard tab presenting overview cards, realtime automation controls, and live account states
public final class DashboardViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let headerContainer = UIView()
    private let titleLabel = UILabel()
    private let statusBadge = UILabel()
    private let toggleButton = UIButton(type: .system)

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
            headerContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            headerContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            headerContainer.heightAnchor.constraint(equalToConstant: 44),

            titleLabel.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: headerContainer.leadingAnchor),

            statusBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusBadge.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            statusBadge.heightAnchor.constraint(equalToConstant: 22),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 68),

            toggleButton.centerYAnchor.constraint(equalTo: headerContainer.centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: headerContainer.trailingAnchor),
            toggleButton.heightAnchor.constraint(equalToConstant: 32),
            toggleButton.widthAnchor.constraint(equalToConstant: 80)
        ])

        updateEngineStatusUI()
    }

    private func setupCards() {
        cardsStackView.axis = .vertical
        cardsStackView.spacing = 10
        cardsStackView.distribution = .fillEqually
        cardsStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cardsStackView)

        let row1 = UIStackView(arrangedSubviews: [activeAccountsCard, torTodayCard])
        row1.axis = .horizontal
        row1.spacing = 10
        row1.distribution = .fillEqually

        let row2 = UIStackView(arrangedSubviews: [adsWatchedCard, errorAccountsCard])
        row2.axis = .horizontal
        row2.spacing = 10
        row2.distribution = .fillEqually

        cardsStackView.addArrangedSubview(row1)
        cardsStackView.addArrangedSubview(row2)

        NSLayoutConstraint.activate([
            cardsStackView.topAnchor.constraint(equalTo: headerContainer.bottomAnchor, constant: 12),
            cardsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            cardsStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            cardsStackView.heightAnchor.constraint(equalToConstant: 140)
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(AccountSummaryCell.self, forCellReuseIdentifier: AccountSummaryCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: cardsStackView.bottomAnchor, constant: 14),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.loadData()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

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
            statusBadge.text = " RUNNING "
            statusBadge.backgroundColor = ToriumTheme.statusGreen.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.statusGreen

            toggleButton.setTitle("Pause", for: .normal)
            toggleButton.backgroundColor = ToriumTheme.cardBorder
            toggleButton.setTitleColor(ToriumTheme.textPrimary, for: .normal)
        } else {
            statusBadge.text = " PAUSED "
            statusBadge.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
            statusBadge.textColor = UIColor.lightGray

            toggleButton.setTitle("Start", for: .normal)
            toggleButton.backgroundColor = ToriumTheme.accentGold
            toggleButton.setTitleColor(UIColor.black, for: .normal)
        }
    }

    private func loadData() {
        let allAccounts = DatabaseManager.shared.getAllAccounts()
        self.accounts = allAccounts

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let todayDate = formatter.string(from: Date())

        let summary = DatabaseManager.shared.getTodaySummary(date: todayDate)

        activeAccountsCard.setValue("\(summary.totalActive)")
        torTodayCard.setValue(String(format: "%.2f", summary.totalTor))
        adsWatchedCard.setValue("\(summary.totalAds)")
        errorAccountsCard.setValue("\(summary.errorAccounts)")

        var newStatsMap: [Int64: MiningStats] = [:]
        for acc in allAccounts {
            if let id = acc.id, let stats = DatabaseManager.shared.getStats(accountId: id, date: todayDate) {
                newStatsMap[id] = stats
            }
        }
        self.statsMap = newStatsMap

        tableView.reloadData()
        updateEngineStatusUI()
    }

    // MARK: - UITableViewDataSource & Delegate

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: AccountSummaryCell.reuseIdentifier, for: indexPath) as? AccountSummaryCell else {
            return UITableViewCell()
        }

        let acc = accounts[indexPath.row]
        let stats = acc.id != nil ? statsMap[acc.id!] : nil
        cell.configure(with: acc, stats: stats)
        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 88.0
    }
}

// MARK: - Reusable Summary Card View

public final class SummaryCardView: UIView {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let iconView = UIImageView()

    public init(title: String, value: String, icon: String, isAlert: Bool = false) {
        super.init(frame: .zero)
        ToriumTheme.applyCardStyle(to: self)

        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = ToriumTheme.textSecondary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        valueLabel.textColor = isAlert ? ToriumTheme.statusRed : ToriumTheme.accentGold
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        iconView.image = UIImage(systemName: icon)
        iconView.tintColor = isAlert ? ToriumTheme.statusRed : ToriumTheme.accentGold
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(valueLabel)
        addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            iconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: iconView.leadingAnchor, constant: -4),

            valueLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setValue(_ value: String) {
        valueLabel.text = value
    }
}
