import UIKit
import UniformTypeIdentifiers

/// Modal view controller for batch importing accounts via Smart Multi-Format Parser with Crane Auto-Provisioning
public final class ImportAccountViewController: UIViewController, UIDocumentPickerDelegate, UITableViewDataSource, UITableViewDelegate {

    private let textView = UITextView()
    private let importFileButton = UIButton(type: .system)
    private let validateButton = UIButton(type: .system)
    private let summaryLabel = UILabel()
    private let previewTableView = UITableView(frame: .zero, style: .plain)
    private let confirmButton = UIButton(type: .system)

    private var previewResult: ImportPreviewResult?
    private var displayedAccounts: [ParsedImportAccount] = []

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Import Accounts (Smart Parser)"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dismissSelf))

        setupViews()
    }

    private func setupViews() {
        let instructionLabel = UILabel()
        instructionLabel.text = "Format linh hoạt: email|pass|refresh_token|client_id hoặc email|pass|proxy hoặc backup txt. Ngăn cách bằng |, :, hoặc Tab. Tự động nhận diện và gán container Crane."
        instructionLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        instructionLabel.textColor = ToriumTheme.textSecondary
        instructionLabel.numberOfLines = 0
        instructionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(instructionLabel)

        textView.backgroundColor = ToriumTheme.cardBackground
        textView.textColor = ToriumTheme.textPrimary
        textView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.layer.cornerRadius = 8
        textView.layer.borderWidth = 1
        textView.layer.borderColor = ToriumTheme.border.cgColor
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
        importFileButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        importFileButton.addTarget(self, action: #selector(handlePickFile), for: .touchUpInside)

        validateButton.setTitle("Phân Tích & Xem Trước", for: .normal)
        validateButton.setTitleColor(UIColor.black, for: .normal)
        validateButton.backgroundColor = ToriumTheme.accentGold
        validateButton.layer.cornerRadius = 8
        validateButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        validateButton.addTarget(self, action: #selector(handleValidate), for: .touchUpInside)

        buttonsStack.addArrangedSubview(importFileButton)
        buttonsStack.addArrangedSubview(validateButton)

        summaryLabel.text = "Chưa phân tích dữ liệu"
        summaryLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        summaryLabel.textColor = ToriumTheme.textSecondary
        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(summaryLabel)

        previewTableView.backgroundColor = .clear
        previewTableView.separatorColor = ToriumTheme.border
        previewTableView.dataSource = self
        previewTableView.delegate = self
        previewTableView.register(UITableViewCell.self, forCellReuseIdentifier: "PreviewCell")
        previewTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(previewTableView)

        confirmButton.setTitle("Xác Nhận Nạp & Tự Tạo Container (0)", for: .normal)
        confirmButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        confirmButton.setTitleColor(UIColor.black, for: .normal)
        confirmButton.backgroundColor = ToriumTheme.success
        confirmButton.layer.cornerRadius = ToriumTheme.cornerRadius
        confirmButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        confirmButton.isEnabled = false
        confirmButton.alpha = 0.5
        confirmButton.addTarget(self, action: #selector(handleConfirmSave), for: .touchUpInside)
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(confirmButton)

        NSLayoutConstraint.activate([
            instructionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            instructionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            instructionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: instructionLabel.bottomAnchor, constant: 8),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 100),

            buttonsStack.topAnchor.constraint(equalTo: textView.bottomAnchor, constant: 8),
            buttonsStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            buttonsStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            summaryLabel.topAnchor.constraint(equalTo: buttonsStack.bottomAnchor, constant: 8),
            summaryLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            summaryLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            previewTableView.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 6),
            previewTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewTableView.bottomAnchor.constraint(equalTo: confirmButton.topAnchor, constant: -10),

            confirmButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            confirmButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            confirmButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
    }

    @objc private func handlePickFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
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
        guard let text = textView.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            let alert = UIAlertController(title: "Chưa có dữ liệu", message: "Vui lòng dán danh sách tài khoản hoặc chọn file .txt trước!", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let result = ImportParser.shared.parseText(text)
        self.previewResult = result
        self.displayedAccounts = result.validAccounts + result.duplicateAccounts

        summaryLabel.text = "✅ Hợp lệ: \(result.totalValid)  |  ⚠️ Trùng email: \(result.totalDuplicates)  |  ❌ Lỗi: \(result.totalInvalid)"
        if result.totalValid > 0 {
            confirmButton.setTitle("Xác Nhận Nạp & Tự Tạo Container (\(result.totalValid))", for: .normal)
            confirmButton.isEnabled = true
            confirmButton.alpha = 1.0
        } else {
            confirmButton.setTitle("Không Có Tài Khoản Hợp Lệ", for: .normal)
            confirmButton.isEnabled = false
            confirmButton.alpha = 0.5
        }

        previewTableView.reloadData()
    }

    @objc private func handleConfirmSave() {
        guard let result = previewResult, result.totalValid > 0 else { return }

        let alert = UIAlertController(
            title: "Xác Nhận Nạp",
            message: "Bạn có muốn lưu \(result.totalValid) tài khoản vào hệ thống và để bot tự động gọi libCrane tạo container tương ứng không?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Huỷ", style: .cancel))
        alert.addAction(UIAlertAction(title: "Xác Nhận", style: .default, handler: { [weak self] _ in
            let count = ImportParser.shared.commitImport(accounts: result.validAccounts, autoProvisionCrane: true)
            let successAlert = UIAlertController(
                title: "Thành Công",
                message: "Đã nạp thành công \(count) tài khoản vào database và sinh container Crane tự động! Bản backup đã được gửi về Telegram.",
                preferredStyle: .alert
            )
            successAlert.addAction(UIAlertAction(title: "Tuyệt vời", style: .default, handler: { _ in
                self?.dismissSelf()
            }))
            self?.present(successAlert, animated: true)
        }))
        present(alert, animated: true)
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    // MARK: - UITableViewDataSource & Delegate

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayedAccounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PreviewCell", for: indexPath)
        cell.backgroundColor = .clear
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)

        let acc = displayedAccounts[indexPath.row]
        var statusIcon = acc.isDuplicate ? "⚠️ [TRÙNG] " : (acc.isReadyToFarm ? "⚡ [TOKEN SẴN] " : "⏳ [CẦN REG] ")
        var proxyInfo = ""
        if let host = acc.proxyHost, let port = acc.proxyPort {
            proxyInfo = " (Proxy: \(host):\(port))"
        }

        cell.textLabel?.text = "\(statusIcon)\(acc.email)\(proxyInfo)"
        cell.textLabel?.textColor = acc.isDuplicate ? ToriumTheme.warning : ToriumTheme.textPrimary
        return cell
    }
}
