import UIKit

/// Cinematic Developer Console for Realtime Logs with filter tabs, color-coding, and clear controls
public final class LogsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let filterSegment = UISegmentedControl(items: ["All", "INFO", "WARN", "ERROR"])
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var logs: [Log] = []
    private var currentFilter: LogLevel? = nil

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Realtime Logs"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Xóa",
            style: .plain,
            target: self,
            action: #selector(handleClearLogs)
        )
        navigationItem.rightBarButtonItem?.tintColor = ToriumTheme.accentGold

        setupSegment()
        setupTableView()
        loadLogs()
        listenForRealtimeLogs()
    }

    private func setupSegment() {
        filterSegment.selectedSegmentIndex = 0
        ToriumTheme.styleSegmentedControl(filterSegment)
        filterSegment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterSegment)

        NSLayoutConstraint.activate([
            filterSegment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filterSegment.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(LogConsoleCell.self, forCellReuseIdentifier: LogConsoleCell.reuseIdentifier)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: filterSegment.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func listenForRealtimeLogs() {
        DatabaseManager.shared.onNewLogAdded = { [weak self] newLog in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if self.currentFilter == nil || self.currentFilter == newLog.level {
                    self.logs.insert(newLog, at: 0)
                    self.tableView.insertRows(at: [IndexPath(row: 0, section: 0)], with: .automatic)
                }
            }
        }
    }

    private func loadLogs() {
        self.logs = DatabaseManager.shared.getRecentLogs(limit: 200, level: currentFilter)
        tableView.reloadData()
    }

    @objc private func filterChanged() {
        switch filterSegment.selectedSegmentIndex {
        case 1:
            currentFilter = .info
        case 2:
            currentFilter = .warn
        case 3:
            currentFilter = .error
        default:
            currentFilter = nil
        }
        loadLogs()
    }

    @objc private func handleClearLogs() {
        let alert = UIAlertController(title: "Xóa toàn bộ Logs?", message: "Hành động này sẽ xóa vĩnh viễn tất cả lịch sử log hiện tại.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Xóa", style: .destructive, handler: { [weak self] _ in
            DatabaseManager.shared.clearLogs()
            self?.logs.removeAll()
            self?.tableView.reloadData()
        }))
        alert.addAction(UIAlertAction(title: "Hủy", style: .cancel))
        present(alert, animated: true)
    }

    // MARK: - TableView DataSource & Delegate

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return logs.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: LogConsoleCell.reuseIdentifier, for: indexPath) as? LogConsoleCell else {
            return UITableViewCell()
        }
        cell.configure(with: logs[indexPath.row])
        return cell
    }
}

// MARK: - Dedicated Cinematic LogConsoleCell

public final class LogConsoleCell: UITableViewCell {
    public static let reuseIdentifier = "LogConsoleCell"

    private let cardView = UIView()
    private let statusDot = UIView()
    private let timestampLabel = UILabel()
    private let levelBadge = UILabel()
    private let actionTagLabel = UILabel()
    private let messageLabel = UILabel()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = ToriumTheme.graphiteCard.withAlphaComponent(0.7)
        cardView.layer.cornerRadius = 8
        cardView.layer.borderWidth = 0.8
        cardView.layer.borderColor = ToriumTheme.graphiteBorder.cgColor
        contentView.addSubview(cardView)

        statusDot.translatesAutoresizingMaskIntoConstraints = false
        statusDot.layer.cornerRadius = 3
        cardView.addSubview(statusDot)

        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        timestampLabel.textColor = ToriumTheme.textMuted
        cardView.addSubview(timestampLabel)

        levelBadge.translatesAutoresizingMaskIntoConstraints = false
        levelBadge.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        levelBadge.layer.cornerRadius = 4
        levelBadge.clipsToBounds = true
        levelBadge.textAlignment = .center
        cardView.addSubview(levelBadge)

        actionTagLabel.translatesAutoresizingMaskIntoConstraints = false
        actionTagLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        actionTagLabel.textColor = ToriumTheme.textSecondary
        cardView.addSubview(actionTagLabel)

        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        messageLabel.textColor = ToriumTheme.textPrimary
        messageLabel.numberOfLines = 0
        cardView.addSubview(messageLabel)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            statusDot.centerYAnchor.constraint(equalTo: timestampLabel.centerYAnchor),
            statusDot.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            statusDot.widthAnchor.constraint(equalToConstant: 6),
            statusDot.heightAnchor.constraint(equalToConstant: 6),

            timestampLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            timestampLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 6),

            levelBadge.centerYAnchor.constraint(equalTo: timestampLabel.centerYAnchor),
            levelBadge.leadingAnchor.constraint(equalTo: timestampLabel.trailingAnchor, constant: 6),
            levelBadge.heightAnchor.constraint(equalToConstant: 16),
            levelBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),

            actionTagLabel.centerYAnchor.constraint(equalTo: timestampLabel.centerYAnchor),
            actionTagLabel.leadingAnchor.constraint(equalTo: levelBadge.trailingAnchor, constant: 6),
            actionTagLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -10),

            messageLabel.topAnchor.constraint(equalTo: timestampLabel.bottomAnchor, constant: 5),
            messageLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            messageLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            messageLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -8)
        ])
    }

    public func configure(with log: Log) {
        timestampLabel.text = "[\(log.formattedDate)]"
        actionTagLabel.text = "(\(log.action.rawValue))"
        messageLabel.text = log.message

        switch log.level {
        case .error:
            statusDot.backgroundColor = ToriumTheme.statusRed
            levelBadge.text = " ERROR "
            levelBadge.textColor = ToriumTheme.statusRed
            levelBadge.backgroundColor = ToriumTheme.statusRed.withAlphaComponent(0.15)
        case .warn:
            statusDot.backgroundColor = ToriumTheme.statusYellow
            levelBadge.text = " WARN "
            levelBadge.textColor = ToriumTheme.statusYellow
            levelBadge.backgroundColor = ToriumTheme.statusYellow.withAlphaComponent(0.15)
        case .info:
            statusDot.backgroundColor = ToriumTheme.cyanHighlight
            levelBadge.text = " INFO "
            levelBadge.textColor = ToriumTheme.cyanHighlight
            levelBadge.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.15)
        }
    }
}
