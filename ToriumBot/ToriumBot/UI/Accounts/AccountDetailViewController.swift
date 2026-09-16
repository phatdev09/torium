import UIKit

/// Detailed management screen for a single account
public final class AccountDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var account: Account
    private var todayStats: MiningStats?
    private var sevenDayHistory: [MiningStats] = []
    private var isTokenRevealed: Bool = false

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // UI Elements
    private let infoCard = UIView()
    private let emailLabel = UILabel()
    private let statusLabel = UILabel()
    private let tokenTitleLabel = UILabel()
    private let tokenValueLabel = UILabel()
    private let revealTokenButton = UIButton(type: .system)

    private let proxyCard = UIView()
    private let proxyInfoLabel = UILabel()
    private let editProxyButton = UIButton(type: .system)

    private let statsCard = UIView()
    private let statsInfoLabel = UILabel()

    private let historyTitleLabel = UILabel()
    private let historyTableView = UITableView(frame: .zero, style: .plain)

    private let actionsStack = UIStackView()
    private let pauseResumeButton = UIButton(type: .system)
    private let manualBackupButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)

    public init(account: Account) {
        self.account = account
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Chi tiết Account"

        setupScrollView()
        setupInfoCard()
        setupProxyCard()
        setupStatsCard()
        setupHistorySection()
        setupActionButtons()
        loadData()
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
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

    private func setupInfoCard() {
        ToriumTheme.applyCardStyle(to: infoCard)
        infoCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(infoCard)

        emailLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        emailLabel.textColor = ToriumTheme.textPrimary
        emailLabel.numberOfLines = 0
        emailLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        tokenTitleLabel.text = "Bearer Token (chạm để xem):"
        tokenTitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        tokenTitleLabel.textColor = ToriumTheme.textMuted
        tokenTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tokenValueLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        tokenValueLabel.textColor = ToriumTheme.accentGold
        tokenValueLabel.numberOfLines = 0
        tokenValueLabel.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleTokenReveal))
        tokenValueLabel.addGestureRecognizer(tap)
        tokenValueLabel.translatesAutoresizingMaskIntoConstraints = false

        infoCard.addSubview(emailLabel)
        infoCard.addSubview(statusLabel)
        infoCard.addSubview(tokenTitleLabel)
        infoCard.addSubview(tokenValueLabel)

        NSLayoutConstraint.activate([
            infoCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            infoCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            infoCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            emailLabel.topAnchor.constraint(equalTo: infoCard.topAnchor, constant: 14),
            emailLabel.leadingAnchor.constraint(equalTo: infoCard.leadingAnchor, constant: 14),
            emailLabel.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14),

            statusLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 6),
            statusLabel.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),

            tokenTitleLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 12),
            tokenTitleLabel.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),

            tokenValueLabel.topAnchor.constraint(equalTo: tokenTitleLabel.bottomAnchor, constant: 4),
            tokenValueLabel.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),
            tokenValueLabel.trailingAnchor.constraint(equalTo: infoCard.trailingAnchor, constant: -14),
            tokenValueLabel.bottomAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupProxyCard() {
        ToriumTheme.applyCardStyle(to: proxyCard)
        proxyCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(proxyCard)

        proxyInfoLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        proxyInfoLabel.textColor = ToriumTheme.textSecondary
        proxyInfoLabel.numberOfLines = 0
        proxyInfoLabel.translatesAutoresizingMaskIntoConstraints = false

        editProxyButton.setTitle("Sửa Proxy", for: .normal)
        editProxyButton.setTitleColor(ToriumTheme.accentGold, for: .normal)
        editProxyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        editProxyButton.addTarget(self, action: #selector(handleEditProxy), for: .touchUpInside)
        editProxyButton.translatesAutoresizingMaskIntoConstraints = false

        proxyCard.addSubview(proxyInfoLabel)
        proxyCard.addSubview(editProxyButton)

        NSLayoutConstraint.activate([
            proxyCard.topAnchor.constraint(equalTo: infoCard.bottomAnchor, constant: 12),
            proxyCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            proxyCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            proxyInfoLabel.topAnchor.constraint(equalTo: proxyCard.topAnchor, constant: 14),
            proxyInfoLabel.leadingAnchor.constraint(equalTo: proxyCard.leadingAnchor, constant: 14),
            proxyInfoLabel.trailingAnchor.constraint(equalTo: editProxyButton.leadingAnchor, constant: -8),
            proxyInfoLabel.bottomAnchor.constraint(equalTo: proxyCard.bottomAnchor, constant: -14),

            editProxyButton.centerYAnchor.constraint(equalTo: proxyCard.centerYAnchor),
            editProxyButton.trailingAnchor.constraint(equalTo: proxyCard.trailingAnchor, constant: -14),
            editProxyButton.widthAnchor.constraint(equalToConstant: 80)
        ])
    }

    private func setupStatsCard() {
        ToriumTheme.applyCardStyle(to: statsCard)
        statsCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statsCard)

        statsInfoLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        statsInfoLabel.textColor = ToriumTheme.textPrimary
        statsInfoLabel.numberOfLines = 0
        statsInfoLabel.translatesAutoresizingMaskIntoConstraints = false

        statsCard.addSubview(statsInfoLabel)

        NSLayoutConstraint.activate([
            statsCard.topAnchor.constraint(equalTo: proxyCard.bottomAnchor, constant: 12),
            statsCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            statsCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            statsInfoLabel.topAnchor.constraint(equalTo: statsCard.topAnchor, constant: 14),
            statsInfoLabel.leadingAnchor.constraint(equalTo: statsCard.leadingAnchor, constant: 14),
            statsInfoLabel.trailingAnchor.constraint(equalTo: statsCard.trailingAnchor, constant: -14),
            statsInfoLabel.bottomAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupHistorySection() {
        historyTitleLabel.text = "Lịch sử 7 ngày gần nhất"
        historyTitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        historyTitleLabel.textColor = ToriumTheme.textPrimary
        historyTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(historyTitleLabel)

        historyTableView.backgroundColor = .clear
        historyTableView.separatorColor = ToriumTheme.cardBorder
        historyTableView.dataSource = self
        historyTableView.delegate = self
        historyTableView.isScrollEnabled = false
        historyTableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
        historyTableView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(historyTableView)

        NSLayoutConstraint.activate([
            historyTitleLabel.topAnchor.constraint(equalTo: statsCard.bottomAnchor, constant: 16),
            historyTitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),

            historyTableView.topAnchor.constraint(equalTo: historyTitleLabel.bottomAnchor, constant: 8),
            historyTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            historyTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            historyTableView.heightAnchor.constraint(equalToConstant: 240)
        ])
    }

    private func setupActionButtons() {
        actionsStack.axis = .vertical
        actionsStack.spacing = 10
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionsStack)

        pauseResumeButton.layer.cornerRadius = ToriumTheme.cornerRadius
        pauseResumeButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        pauseResumeButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        pauseResumeButton.addTarget(self, action: #selector(togglePause), for: .touchUpInside)

        manualBackupButton.setTitle("Manual Backup (Gửi qua Telegram)", for: .normal)
        manualBackupButton.setTitleColor(UIColor.black, for: .normal)
        manualBackupButton.backgroundColor = ToriumTheme.accentGold
        manualBackupButton.layer.cornerRadius = ToriumTheme.cornerRadius
        manualBackupButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        manualBackupButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        manualBackupButton.addTarget(self, action: #selector(handleManualBackup), for: .touchUpInside)

        deleteButton.setTitle("Xóa Tài Khoản", for: .normal)
        deleteButton.setTitleColor(ToriumTheme.statusRed, for: .normal)
        deleteButton.backgroundColor = ToriumTheme.cardBackground
        deleteButton.layer.cornerRadius = ToriumTheme.cornerRadius
        deleteButton.layer.borderWidth = 1
        deleteButton.layer.borderColor = ToriumTheme.statusRed.cgColor
        deleteButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        deleteButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)

        actionsStack.addArrangedSubview(pauseResumeButton)
        actionsStack.addArrangedSubview(manualBackupButton)
        actionsStack.addArrangedSubview(deleteButton)

        NSLayoutConstraint.activate([
            actionsStack.topAnchor.constraint(equalTo: historyTableView.bottomAnchor, constant: 16),
            actionsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionsStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        ])
    }

    private func loadData() {
        emailLabel.text = account.email

        if account.isBanned {
            statusLabel.text = "Trạng thái: 🚫 Bị Ban"
            statusLabel.textColor = ToriumTheme.statusRed
        } else if !account.isActive {
            statusLabel.text = "Trạng thái: ⏸ Tạm Dừng"
            statusLabel.textColor = UIColor.lightGray
        } else {
            statusLabel.text = "Trạng thái: ✅ Đang Hoạt Động"
            statusLabel.textColor = ToriumTheme.statusGreen
        }

        updateTokenDisplay()

        let proxyStr = account.proxyString ?? "Không cấu hình (Kết nối trực tiếp)"
        proxyInfoLabel.text = "🌐 Proxy:\n\(proxyStr)"

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(secondsFromGMT: 7 * 3600)
        let todayDate = formatter.string(from: Date())

        if let id = account.id {
            todayStats = DatabaseManager.shared.getStats(accountId: id, date: todayDate)
            sevenDayHistory = DatabaseManager.shared.get7DayStats(accountId: id)
        }

        let balance = todayStats?.torBalance ?? 0.0
        let adsWatched = todayStats?.adsWatched ?? 0
        let rate = todayStats?.boostRate ?? 0.0
        statsInfoLabel.text = """
        📊 Mining Stats Hôm Nay:
        • Số dư TOR: \(String(format: "%.3f", balance)) TOR
        • Xem Ad hôm nay: \(adsWatched)/120
        • Tốc độ Boost: \(String(format: "%.3f", rate))
        """

        if account.isActive {
            pauseResumeButton.setTitle("Tạm dừng Account", for: .normal)
            pauseResumeButton.backgroundColor = ToriumTheme.cardBorder
            pauseResumeButton.setTitleColor(ToriumTheme.textPrimary, for: .normal)
        } else {
            pauseResumeButton.setTitle("Kích hoạt Account", for: .normal)
            pauseResumeButton.backgroundColor = ToriumTheme.statusGreen
            pauseResumeButton.setTitleColor(UIColor.black, for: .normal)
        }

        historyTableView.reloadData()
    }

    private func updateTokenDisplay() {
        guard let token = account.bearerToken, !token.isEmpty else {
            tokenValueLabel.text = "(Chưa trích xuất token)"
            return
        }
        if isTokenRevealed {
            tokenValueLabel.text = token
        } else {
            let masked = String(token.prefix(6)) + "••••••••••••••••••••" + String(token.suffix(4))
            tokenValueLabel.text = masked
        }
    }

    @objc private func toggleTokenReveal() {
        isTokenRevealed.toggle()
        updateTokenDisplay()
    }

    @objc private func handleEditProxy() {
        let alert = UIAlertController(title: "Cấu hình Proxy", message: "Nhập thông tin proxy (host, port, user, pass, proto)", preferredStyle: .alert)
        alert.addTextField { $0.placeholder = "Protocol (http/https/socks4/socks5)"; $0.text = self.account.proxyProtocol ?? "socks5" }
        alert.addTextField { $0.placeholder = "Host (IP hoặc domain)"; $0.text = self.account.proxyHost }
        alert.addTextField { $0.placeholder = "Port"; $0.keyboardType = .numberPad; $0.text = self.account.proxyPort != nil ? "\(self.account.proxyPort!)" : "" }
        alert.addTextField { $0.placeholder = "Username (tùy chọn)"; $0.text = self.account.proxyUsername }
        alert.addTextField { $0.placeholder = "Password (tùy chọn)"; $0.isSecureTextEntry = true; $0.text = self.account.proxyPassword }

        alert.addAction(UIAlertAction(title: "Lưu", style: .default, handler: { [weak self] _ in
            guard let self = self, let id = self.account.id else { return }
            let proto = alert.textFields?[0].text
            let host = alert.textFields?[1].text
            let portStr = alert.textFields?[2].text
            let port = portStr != nil ? Int(portStr!) : nil
            let user = alert.textFields?[3].text
            let pass = alert.textFields?[4].text

            DatabaseManager.shared.updateProxy(id: id, host: host, port: port, username: user, password: pass, proto: proto)
            self.account.proxyProtocol = proto
            self.account.proxyHost = host
            self.account.proxyPort = port
            self.account.proxyUsername = user
            self.account.proxyPassword = pass
            self.loadData()
        }))
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func togglePause() {
        account.isActive.toggle()
        DatabaseManager.shared.updateAccount(account)
        loadData()
    }

    @objc private func handleManualBackup() {
        Task {
            let res = await BackupManager.shared.backupSingleAccount(account: self.account)
            DispatchQueue.main.async {
                let alert = UIAlertController(title: res.success ? "Thành công" : "Lỗi", message: res.message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func handleDelete() {
        let alert = UIAlertController(title: "Xác nhận xóa", message: "Bạn có chắc chắn muốn xóa tài khoản \(account.email)?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Xóa", style: .destructive, handler: { [weak self] _ in
            guard let self = self, let id = self.account.id else { return }
            DatabaseManager.shared.deleteAccount(id: id)
            self.navigationController?.popViewController(animated: true)
        }))
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - History TableView DataSource

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sevenDayHistory.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        let item = sevenDayHistory[indexPath.row]
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.text = "Ngày: \(item.date) — Ad: \(item.adsWatched)/120"
        cell.textLabel?.textColor = ToriumTheme.textSecondary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .regular)

        cell.detailTextLabel?.text = "\(String(format: "%.3f", item.torBalance)) TOR"
        cell.detailTextLabel?.textColor = ToriumTheme.accentGold
        return cell
    }
}
