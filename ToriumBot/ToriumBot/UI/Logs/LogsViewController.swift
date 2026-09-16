import UIKit

/// Realtime logs viewer with filter tabs, color-coding, auto-scroll, and clear controls
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

        setupSegment()
        setupTableView()
        loadLogs()
        listenForRealtimeLogs()
    }

    private func setupSegment() {
        filterSegment.selectedSegmentIndex = 0
        filterSegment.backgroundColor = ToriumTheme.cardBackground
        filterSegment.selectedSegmentTintColor = ToriumTheme.accentGold
        filterSegment.setTitleTextAttributes([.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
        filterSegment.setTitleTextAttributes([.foregroundColor: ToriumTheme.textSecondary], for: .normal)
        filterSegment.addTarget(self, action: #selector(filterChanged), for: .valueChanged)
        filterSegment.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(filterSegment)

        NSLayoutConstraint.activate([
            filterSegment.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            filterSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            filterSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            filterSegment.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = ToriumTheme.cardBorder
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LogCell")
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "LogCell", for: indexPath)
        let log = logs[indexPath.row]

        cell.backgroundColor = .clear
        cell.selectionStyle = .none

        let attributed = NSMutableAttributedString()

        // Timestamp
        let timeAttr = NSAttributedString(
            string: "[\(log.formattedDate)] ",
            attributes: [.foregroundColor: ToriumTheme.textMuted, .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)]
        )
        attributed.append(timeAttr)

        // Level Badge
        var badgeColor = ToriumTheme.textPrimary
        if log.level == .warn { badgeColor = ToriumTheme.statusYellow }
        if log.level == .error { badgeColor = ToriumTheme.statusRed }

        let levelAttr = NSAttributedString(
            string: "[\(log.level.rawValue)] ",
            attributes: [.foregroundColor: badgeColor, .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .bold)]
        )
        attributed.append(levelAttr)

        // Action & Message
        let msgAttr = NSAttributedString(
            string: "(\(log.action.rawValue)) \(log.message)",
            attributes: [.foregroundColor: badgeColor, .font: UIFont.systemFont(ofSize: 13, weight: .regular)]
        )
        attributed.append(msgAttr)

        cell.textLabel?.attributedText = attributed
        cell.textLabel?.numberOfLines = 0
        return cell
    }
}
