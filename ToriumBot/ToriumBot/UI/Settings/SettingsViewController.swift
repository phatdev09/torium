import UIKit

/// Settings Tab providing configuration for Telegram, Automation schedules, Backup, and About
public final class SettingsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Telegram Section
    private let telegramCard = UIView()
    private let botTokenField = UITextField()
    private let chatIdField = UITextField()
    private let testTelegramButton = UIButton(type: .system)
    private let intervalPicker = UIPickerView()
    private let intervalOptions = ["1", "3", "6", "12", "24"]

    // Automation Section
    private let automationCard = UIView()
    private let adIntervalField = UITextField()
    private let humanDelaySwitch = UISwitch()
    private let autoRestartSwitch = UISwitch()

    // Backup Section
    private let backupCard = UIView()
    private let backupAllButton = UIButton(type: .system)

    // About Section
    private let aboutCard = UIView()
    private let versionLabel = UILabel()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(saveSettings))

        setupScrollView()
        setupTelegramSection()
        setupAutomationSection()
        setupBackupSection()
        setupAboutSection()
        loadSettings()
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

    private func setupTelegramSection() {
        ToriumTheme.applyCardStyle(to: telegramCard)
        telegramCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(telegramCard)

        let sectionTitle = makeSectionTitle("TELEGRAM NOTIFICATIONS")
        styleTextField(botTokenField, placeholder: "Telegram Bot Token")
        styleTextField(chatIdField, placeholder: "Telegram Chat ID")

        testTelegramButton.setTitle("Test Kết Nối Telegram", for: .normal)
        testTelegramButton.setTitleColor(ToriumTheme.accentGold, for: .normal)
        testTelegramButton.layer.borderWidth = 1
        testTelegramButton.layer.borderColor = ToriumTheme.accentGold.cgColor
        testTelegramButton.layer.cornerRadius = 8
        testTelegramButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        testTelegramButton.addTarget(self, action: #selector(handleTestTelegram), for: .touchUpInside)

        let intervalLabel = UILabel()
        intervalLabel.text = "Chu kỳ báo cáo định kỳ:"
        intervalLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        intervalLabel.textColor = ToriumTheme.textSecondary

        intervalPicker.dataSource = self
        intervalPicker.delegate = self
        intervalPicker.heightAnchor.constraint(equalToConstant: 80).isActive = true

        let stack = UIStackView(arrangedSubviews: [
            sectionTitle,
            botTokenField,
            chatIdField,
            testTelegramButton,
            intervalLabel,
            intervalPicker
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        telegramCard.addSubview(stack)

        NSLayoutConstraint.activate([
            telegramCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            telegramCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            telegramCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: telegramCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: telegramCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: telegramCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: telegramCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupAutomationSection() {
        ToriumTheme.applyCardStyle(to: automationCard)
        automationCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(automationCard)

        let sectionTitle = makeSectionTitle("AUTOMATION SETTINGS")

        let intervalLabel = UILabel()
        intervalLabel.text = "Khoảng cách xem Ad mặc định (giờ):"
        intervalLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        intervalLabel.textColor = ToriumTheme.textSecondary

        styleTextField(adIntervalField, placeholder: "2")
        adIntervalField.keyboardType = .decimalPad

        let humanDelayRow = makeSwitchRow(title: "Human Delay (delay ngẫu nhiên chống phát hiện)", toggleSwitch: humanDelaySwitch)
        let autoRestartRow = makeSwitchRow(title: "Auto Restart on Error (tự khởi động lại khi lỗi)", toggleSwitch: autoRestartSwitch)

        let stack = UIStackView(arrangedSubviews: [
            sectionTitle,
            intervalLabel,
            adIntervalField,
            humanDelayRow,
            autoRestartRow
        ])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        automationCard.addSubview(stack)

        NSLayoutConstraint.activate([
            automationCard.topAnchor.constraint(equalTo: telegramCard.bottomAnchor, constant: 14),
            automationCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            automationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: automationCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: automationCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: automationCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: automationCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupBackupSection() {
        ToriumTheme.applyCardStyle(to: backupCard)
        backupCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(backupCard)

        let sectionTitle = makeSectionTitle("DỮ LIỆU & BACKUP")

        backupAllButton.setTitle("Backup Tất Cả Accounts (Gửi qua Telegram)", for: .normal)
        backupAllButton.setTitleColor(UIColor.black, for: .normal)
        backupAllButton.backgroundColor = ToriumTheme.accentGold
        backupAllButton.layer.cornerRadius = ToriumTheme.cornerRadius
        backupAllButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        backupAllButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        backupAllButton.addTarget(self, action: #selector(handleBackupAll), for: .touchUpInside)

        let descLabel = UILabel()
        descLabel.text = "Xuất định dạng: email|password|bearer_token|clerk_id|device_id|proxy"
        descLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        descLabel.textColor = ToriumTheme.textMuted
        descLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [sectionTitle, backupAllButton, descLabel])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        backupCard.addSubview(stack)

        NSLayoutConstraint.activate([
            backupCard.topAnchor.constraint(equalTo: automationCard.bottomAnchor, constant: 14),
            backupCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            backupCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: backupCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: backupCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: backupCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: backupCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupAboutSection() {
        ToriumTheme.applyCardStyle(to: aboutCard)
        aboutCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(aboutCard)

        let sectionTitle = makeSectionTitle("ABOUT")
        versionLabel.text = """
        ToriumBot Native v1.0.0
        Rootful Jailbreak & TrollStore Edition
        A9 / iPhone 6s / 6s Plus Support
        """
        versionLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        versionLabel.textColor = ToriumTheme.textSecondary
        versionLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [sectionTitle, versionLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        aboutCard.addSubview(stack)

        NSLayoutConstraint.activate([
            aboutCard.topAnchor.constraint(equalTo: backupCard.bottomAnchor, constant: 14),
            aboutCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            aboutCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            aboutCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: aboutCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: aboutCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: aboutCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: aboutCard.bottomAnchor, constant: -14)
        ])
    }

    private func loadSettings() {
        botTokenField.text = DatabaseManager.shared.getSetting(key: "telegram_bot_token")
        chatIdField.text = DatabaseManager.shared.getSetting(key: "telegram_chat_id")
        adIntervalField.text = DatabaseManager.shared.getSetting(key: "default_ad_interval_hours") ?? "2"

        humanDelaySwitch.isOn = (DatabaseManager.shared.getSetting(key: "human_delay_enabled") ?? "true") == "true"
        autoRestartSwitch.isOn = (DatabaseManager.shared.getSetting(key: "auto_restart_enabled") ?? "true") == "true"

        let currentInterval = DatabaseManager.shared.getSetting(key: "report_interval_hours") ?? "6"
        if let idx = intervalOptions.firstIndex(of: currentInterval) {
            intervalPicker.selectRow(idx, inComponent: 0, animated: false)
        }
    }

    @objc private func saveSettings() {
        DatabaseManager.shared.setSetting(key: "telegram_bot_token", value: botTokenField.text ?? "")
        DatabaseManager.shared.setSetting(key: "telegram_chat_id", value: chatIdField.text ?? "")
        DatabaseManager.shared.setSetting(key: "default_ad_interval_hours", value: adIntervalField.text ?? "2")
        DatabaseManager.shared.setSetting(key: "human_delay_enabled", value: humanDelaySwitch.isOn ? "true" : "false")
        DatabaseManager.shared.setSetting(key: "auto_restart_enabled", value: autoRestartSwitch.isOn ? "true" : "false")

        let selectedRow = intervalPicker.selectedRow(inComponent: 0)
        let interval = intervalOptions[selectedRow]
        DatabaseManager.shared.setSetting(key: "report_interval_hours", value: interval)

        TelegramReporter.shared.startPeriodicReporting()

        let alert = UIAlertController(title: "Đã lưu", message: "Các cài đặt đã được lưu thành công.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func handleTestTelegram() {
        // Temporarily save token and chat id for test
        DatabaseManager.shared.setSetting(key: "telegram_bot_token", value: botTokenField.text ?? "")
        DatabaseManager.shared.setSetting(key: "telegram_chat_id", value: chatIdField.text ?? "")

        Task {
            let success = await TelegramReporter.shared.sendMessage(text: "🔔 [ToriumBot] Test kết nối Telegram thành công! Bot đã sẵn sàng nhận cảnh báo.")
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: success ? "Kết nối thành công" : "Kết nối thất bại",
                    message: success ? "Telegram bot đã gửi tin nhắn thử nghiệm thành công!" : "Không thể gửi tin nhắn. Vui lòng kiểm tra lại Bot Token và Chat ID.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    @objc private func handleBackupAll() {
        Task {
            let res = await BackupManager.shared.backupAllAccounts()
            DispatchQueue.main.async {
                let alert = UIAlertController(title: res.success ? "Thành công" : "Lỗi", message: res.message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    // MARK: - UI Helpers

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = ToriumTheme.accentGold
        return label
    }

    private func makeSwitchRow(title: String, toggleSwitch: UISwitch) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = ToriumTheme.textPrimary
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.translatesAutoresizingMaskIntoConstraints = false
        toggleSwitch.onTintColor = ToriumTheme.accentGold

        container.addSubview(label)
        container.addSubview(toggleSwitch)

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.trailingAnchor.constraint(equalTo: toggleSwitch.leadingAnchor, constant: -8),

            toggleSwitch.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            toggleSwitch.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        return container
    }

    private func styleTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.textColor = ToriumTheme.textPrimary
        field.backgroundColor = ToriumTheme.cardBackground
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = ToriumTheme.cardBorder.cgColor
        field.heightAnchor.constraint(equalToConstant: 40).isActive = true
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 40))
        field.leftView = padding
        field.leftViewMode = .always
    }

    // MARK: - UIPickerViewDataSource & Delegate

    public func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { return intervalOptions.count }
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return "\(intervalOptions[row]) giờ"
    }
}
