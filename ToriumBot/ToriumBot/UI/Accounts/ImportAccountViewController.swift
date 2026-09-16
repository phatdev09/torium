import UIKit
import UniformTypeIdentifiers

/// Modal view controller for batch importing accounts via text paste or Files app
public final class ImportAccountViewController: UIViewController, UIDocumentPickerDelegate, UITableViewDataSource, UITableViewDelegate {

    private let textView = UITextView()
    private let importFileButton = UIButton(type: .system)
    private let validateButton = UIButton(type: .system)
    private let confirmButton = UIButton(type: .system)
    private let previewTableView = UITableView(frame: .zero, style: .plain)

    private var parsedAccounts: [Account] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Import Accounts"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dismissSelf))

        setupViews()
    }

    private func setupViews() {
        let instructionLabel = UILabel()
        instructionLabel.text = "Format: email|password|refresh_token|client_id hoặc định dạng file backup. Mỗi account một dòng."
        instructionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        instructionLabel.textColor = ToriumTheme.textSecondary
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        textView.backgroundColor = ToriumTheme.cardBackground
        textView.textColor = ToriumTheme.textPrimary
        textView.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = ToriumTheme.cardBorder.cgColor
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        let buttonsStack = UIStackView()
        buttonsStack.axis = .horizontal
        buttonsStack.spacing = 10
        buttonsStack.distribution = .fillEqually
        buttonsStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonsStack)

        importFileButton.setTitle("Chọn Từ Files", for: .normal)
        importFileButton.setTitleColor(ToriumTheme.accentGold, for: .normal)
        importFileButton.backgroundColor = ToriumTheme.cardBackground
        importFileButton.layer.cornerRadius = 8
        importFileButton.layer.borderWidth = 1
        importFileButton.layer.borderColor = ToriumTheme.accentGold.cgColor
        importFileButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        importFileButton.addTarget(self, action: #selector(handlePickFile), for: .touchUpInside)

        validateButton.setTitle("Kiểm Tra & Xem Trước", for: .normal)
        validateButton.setTitleColor(UIColor.black, for: .normal)
        validateButton.backgroundColor = ToriumTheme.accentGold
        validateButton.layer.cornerRadius = 8
        validateButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        validateButton.addTarget(self, action: #selector(handleValidate), for: .touchUpInside)

        buttonsStack.addArrangedSubview(importFileButton)
        buttonsStack.addArrangedSubview(validateButton)

        previewTableView.backgroundColor = .clear
        previewTableView.separatorColor = ToriumTheme.cardBorder
        previewTableView.dataSource = self
        previewTableView.delegate = self
        previewTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PreviewCell")
        previewTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewTableView)

        confirmButton.setTitle("Xác Nhận Lưu Vào Database (0)", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        confirmButton.setTitleColor(UIColor.black, for: .normal)
        confirmButton.backgroundColor = ToriumTheme.statusGreen
        confirmButton.layer.cornerRadius = ToriumTheme.cornerRadius
        confirmButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        confirmButton.isEnabled = false
        confirmButton.alpha = 0.5
        confirmButton.addTarget(self, action: #selector(handleConfirmSave), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 10),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 120),

            buttonsStack.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 10),
            buttonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            previewTableView.topAnchor.constraint(equalTo: buttonsStack.bottomAnchor, constant: 12),
            previewTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            previewTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            previewTableView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -12),

            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12)
        ])
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func handlePickFile() {
        let types: [UTType] = [.plainText]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
        picker.delegate = self
        present(picker, animated: true)
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            textView.text = content
            handleValidate()
        }
    }

    @objc private func handleValidate() {
        guard let text = textView.text, !text.isEmpty else {
            showAlert(title: "Thông báo", message: "Vui lòng nhập hoặc chọn file accounts trước.")
            return
        }

        let lines = text.components(separatedBy: .newlines)
        var validAccounts: [Account] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.components(separatedBy: "|")

            if parts.count >= 4 {
                // Check if this is backup format (>= 10 parts)
                if parts.count >= 10 {
                    let email = parts[0]
                    let pass = parts[1]
                    let token = parts[2].isEmpty ? nil : parts[2]
                    let clerkId = parts[3].isEmpty ? nil : parts[3]
                    let deviceId = parts[4].isEmpty ? nil : parts[4]
                    let proto = parts[5].isEmpty ? nil : parts[5]
                    let host = parts[6].isEmpty ? nil : parts[6]
                    let port = Int(parts[7])
                    let user = parts[8].isEmpty ? nil : parts[8]
                    let pword = parts[9].isEmpty ? nil : parts[9]

                    let acc = Account(
                        email: email,
                        password: pass,
                        bearerToken: token,
                        clerkId: clerkId,
                        deviceId: deviceId,
                        proxyHost: host,
                        proxyPort: port,
                        proxyUsername: user,
                        proxyPassword: pword,
                        proxyProtocol: proto
                    )
                    validAccounts.append(acc)
                } else {
                    // Standard format: email|password|refresh_token|client_id
                    let email = parts[0]
                    let pass = parts[1]
                    let acc = Account(email: email, password: pass)
                    validAccounts.append(acc)
                }
            }
        }

        self.parsedAccounts = validAccounts
        previewTableView.reloadData()

        if !validAccounts.isEmpty {
            confirmButton.isEnabled = true
            confirmButton.alpha = 1.0
            confirmButton.setTitle("Xác Nhận Lưu Vào Database (\(validAccounts.count))", for: .normal)
        } else {
            confirmButton.isEnabled = false
            confirmButton.alpha = 0.5
            confirmButton.setTitle("Xác Nhận Lưu Vào Database (0)", for: .normal)
            showAlert(title: "Định dạng sai", message: "Không tìm thấy account hợp lệ nào theo định dạng pipe |.")
        }
    }

    @objc private func handleConfirmSave() {
        var count = 0
        for acc in parsedAccounts {
            if DatabaseManager.shared.insertAccount(acc) != nil {
                count += 1
            }
        }

        showAlert(title: "Hoàn tất", message: "Đã thêm thành công \(count) accounts vào database.") { [weak self] in
            self?.dismiss(animated: true)
        }
    }

    private func showAlert(title: String, message: String, onDismiss: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in onDismiss?() }))
        present(alert, animated: true)
    }

    // MARK: - TableView DataSource

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return parsedAccounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PreviewCell", for: indexPath)
        let acc = parsedAccounts[indexPath.row]
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        cell.textLabel?.text = "\(indexPath.row + 1). \(acc.email)"
        cell.textLabel?.textColor = ToriumTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)

        let hasToken = acc.bearerToken != nil ? "Token: Có" : "Token: Chưa"
        cell.detailTextLabel?.text = hasToken
        cell.detailTextLabel?.textColor = ToriumTheme.accentGold
        return cell
    }
}
