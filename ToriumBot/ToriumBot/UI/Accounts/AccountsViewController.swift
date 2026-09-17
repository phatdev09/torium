import UIKit
import UniformTypeIdentifiers

/// Accounts Management Screen cleanly separated into:
/// 1. "Tạo Mới (DongVanFB + OTP)" - Full registration pipeline with DongVanFB mail API & OTP
/// 2. "Đăng Nhập / Import (Không OTP)" - Direct sign-in without OTP, auto Crane provisioning, and auto-run
public final class AccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Segmented Switcher
    private let segmentControl = UISegmentedControl(items: ["✨ Tạo Mới (DongVanFB)", "⚡ Đăng Nhập / Import"])

    // Section 1: Tạo Tài Khoản Mới (DongVanFB + OTP)
    private let registerContainer = UIView()
    private let regInfoLabel = UILabel()
    private let regEmailField = UITextField()
    private let regPasswordField = UITextField()
    private let regDongVanField = UITextField()
    private let regReferralField = UITextField()
    private let regProxyField = UITextField()
    private let regContainerPickerLabel = UILabel()
    private let regContainerPicker = UIPickerView()
    private let regSubmitButton = UIButton(type: .system)
    private let regStatusCard = UIView()
    private let regStatusDot = UIView()
    private let regStatusLabel = UILabel()
    private let regActivityIndicator = UIActivityIndicatorView(style: .medium)

    // Section 2: Đăng Nhập / Import (Không Cần OTP - Tự Chạy)
    private let loginContainer = UIView()
    private let loginNoticeCard = UIView()
    private let loginNoticeLabel = UILabel()
    private let loginTextView = UITextView()
    private let loginButtonsStack = UIStackView()
    private let loginFilePickButton = UIButton(type: .system)
    private let loginSubmitButton = UIButton(type: .system)
    private let loginProgressCard = UIView()
    private let loginProgressBar = UIProgressView(progressViewStyle: .default)
    private let loginProgressLabel = UILabel()

    // Section 3: Danh Sách Tài Khoản Đã Quản Lý
    private let tableSectionHeader = UIView()
    private let tableTitleLabel = UILabel()
    private let tableCountBadge = UILabel()
    private let accountsTableView = UITableView(frame: .zero, style: .plain)
    private var tableViewHeightConstraint: NSLayoutConstraint?

    // Data
    private var accounts: [Account] = []
    private var craneContainers: [CraneContainer] = []
    private var selectedContainerId: String = "default"

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Quản Lý Accounts"

        loadContainers()
        setupScrollView()
        setupSegmentControl()
        setupRegisterSection()
        setupLoginSection()
        setupAccountsTableSection()
        loadAccounts()
        updateSegmentView()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadContainers()
        loadAccounts()
    }

    private func loadContainers() {
        craneContainers = CraneManager.shared.fetchContainers()
        if let first = craneContainers.first {
            selectedContainerId = first.id
        }
        regContainerPicker.reloadAllComponents()
    }

    private func loadAccounts() {
        accounts = DatabaseManager.shared.getAllAccounts()
        tableCountBadge.text = " \(accounts.count) TÀI KHOẢN "

        let cellHeight: CGFloat = 68.0
        let totalHeight = max(1, CGFloat(accounts.count)) * cellHeight
        tableViewHeightConstraint?.constant = totalHeight
        accountsTableView.reloadData()
    }

    // MARK: - Layout Setup

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsVerticalScrollIndicator = false
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

    private func setupSegmentControl() {
        segmentControl.selectedSegmentIndex = 0
        segmentControl.selectedSegmentTintColor = ToriumTheme.accentGold
        segmentControl.setTitleTextAttributes([.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 13, weight: .bold)], for: .selected)
        segmentControl.setTitleTextAttributes([.foregroundColor: ToriumTheme.textSecondary, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .normal)
        segmentControl.backgroundColor = ToriumTheme.darkNavyCard
        segmentControl.addTarget(self, action: #selector(handleSegmentChanged), for: .valueChanged)
        segmentControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(segmentControl)

        NSLayoutConstraint.activate([
            segmentControl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            segmentControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            segmentControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            segmentControl.heightAnchor.constraint(equalToConstant: 38)
        ])
    }

    // MARK: - Section 1: Tạo Mới (DongVanFB + OTP)

    private func setupRegisterSection() {
        registerContainer.translatesAutoresizingMaskIntoConstraints = false
        registerContainer.backgroundColor = ToriumTheme.darkNavyCard
        registerContainer.layer.cornerRadius = 14
        registerContainer.layer.borderWidth = 1
        registerContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        contentView.addSubview(registerContainer)

        regInfoLabel.text = "TẠO TÀI KHOẢN MỚI (DONGVANFB + OTP)"
        regInfoLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        regInfoLabel.textColor = ToriumTheme.accentGold

        styleTextField(regEmailField, placeholder: "Email mới (vd: user982@hotmail.com)")
        styleTextField(regPasswordField, placeholder: "Mật khẩu cho tài khoản")
        regPasswordField.isSecureTextEntry = true

        styleTextField(regDongVanField, placeholder: "DongVanFB: refresh_token|client_id")
        styleTextField(regReferralField, placeholder: "Mã giới thiệu (Mặc định: \(DatabaseManager.shared.getSetting(key: "master_referral_code") ?? "TORIUMVIP"))")
        regReferralField.text = DatabaseManager.shared.getSetting(key: "master_referral_code")

        styleTextField(regProxyField, placeholder: "Proxy (tùy chọn: host:port hoặc socks5://...)")

        regContainerPickerLabel.text = "Gán Crane Container:"
        regContainerPickerLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        regContainerPickerLabel.textColor = ToriumTheme.cyanHighlight

        regContainerPicker.dataSource = self
        regContainerPicker.delegate = self
        regContainerPicker.heightAnchor.constraint(equalToConstant: 75).isActive = true

        regSubmitButton.setTitle("🚀 BẮT ĐẦU ĐĂNG KÝ (TỰ GIẢI OTP DONGVAN)", for: .normal)
        regSubmitButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        regSubmitButton.setTitleColor(UIColor.black, for: .normal)
        regSubmitButton.backgroundColor = ToriumTheme.accentGold
        regSubmitButton.layer.cornerRadius = 8
        regSubmitButton.heightAnchor.constraint(equalToConstant: 42).isActive = true
        regSubmitButton.addTarget(self, action: #selector(handleStartRegister), for: .touchUpInside)

        // Status Card
        regStatusCard.backgroundColor = ToriumTheme.darkNavy
        regStatusCard.layer.cornerRadius = 8
        regStatusCard.layer.borderWidth = 1
        regStatusCard.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor

        regStatusDot.backgroundColor = ToriumTheme.miningGreen
        regStatusDot.layer.cornerRadius = 3.5
        regStatusDot.translatesAutoresizingMaskIntoConstraints = false

        regStatusLabel.text = "Sẵn sàng: Nhập thông tin DongVanFB để đăng ký tự động."
        regStatusLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        regStatusLabel.textColor = ToriumTheme.textSecondary
        regStatusLabel.numberOfLines = 2
        regStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        regActivityIndicator.color = ToriumTheme.accentGold
        regActivityIndicator.hidesWhenStopped = true
        regActivityIndicator.translatesAutoresizingMaskIntoConstraints = false

        regStatusCard.addSubview(regStatusDot)
        regStatusCard.addSubview(regStatusLabel)
        regStatusCard.addSubview(regActivityIndicator)

        NSLayoutConstraint.activate([
            regStatusDot.centerYAnchor.constraint(equalTo: regStatusCard.centerYAnchor),
            regStatusDot.leadingAnchor.constraint(equalTo: regStatusCard.leadingAnchor, constant: 10),
            regStatusDot.widthAnchor.constraint(equalToConstant: 7),
            regStatusDot.heightAnchor.constraint(equalToConstant: 7),

            regActivityIndicator.centerYAnchor.constraint(equalTo: regStatusCard.centerYAnchor),
            regActivityIndicator.trailingAnchor.constraint(equalTo: regStatusCard.trailingAnchor, constant: -10),

            regStatusLabel.centerYAnchor.constraint(equalTo: regStatusCard.centerYAnchor),
            regStatusLabel.leadingAnchor.constraint(equalTo: regStatusDot.trailingAnchor, constant: 8),
            regStatusLabel.trailingAnchor.constraint(equalTo: regActivityIndicator.leadingAnchor, constant: -6),
            regStatusCard.heightAnchor.constraint(equalToConstant: 38)
        ])

        let regStack = UIStackView(arrangedSubviews: [
            regInfoLabel,
            regEmailField,
            regPasswordField,
            regDongVanField,
            regReferralField,
            regProxyField,
            regContainerPickerLabel,
            regContainerPicker,
            regSubmitButton,
            regStatusCard
        ])
        regStack.axis = .vertical
        regStack.spacing = 8
        regStack.translatesAutoresizingMaskIntoConstraints = false
        registerContainer.addSubview(regStack)

        NSLayoutConstraint.activate([
            registerContainer.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 12),
            registerContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            registerContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            regStack.topAnchor.constraint(equalTo: registerContainer.topAnchor, constant: 14),
            regStack.leadingAnchor.constraint(equalTo: registerContainer.leadingAnchor, constant: 14),
            regStack.trailingAnchor.constraint(equalTo: registerContainer.trailingAnchor, constant: -14),
            regStack.bottomAnchor.constraint(equalTo: registerContainer.bottomAnchor, constant: -14)
        ])
    }

    // MARK: - Section 2: Đăng Nhập / Import (Không Cần OTP - Tự Chạy)

    private func setupLoginSection() {
        loginContainer.translatesAutoresizingMaskIntoConstraints = false
        loginContainer.backgroundColor = ToriumTheme.darkNavyCard
        loginContainer.layer.cornerRadius = 14
        loginContainer.layer.borderWidth = 1
        loginContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        contentView.addSubview(loginContainer)

        // Notice Card explaining NO OTP needed for sign-in
        loginNoticeCard.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.08)
        loginNoticeCard.layer.cornerRadius = 8
        loginNoticeCard.layer.borderWidth = 1
        loginNoticeCard.layer.borderColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.3).cgColor
        loginNoticeCard.translatesAutoresizingMaskIntoConstraints = false

        loginNoticeLabel.text = "💡 ĐĂNG NHẬP KHÔNG CẦN OTP: Torium chỉ bắt OTP khi đăng ký mới. Khi đăng nhập, chỉ cần nhập email:mật khẩu. Hệ thống sẽ tự động gán Crane container, đăng nhập và kích hoạt đào ngay!"
        loginNoticeLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        loginNoticeLabel.textColor = ToriumTheme.cyanHighlight
        loginNoticeLabel.numberOfLines = 0
        loginNoticeLabel.translatesAutoresizingMaskIntoConstraints = false
        loginNoticeCard.addSubview(loginNoticeLabel)

        NSLayoutConstraint.activate([
            loginNoticeLabel.topAnchor.constraint(equalTo: loginNoticeCard.topAnchor, constant: 8),
            loginNoticeLabel.leadingAnchor.constraint(equalTo: loginNoticeCard.leadingAnchor, constant: 10),
            loginNoticeLabel.trailingAnchor.constraint(equalTo: loginNoticeCard.trailingAnchor, constant: -10),
            loginNoticeLabel.bottomAnchor.constraint(equalTo: loginNoticeCard.bottomAnchor, constant: -8)
        ])

        // Multi-line Text Area
        loginTextView.backgroundColor = ToriumTheme.darkNavy
        loginTextView.textColor = ToriumTheme.textPrimary
        loginTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        loginTextView.layer.cornerRadius = 8
        loginTextView.layer.borderWidth = 1
        loginTextView.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        loginTextView.heightAnchor.constraint(equalToConstant: 110).isActive = true
        loginTextView.translatesAutoresizingMaskIntoConstraints = false

        // Buttons
        loginButtonsStack.axis = .horizontal
        loginButtonsStack.spacing = 8
        loginButtonsStack.distribution = .fillProportionally
        loginButtonsStack.translatesAutoresizingMaskIntoConstraints = false

        loginFilePickButton.setTitle("📁 File .txt", for: .normal)
        loginFilePickButton.setTitleColor(ToriumTheme.cyanHighlight, for: .normal)
        loginFilePickButton.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.12)
        loginFilePickButton.layer.cornerRadius = 8
        loginFilePickButton.layer.borderWidth = 1
        loginFilePickButton.layer.borderColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.35).cgColor
        loginFilePickButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        loginFilePickButton.widthAnchor.constraint(equalToConstant: 95).isActive = true
        loginFilePickButton.addTarget(self, action: #selector(handlePickImportFile), for: .touchUpInside)

        loginSubmitButton.setTitle("⚡ ĐĂNG NHẬP & BẬT ĐÀO NGAY (KHÔNG OTP)", for: .normal)
        loginSubmitButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        loginSubmitButton.setTitleColor(UIColor.black, for: .normal)
        loginSubmitButton.backgroundColor = ToriumTheme.miningGreen
        loginSubmitButton.layer.cornerRadius = 8
        loginSubmitButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        loginSubmitButton.addTarget(self, action: #selector(handleBatchLogin), for: .touchUpInside)

        loginButtonsStack.addArrangedSubview(loginFilePickButton)
        loginButtonsStack.addArrangedSubview(loginSubmitButton)

        // Progress Card
        loginProgressCard.backgroundColor = ToriumTheme.darkNavy
        loginProgressCard.layer.cornerRadius = 8
        loginProgressCard.layer.borderWidth = 1
        loginProgressCard.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor

        loginProgressLabel.text = "Chờ nhập danh sách tài khoản cần đăng nhập."
        loginProgressLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        loginProgressLabel.textColor = ToriumTheme.textSecondary
        loginProgressLabel.translatesAutoresizingMaskIntoConstraints = false

        loginProgressBar.progress = 0.0
        loginProgressBar.progressTintColor = ToriumTheme.miningGreen
        loginProgressBar.trackTintColor = ToriumTheme.darkNavyBorder
        loginProgressBar.layer.cornerRadius = 2
        loginProgressBar.clipsToBounds = true
        loginProgressBar.translatesAutoresizingMaskIntoConstraints = false

        loginProgressCard.addSubview(loginProgressLabel)
        loginProgressCard.addSubview(loginProgressBar)

        NSLayoutConstraint.activate([
            loginProgressLabel.topAnchor.constraint(equalTo: loginProgressCard.topAnchor, constant: 8),
            loginProgressLabel.leadingAnchor.constraint(equalTo: loginProgressCard.leadingAnchor, constant: 10),
            loginProgressLabel.trailingAnchor.constraint(equalTo: loginProgressCard.trailingAnchor, constant: -10),

            loginProgressBar.topAnchor.constraint(equalTo: loginProgressLabel.bottomAnchor, constant: 6),
            loginProgressBar.leadingAnchor.constraint(equalTo: loginProgressCard.leadingAnchor, constant: 10),
            loginProgressBar.trailingAnchor.constraint(equalTo: loginProgressCard.trailingAnchor, constant: -10),
            loginProgressBar.bottomAnchor.constraint(equalTo: loginProgressCard.bottomAnchor, constant: -8),
            loginProgressBar.heightAnchor.constraint(equalToConstant: 4)
        ])

        let loginStack = UIStackView(arrangedSubviews: [
            loginNoticeCard,
            loginTextView,
            loginButtonsStack,
            loginProgressCard
        ])
        loginStack.axis = .vertical
        loginStack.spacing = 10
        loginStack.translatesAutoresizingMaskIntoConstraints = false
        loginContainer.addSubview(loginStack)

        NSLayoutConstraint.activate([
            loginContainer.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 12),
            loginContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            loginContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            loginStack.topAnchor.constraint(equalTo: loginContainer.topAnchor, constant: 14),
            loginStack.leadingAnchor.constraint(equalTo: loginContainer.leadingAnchor, constant: 14),
            loginStack.trailingAnchor.constraint(equalTo: loginContainer.trailingAnchor, constant: -14),
            loginStack.bottomAnchor.constraint(equalTo: loginContainer.bottomAnchor, constant: -14)
        ])
    }

    // MARK: - Section 3: Accounts Table Section

    private func setupAccountsTableSection() {
        tableSectionHeader.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tableSectionHeader)

        tableTitleLabel.text = "DANH SÁCH TÀI KHOẢN ĐÃ QUẢN LÝ"
        tableTitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        tableTitleLabel.textColor = ToriumTheme.textPrimary
        tableTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        tableCountBadge.font = UIFont.systemFont(ofSize: 10, weight: .bold)
        tableCountBadge.textColor = ToriumTheme.accentGold
        tableCountBadge.backgroundColor = ToriumTheme.accentGold.withAlphaComponent(0.15)
        tableCountBadge.layer.cornerRadius = 4
        tableCountBadge.clipsToBounds = true
        tableCountBadge.textAlignment = .center
        tableCountBadge.translatesAutoresizingMaskIntoConstraints = false

        tableSectionHeader.addSubview(tableTitleLabel)
        tableSectionHeader.addSubview(tableCountBadge)

        accountsTableView.translatesAutoresizingMaskIntoConstraints = false
        accountsTableView.backgroundColor = .clear
        accountsTableView.separatorColor = ToriumTheme.darkNavyBorder
        accountsTableView.dataSource = self
        accountsTableView.delegate = self
        accountsTableView.isScrollEnabled = false
        accountsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "AccountCell")
        contentView.addSubview(accountsTableView)

        let heightConstraint = accountsTableView.heightAnchor.constraint(equalToConstant: 200)
        self.tableViewHeightConstraint = heightConstraint

        NSLayoutConstraint.activate([
            tableSectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableSectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tableSectionHeader.heightAnchor.constraint(equalToConstant: 24),

            tableTitleLabel.centerYAnchor.constraint(equalTo: tableSectionHeader.centerYAnchor),
            tableTitleLabel.leadingAnchor.constraint(equalTo: tableSectionHeader.leadingAnchor),

            tableCountBadge.centerYAnchor.constraint(equalTo: tableSectionHeader.centerYAnchor),
            tableCountBadge.trailingAnchor.constraint(equalTo: tableSectionHeader.trailingAnchor),
            tableCountBadge.heightAnchor.constraint(equalToConstant: 18),

            accountsTableView.topAnchor.constraint(equalTo: tableSectionHeader.bottomAnchor, constant: 8),
            accountsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            accountsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            accountsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            heightConstraint
        ])
    }

    private func updateSegmentView() {
        let isRegisterMode = segmentControl.selectedSegmentIndex == 0
        registerContainer.isHidden = !isRegisterMode
        loginContainer.isHidden = isRegisterMode

        // Re-anchor tableSectionHeader to whichever container is visible
        tableSectionHeader.removeFromSuperview()
        contentView.addSubview(tableSectionHeader)

        let activeAnchor = isRegisterMode ? registerContainer.bottomAnchor : loginContainer.bottomAnchor

        NSLayoutConstraint.activate([
            tableSectionHeader.topAnchor.constraint(equalTo: activeAnchor, constant: 16),
            tableSectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableSectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tableSectionHeader.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    @objc private func handleSegmentChanged() {
        updateSegmentView()
    }

    // MARK: - Action: Start Registration (DongVanFB + OTP)

    @objc private func handleStartRegister() {
        guard let email = regEmailField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty,
              let password = regPasswordField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !password.isEmpty else {
            showAlert(title: "Thiếu thông tin", message: "Vui lòng nhập Email và Mật khẩu.")
            return
        }

        var cred: DongVanCredential?
        if let dvText = regDongVanField.text?.trimmingCharacters(in: .whitespacesAndNewlines), !dvText.isEmpty {
            let combined = "\(email)|\(password)|\(dvText)"
            cred = DongVanCredential(line: combined)
        }

        regSubmitButton.isEnabled = false
        regActivityIndicator.startAnimating()
        regStatusLabel.text = "Đang bắt đầu đăng ký..."

        Task {
            do {
                _ = try await AccountRegistrar.shared.startRegistration(
                    email: email,
                    password: password,
                    credential: cred,
                    containerId: self.selectedContainerId,
                    onStepUpdate: { [weak self] step in
                        DispatchQueue.main.async {
                            self?.updateRegStepUI(step: step)
                        }
                    },
                    onRequestCaptchaSolve: { [weak self] (completion: @escaping () -> Void) in
                        DispatchQueue.main.async {
                            let alert = UIAlertController(
                                title: "Giải Captcha Cloudflare",
                                message: "App Torium đã được mở trong Container. Vui lòng giải captcha Turnstile trên màn hình rồi nhấn Tiếp tục.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "Tiếp tục", style: .default, handler: { _ in
                                completion()
                            }))
                            self?.present(alert, animated: true)
                        }
                    }
                )

                DispatchQueue.main.async {
                    self.regActivityIndicator.stopAnimating()
                    self.regSubmitButton.isEnabled = true
                    self.regStatusLabel.text = "✅ Đăng ký thành công! Token đã lưu vào hệ thống."
                    self.regStatusLabel.textColor = ToriumTheme.miningGreen
                    self.regEmailField.text = ""
                    self.regPasswordField.text = ""
                    self.regDongVanField.text = ""
                    self.loadAccounts()
                }
            } catch {
                DispatchQueue.main.async {
                    self.regActivityIndicator.stopAnimating()
                    self.regSubmitButton.isEnabled = true
                    self.regStatusLabel.text = "❌ Lỗi: \(error.localizedDescription)"
                    self.regStatusLabel.textColor = ToriumTheme.statusRed
                }
            }
        }
    }

    private func updateRegStepUI(step: AccountRegistrar.RegistrationStep) {
        switch step {
        case .idle:
            regStatusLabel.text = "Sẵn sàng"
        case .openingContainer, .switchingContainer:
            regStatusLabel.text = "[1/6] Đang mở Crane container..."
        case .fillingForm, .fillingCredentials:
            regStatusLabel.text = "[2/6] Đang điền form đăng ký..."
        case .waitingForCaptcha, .waitingForUserCaptcha:
            regStatusLabel.text = "[3/6] Chờ giải Cloudflare Turnstile..."
        case .fetchingOTP:
            regStatusLabel.text = "[4/6] Đang đọc mã OTP từ DongVanFB API..."
        case .submittingOTP:
            regStatusLabel.text = "[5/6] Đang tự động điền mã OTP..."
        case .extractingToken:
            regStatusLabel.text = "[6/6] Đang trích xuất Bearer Token..."
        case .completed:
            regStatusLabel.text = "✅ Hoàn tất đăng ký!"
            regStatusLabel.textColor = ToriumTheme.miningGreen
        case .paused:
            regStatusLabel.text = "Đã tạm dừng"
        case .failed(let msg):
            regStatusLabel.text = "❌ Thất bại: \(msg)"
            regStatusLabel.textColor = ToriumTheme.statusRed
        }
    }

    // MARK: - Action: Batch Sign-In / Import (No OTP Required)

    @objc private func handlePickImportFile() {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: true)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }

    public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            loginTextView.text = content
            loginProgressLabel.text = "Đã nạp nội dung file. Nhấn [ĐĂNG NHẬP & BẬT ĐÀO NGAY]."
        }
    }

    @objc private func handleBatchLogin() {
        guard let text = loginTextView.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Chưa có dữ liệu", message: "Vui lòng nhập hoặc nạp file danh sách account email:pass.")
            return
        }

        let result = ImportParser.shared.parseText(text)
        guard result.totalValid > 0 else {
            showAlert(title: "Không hợp lệ", message: "Không tìm thấy tài khoản hợp lệ nào trong văn bản đã nhập.")
            return
        }

        loginSubmitButton.isEnabled = false
        loginProgressLabel.text = "Đang khởi tạo \(result.totalValid) Crane containers..."
        loginProgressBar.progress = 0.05

        // Commit valid accounts into database with auto Crane provisioning
        _ = ImportParser.shared.commitImport(accounts: result.validAccounts, autoProvisionCrane: true)
        loadAccounts()

        // Gather the newly saved accounts
        let allCurrent = DatabaseManager.shared.getAllAccounts()
        let validEmails = Set(result.validAccounts.map { $0.email.lowercased() })
        let accountsToLogin = allCurrent.filter { validEmails.contains($0.email.lowercased()) }

        Task {
            var successCount = 0
            var failCount = 0
            let total = accountsToLogin.count

            for (idx, acc) in accountsToLogin.enumerated() {
                let progressFraction = Float(idx + 1) / Float(total)
                DispatchQueue.main.async {
                    self.loginProgressBar.progress = progressFraction
                    self.loginProgressLabel.text = "[\(idx + 1)/\(total)] Đang đăng nhập: \(acc.email) (Không OTP)..."
                }

                do {
                    _ = try await AccountRegistrar.shared.performDirectLoginWithoutOTP(account: acc, onStepUpdate: { msg in
                        DispatchQueue.main.async {
                            self.loginProgressLabel.text = "[\(idx + 1)/\(total)] \(msg)"
                        }
                    })
                    successCount += 1
                } catch {
                    failCount += 1
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            // Immediately ensure Mining Engine is running
            if !MiningEngine.shared.isRunning {
                MiningEngine.shared.start()
            }

            DispatchQueue.main.async {
                self.loginProgressBar.progress = 1.0
                self.loginSubmitButton.isEnabled = true
                self.loginProgressLabel.text = "🎉 Hoàn tất! Đăng nhập thành công: \(successCount) | Thất bại: \(failCount). Đã tự động kích hoạt đào."
                self.loginTextView.text = ""
                self.loadAccounts()
            }
        }
    }

    // MARK: - UIPickerView (Crane Containers)

    public func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { craneContainers.count }
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { craneContainers[row].name }
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if row < craneContainers.count {
            selectedContainerId = craneContainers[row].id
        }
    }

    // MARK: - UITableViewDataSource & Delegate (Accounts List)

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath)
        let acc = accounts[indexPath.row]

        cell.backgroundColor = ToriumTheme.darkNavyCard
        cell.selectionStyle = .none
        cell.layer.cornerRadius = 8
        cell.clipsToBounds = true

        let containerText = acc.containerId ?? "default"
        cell.textLabel?.text = "📦 [\(containerText)] • \(acc.email)"
        cell.textLabel?.textColor = ToriumTheme.textPrimary
        cell.textLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)

        let statusText = acc.isBanned ? "🚫 Banned" : (acc.isActive ? "🟢 Active" : "⏸ Paused")
        let proxyText = acc.proxyHost != nil ? " • 🌐 Proxy" : ""
        let tokenText = acc.bearerToken != nil ? " • 🔑 Có Token" : " • ⏳ Chưa có Token"
        cell.detailTextLabel?.text = "\(statusText)\(proxyText)\(tokenText)"
        cell.detailTextLabel?.textColor = ToriumTheme.textSecondary
        cell.accessoryType = .disclosureIndicator

        return cell
    }

    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68.0
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
                if let cId = acc.containerId {
                    CraneManager.shared.removeContainer(containerId: cId)
                }
                accounts.remove(at: indexPath.row)
                tableView.deleteRows(at: [indexPath], with: .fade)
                tableCountBadge.text = " \(accounts.count) TÀI KHOẢN "
            }
        }
    }

    // MARK: - Helpers

    private func styleTextField(_ tf: UITextField, placeholder: String) {
        tf.placeholder = placeholder
        tf.font = UIFont.systemFont(ofSize: 13)
        tf.textColor = ToriumTheme.textPrimary
        tf.backgroundColor = ToriumTheme.darkNavy
        tf.layer.cornerRadius = 8
        tf.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        tf.layer.borderWidth = 1
        tf.heightAnchor.constraint(equalToConstant: 38).isActive = true
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 38))
        tf.leftView = padding
        tf.leftViewMode = .always
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
