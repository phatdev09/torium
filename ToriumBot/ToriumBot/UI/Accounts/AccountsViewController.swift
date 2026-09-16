import UIKit

/// Accounts Tab managing the list of accounts, adding new accounts, importing files, and swipe-deletion
public final class AccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private let tableView = UITableView(frame: .zero, style: .plain)
    private var accounts: [Account] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Accounts"

        setupNavigationButtons()
        setupTableView()
        loadAccounts()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadAccounts()
    }

    private func setupNavigationButtons() {
        let addButton = UIBarButtonItem(
            barButtonSystemItem: .add,
            target: self,
            action: #selector(handleAddAccount)
        )

        let importButton = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.down"),
            style: .plain,
            target: self,
            action: #selector(handleImportAccount)
        )

        navigationItem.rightBarButtonItems = [addButton, importButton]
    }

    private func setupTableView() {
        tableView.backgroundColor = .clear
        tableView.separatorColor = ToriumTheme.cardBorder
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "AccountListCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadAccounts() {
        self.accounts = DatabaseManager.shared.getAllAccounts()
        tableView.reloadData()
    }

    @objc private func handleAddAccount() {
        let addVC = AddAccountViewController()
        let nav = UINavigationController(rootViewController: addVC)
        present(nav, animated: true)
    }

    @objc private func handleImportAccount() {
        let importVC = ImportAccountViewController()
        let nav = UINavigationController(rootViewController: importVC)
        present(nav, animated: true)
    }

    // MARK: - UITableViewDataSource & Delegate

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountListCell", for: indexPath)
        let acc = accounts[indexPath.row]

        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.text = acc.email
        cell.textLabel?.textColor = ToriumTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)

        let status = acc.isBanned ? "🚫 Banned" : (acc.isActive ? "✅ Active" : "⏸ Paused")
        let proxyText = acc.proxyHost != nil ? " • 🌐 Proxy" : ""
        cell.detailTextLabel?.text = "\(status)\(proxyText)"
        cell.detailTextLabel?.textColor = ToriumTheme.textSecondary
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let acc = accounts[indexPath.row]
        let detailVC = AccountDetailViewController(account: acc)
        navigationController?.pushViewController(detailVC, animated: true)
    }

    public func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let acc = accounts[indexPath.row]
            if let id = acc.id {
                DatabaseManager.shared.deleteAccount(id: id)
                accounts.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
            }
        }
    }
}
