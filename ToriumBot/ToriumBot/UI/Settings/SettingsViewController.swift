import UIKit

/// Settings Tab providing configuration for Telegram, Automation, Referral, Sleep Simulator, Tweak & OTA
public final class SettingsViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Referral & Anti-Sybil Section
    private let referralCard = UIView()
    private let masterRefField = UITextField()
    private let sleepSimulatorSwitch = UISwitch()
    private let sleepHoursLabel = UILabel()

    // Telegram Section
    private let telegramCard = UIView()
    private let telegramGuideButton = UIButton(type: .system)
    private let botTokenField = UITextField()
    private let chatIdField = UITextField()
    private let testTelegramButton = UIButton(type: .system)
    private let intervalPicker = UIPickerView()
    private let intervalOptions = ["1", "3", "6", "12", "24"]

    // Captcha Solver Section
    private let captchaCard = UIView()
    private let captchaModeSegment = UISegmentedControl(items: ["1-Tap Thủ Công (Free)", "Auto CapSolver API"])
    private let captchaApiKeyField = UITextField()

    // Automation & Dynamic Route Section
    private let automationCard = UIView()
    private let adIntervalField = UITextField()
    private let humanDelaySwitch = UISwitch()
    private let otaVersionField = UITextField()
    private let appVersionField = UITextField()
    private let apiBaseUrlField = UITextField()
    private let apiStatusPathField = UITextField()
    private let apiBoostPathField = UITextField()

    // Tweak, Housekeeping & Backup Section
    private let tweakCard = UIView()
    private let installTweakButton = UIButton(type: .system)
    private let housekeepingButton = UIButton(type: .system)
    private let backupAllButton = UIButton(type: .system)

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Settings"
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Lưu", style: .done, target: self, action: #selector(saveSettings))

        setupScrollView()
        setupReferralSection()
        setupCaptchaSection()
        setupAutomationSection()
        setupTelegramSection()
        setupTweakSection()
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

    private func setupReferralSection() {
        ToriumTheme.applyCardStyle(to: referralCard)
        referralCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(referralCard)

        let sectionTitle = makeSectionTitle("MÃ GIỚI THIỆU & MÔ PHỎNG GIẤC NGỦ")
        styleTextField(masterRefField, placeholder: "Master Referral Code (Ví dụ: TORIUMVIP)")

        let sleepRow = UIStackView()
        sleepRow.axis = .horizontal
        sleepRow.alignment = .center

        let sleepLabel = UILabel()
        sleepLabel.text = "Mô Phỏng Giấc Ngủ (Nghỉ 01:30 - 05:30):"
        sleepLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        sleepLabel.textColor = ToriumTheme.textPrimary
        sleepLabel.numberOfLines = 2

        sleepRow.addArrangedSubview(sleepLabel)
        sleepRow.addArrangedSubview(sleepSimulatorSwitch)

        let stack = UIStackView(arrangedSubviews: [sectionTitle, masterRefField, sleepRow])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        referralCard.addSubview(stack)

        NSLayoutConstraint.activate([
            referralCard.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            referralCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            referralCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: referralCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: referralCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: referralCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: referralCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupCaptchaSection() {
        ToriumTheme.applyCardStyle(to: captchaCard)
        captchaCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(captchaCard)

        let sectionTitle = makeSectionTitle("GIẢI CAPTCHA TURNSTILE")

        captchaModeSegment.selectedSegmentTintColor = ToriumTheme.accentGold
        captchaModeSegment.setTitleTextAttributes([.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 12, weight: .semibold)], for: .selected)
        captchaModeSegment.setTitleTextAttributes([.foregroundColor: ToriumTheme.textSecondary, .font: UIFont.systemFont(ofSize: 12, weight: .regular)], for: .normal)
        captchaModeSegment.backgroundColor = ToriumTheme.background
        captchaModeSegment.addTarget(self, action: #selector(handleCaptchaModeChanged), for: .valueChanged)

        styleTextField(captchaApiKeyField, placeholder: "CapSolver API Key (Bắt buộc cho Auto Mode)")
        captchaApiKeyField.isSecureTextEntry = true

        let stack = UIStackView(arrangedSubviews: [sectionTitle, captchaModeSegment, captchaApiKeyField])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        captchaCard.addSubview(stack)

        NSLayoutConstraint.activate([
            captchaCard.topAnchor.constraint(equalTo: referralCard.bottomAnchor, constant: 12),
            captchaCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            captchaCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: captchaCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: captchaCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: captchaCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: captchaCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupAutomationSection() {
        ToriumTheme.applyCardStyle(to: automationCard)
        automationCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(automationCard)

        let sectionTitle = makeSectionTitle("TỰ ĐỘNG HÓA & ROUTE API DYNAMIC")
        styleTextField(adIntervalField, placeholder: "Khoảng cách xem ad (mặc định 2 giờ)")
        adIntervalField.keyboardType = .numberPad

        let delayRow = UIStackView()
        delayRow.axis = .horizontal
        let delayLabel = UILabel()
        delayLabel.text = "Human Delay (Giãn cách ngẫu nhiên):"
        delayLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        delayLabel.textColor = ToriumTheme.textPrimary
        delayRow.addArrangedSubview(delayLabel)
        delayRow.addArrangedSubview(humanDelaySwitch)

        styleTextField(otaVersionField, placeholder: "Header x-ota-version")
        styleTextField(appVersionField, placeholder: "Header x-app-version (2.1.0)")
        styleTextField(apiBaseUrlField, placeholder: "API Base URL (https://api.torium.network)")
        styleTextField(apiStatusPathField, placeholder: "Status Path (/v1/mining/v2/session-status)")
        styleTextField(apiBoostPathField, placeholder: "Boost Path (/v1/mining/v2/boost)")

        let stack = UIStackView(arrangedSubviews: [
            sectionTitle,
            adIntervalField,
            delayRow,
            otaVersionField,
            appVersionField,
            apiBaseUrlField,
            apiStatusPathField,
            apiBoostPathField
        ])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        automationCard.addSubview(stack)

        NSLayoutConstraint.activate([
            automationCard.topAnchor.constraint(equalTo: captchaCard.bottomAnchor, constant: 12),
            automationCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            automationCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: automationCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: automationCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: automationCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: automationCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupTelegramSection() {
        ToriumTheme.applyCardStyle(to: telegramCard)
        telegramCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(telegramCard)

        let sectionTitle = makeSectionTitle("TELEGRAM NOTIFICATIONS (SEND-ONLY)")

        telegramGuideButton.setTitle("Bấm vào đây để xem hướng dẫn", for: .normal)
        telegramGuideButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        telegramGuideButton.setTitleColor(ToriumTheme.cyanHighlight, for: .normal)
        telegramGuideButton.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.12)
        telegramGuideButton.layer.cornerRadius = 8
        telegramGuideButton.layer.borderWidth = 1
        telegramGuideButton.layer.borderColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.4).cgColor
        telegramGuideButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        telegramGuideButton.addTarget(self, action: #selector(handleOpenTelegramGuide), for: .touchUpInside)

        styleTextField(botTokenField, placeholder: "Telegram Bot Token")
        styleTextField(chatIdField, placeholder: "Telegram Chat ID")

        testTelegramButton.setTitle("Test Kết Nối Telegram", for: .normal)
        testTelegramButton.setTitleColor(ToriumTheme.accentGold, for: .normal)
        testTelegramButton.layer.borderWidth = 1
        testTelegramButton.layer.borderColor = ToriumTheme.accentGold.cgColor
        testTelegramButton.layer.cornerRadius = 8
        testTelegramButton.heightAnchor.constraint(equalToConstant: 38).isActive = true
        testTelegramButton.addTarget(self, action: #selector(handleTestTelegram), for: .touchUpInside)

        let intervalLabel = UILabel()
        intervalLabel.text = "Chu kỳ báo cáo định kỳ (Giờ):"
        intervalLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        intervalLabel.textColor = ToriumTheme.textSecondary

        intervalPicker.dataSource = self
        intervalPicker.delegate = self
        intervalPicker.heightAnchor.constraint(equalToConstant: 70).isActive = true

        let stack = UIStackView(arrangedSubviews: [sectionTitle, telegramGuideButton, botTokenField, chatIdField, testTelegramButton, intervalLabel, intervalPicker])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        telegramCard.addSubview(stack)

        NSLayoutConstraint.activate([
            telegramCard.topAnchor.constraint(equalTo: automationCard.bottomAnchor, constant: 12),
            telegramCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            telegramCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            stack.topAnchor.constraint(equalTo: telegramCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: telegramCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: telegramCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: telegramCard.bottomAnchor, constant: -14)
        ])
    }

    private func setupTweakSection() {
        ToriumTheme.applyCardStyle(to: tweakCard)
        tweakCard.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tweakCard)

        let sectionTitle = makeSectionTitle("TWEAK HỖ TRỢ, BỘ NHỚ & SAO LƯU")

        installTweakButton.setTitle("⚡ Cài Đặt ToriumHelper Tweak (1 chạm)", for: .normal)
        installTweakButton.backgroundColor = ToriumTheme.accentGold.withAlphaComponent(0.2)
        installTweakButton.setTitleColor(ToriumTheme.accentGold, for: .normal)
        installTweakButton.layer.cornerRadius = 8
        installTweakButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        installTweakButton.addTarget(self, action: #selector(handleInstallTweak), for: .touchUpInside)

        housekeepingButton.setTitle("🧹 Dọn Dẹp CSDL & Tối Ưu Bộ Nhớ (<15MB)", for: .normal)
        housekeepingButton.backgroundColor = ToriumTheme.warning.withAlphaComponent(0.2)
        housekeepingButton.setTitleColor(ToriumTheme.warning, for: .normal)
        housekeepingButton.layer.cornerRadius = 8
        housekeepingButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        housekeepingButton.addTarget(self, action: #selector(handleHousekeeping), for: .touchUpInside)

        backupAllButton.setTitle("📥 Backup Tất Cả Accounts (Gửi qua Telegram)", for: .normal)
        backupAllButton.backgroundColor = ToriumTheme.success.withAlphaComponent(0.2)
        backupAllButton.setTitleColor(ToriumTheme.success, for: .normal)
        backupAllButton.layer.cornerRadius = 8
        backupAllButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        backupAllButton.addTarget(self, action: #selector(handleBackupAll), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [sectionTitle, installTweakButton, housekeepingButton, backupAllButton])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        tweakCard.addSubview(stack)

        NSLayoutConstraint.activate([
            tweakCard.topAnchor.constraint(equalTo: telegramCard.bottomAnchor, constant: 12),
            tweakCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tweakCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tweakCard.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),

            stack.topAnchor.constraint(equalTo: tweakCard.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: tweakCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: tweakCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: tweakCard.bottomAnchor, constant: -14)
        ])
    }

    // MARK: - Handlers

    @objc private func handleCaptchaModeChanged() {
        let isAuto = captchaModeSegment.selectedSegmentIndex == 1
        captchaApiKeyField.alpha = isAuto ? 1.0 : 0.4
        captchaApiKeyField.isEnabled = isAuto
    }

    @objc private func handleInstallTweak() {
        // Run dpkg -i on bundled deb
        let alert = UIAlertController(title: "Cài Đặt Tweak", message: "Đang cài đặt gói toriumhelper.deb vào hệ thống qua rootful dpkg...", preferredStyle: .alert)
        present(alert, animated: true)

        DispatchQueue.global(qos: .userInitiated).async {
            let bundleDeb = Bundle.main.path(forResource: "toriumhelper", ofType: "deb") ?? ""
            let cmd = "dpkg -i '\(bundleDeb)' 2>/dev/null || dpkg -i /Applications/ToriumBot.app/toriumhelper.deb 2>/dev/null || dpkg -i /var/jb/Applications/ToriumBot.app/toriumhelper.deb 2>/dev/null"
            CraneBridge.runShellCommand(cmd)
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    let doneAlert = UIAlertController(title: "Hoàn Tất", message: "Tweak ToriumHelper đã được cài đặt vào hệ thống. Vui lòng respring nếu cần!", preferredStyle: .alert)
                    doneAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(doneAlert, animated: true)
                }
            }
        }
    }

    @objc private func handleHousekeeping() {
        let alert = UIAlertController(title: "Dọn Dẹp CSDL", message: "Đang xóa logs > 7 ngày, checkpoint WAL và VACUUM SQLite...", preferredStyle: .alert)
        present(alert, animated: true)

        DispatchQueue.global(qos: .userInitiated).async {
            DatabaseManager.shared.performDatabaseHousekeeping()
            DispatchQueue.main.async {
                alert.dismiss(animated: true) {
                    let doneAlert = UIAlertController(title: "Đã Tối Ưu", message: "Database đã được giải phóng dung lượng, thu gọn kích thước file về < 15MB an toàn trên iPhone 6s.", preferredStyle: .alert)
                    doneAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(doneAlert, animated: true)
                }
            }
        }
    }

    @objc private func handleOpenTelegramGuide() {
        guard let url = URL(string: "https://phatdev09.github.io/torium/") else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    @objc private func handleTestTelegram() {
        saveSettings()
        TelegramReporter.shared.sendTestMessage { [weak self] (success: Bool, msg: String) in
            let alert = UIAlertController(title: success ? "Thành Công" : "Thất Bại", message: msg, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self?.present(alert, animated: true)
        }
    }

    @objc private func handleBackupAll() {
        TelegramReporter.shared.sendManualBackup()
        let alert = UIAlertController(title: "Đã gửi", message: "File backup đã được gửi tới Telegram của bạn!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    @objc private func saveSettings() {
        DatabaseManager.shared.setSetting(key: "master_referral_code", value: masterRefField.text ?? "")
        DatabaseManager.shared.setSetting(key: "sleep_simulator_enabled", value: sleepSimulatorSwitch.isOn ? "true" : "false")

        let captchaMode = captchaModeSegment.selectedSegmentIndex == 1 ? "auto" : "1-tap"
        DatabaseManager.shared.setSetting(key: "captcha_mode", value: captchaMode)
        DatabaseManager.shared.setSetting(key: "captcha_api_key", value: captchaApiKeyField.text ?? "")

        DatabaseManager.shared.setSetting(key: "telegram_bot_token", value: botTokenField.text ?? "")
        DatabaseManager.shared.setSetting(key: "telegram_chat_id", value: chatIdField.text ?? "")
        DatabaseManager.shared.setSetting(key: "default_ad_interval_hours", value: adIntervalField.text ?? "2")
        DatabaseManager.shared.setSetting(key: "human_delay_enabled", value: humanDelaySwitch.isOn ? "true" : "false")

        if let ota = otaVersionField.text, !ota.isEmpty {
            DatabaseManager.shared.setSetting(key: "x_ota_version", value: ota)
        }
        if let appV = appVersionField.text, !appV.isEmpty {
            DatabaseManager.shared.setSetting(key: "x_app_version", value: appV)
        }
        if let baseUrl = apiBaseUrlField.text, !baseUrl.isEmpty {
            DatabaseManager.shared.setSetting(key: "api_base_url", value: baseUrl)
        }
        if let statusPath = apiStatusPathField.text, !statusPath.isEmpty {
            DatabaseManager.shared.setSetting(key: "api_mining_status_path", value: statusPath)
        }
        if let boostPath = apiBoostPathField.text, !boostPath.isEmpty {
            DatabaseManager.shared.setSetting(key: "api_boost_path", value: boostPath)
        }

        let selectedInterval = intervalOptions[intervalPicker.selectedRow(inComponent: 0)]
        DatabaseManager.shared.setSetting(key: "report_interval_hours", value: selectedInterval)
        TelegramReporter.shared.restartPeriodicReportingIfRunning()

        let alert = UIAlertController(title: "Đã Lưu", message: "Cài đặt hệ thống đã được cập nhật thành công!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func loadSettings() {
        masterRefField.text = DatabaseManager.shared.getSetting(key: "master_referral_code")
        sleepSimulatorSwitch.isOn = DatabaseManager.shared.getSetting(key: "sleep_simulator_enabled") == "true"

        let captchaMode = DatabaseManager.shared.getSetting(key: "captcha_mode") ?? "1-tap"
        captchaModeSegment.selectedSegmentIndex = (captchaMode == "auto") ? 1 : 0
        captchaApiKeyField.text = DatabaseManager.shared.getSetting(key: "captcha_api_key")
        handleCaptchaModeChanged()

        botTokenField.text = DatabaseManager.shared.getSetting(key: "telegram_bot_token")
        chatIdField.text = DatabaseManager.shared.getSetting(key: "telegram_chat_id")
        adIntervalField.text = DatabaseManager.shared.getSetting(key: "default_ad_interval_hours") ?? "2"
        humanDelaySwitch.isOn = DatabaseManager.shared.getSetting(key: "human_delay_enabled") != "false"
        otaVersionField.text = DatabaseManager.shared.getSetting(key: "x_ota_version") ?? "0a9f87c3-0a5f-4ed5-aefd-7a9004875813"
        appVersionField.text = DatabaseManager.shared.getSetting(key: "x_app_version") ?? "2.1.0"
        apiBaseUrlField.text = DatabaseManager.shared.getAPIBaseURL()
        apiStatusPathField.text = DatabaseManager.shared.getAPIMiningStatusPath()
        apiBoostPathField.text = DatabaseManager.shared.getAPIBoostPath()

        let interval = DatabaseManager.shared.getSetting(key: "report_interval_hours") ?? "6"
        if let idx = intervalOptions.firstIndex(of: interval) {
            intervalPicker.selectRow(idx, inComponent: 0, animated: false)
        }
    }

    // MARK: - UIPickerView

    public func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { intervalOptions.count }
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { "\(intervalOptions[row]) Giờ" }

    // MARK: - UI Helpers

    private func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        label.textColor = ToriumTheme.accentGold
        return label
    }

    private func styleTextField(_ tf: UITextField, placeholder: String) {
        tf.placeholder = placeholder
        tf.font = UIFont.systemFont(ofSize: 14)
        tf.textColor = ToriumTheme.textPrimary
        tf.backgroundColor = ToriumTheme.background
        tf.layer.cornerRadius = 8
        tf.layer.borderColor = ToriumTheme.border.cgColor
        tf.layer.borderWidth = 1
        tf.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 38))
        tf.leftView = padding
        tf.leftViewMode = .always
    }
}
