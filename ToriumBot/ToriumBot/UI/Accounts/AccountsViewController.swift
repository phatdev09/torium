import UIKit
import UniformTypeIdentifiers

/// Accounts Management Screen cleanly separated into:
/// 1. "Tạo Mới (DongVanFB + OTP)" - Auto-generates password & account credentials, parses DongVanFB, receives OTP, and alerts Telegram
/// 2. "Đăng Nhập / Import (Không OTP)" - Direct sign-in without OTP, format guide, auto Crane provisioning, and auto-run
public final class AccountsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UIDocumentPickerDelegate, UIPickerViewDataSource, UIPickerViewDelegate {

    private let scrollView = UIScrollView()
    private let contentView = UIView()

    // Segmented Switcher
    private let segmentControl = UISegmentedControl(items: ["✨ Tạo Mới (DongVanFB)", "⚡ Đăng Nhập / Import"])

    // Form Container Stack (Collapses hidden section automatically without layout breakage)
    private let formContainerStack = UIStackView()

    // =========================================================================
    // Section 1: Tạo Tài Khoản Mới (DongVanFB + OTP)
    // =========================================================================
    private let registerContainer = UIView()
    private let regInfoLabel = UILabel()
    private let regNoticeCard = UIView()
    private let regNoticeLabel = UILabel()

    private let regDongVanTitleLabel = UILabel()
    private let regDongVanTextView = UITextView()
    private let regDongVanPasteButton = UIButton(type: .system)

    // Generator Preview Card
    private let regGeneratorCard = UIView()
    private let regPasswordPreviewLabel = UILabel()
    private let regRegenPassButton = UIButton(type: .system)
    private let regReferralPreviewLabel = UILabel()

    private let regProxyField = UITextField()
    private let regContainerPickerLabel = UILabel()
    private let regContainerPicker = UIPickerView()
    private let regSubmitButton = UIButton(type: .system)

    private let regStatusCard = UIView()
    private let regStatusDot = UIView()
    private let regStatusLabel = UILabel()
    private let regActivityIndicator = UIActivityIndicatorView(style: .medium)

    private var currentGeneratedPassword = AccountGenerator.generateSecurePassword()

    // =========================================================================
    // Section 2: Đăng Nhập / Import (Không Cần OTP - Tự Chạy)
    // =========================================================================
    private let loginContainer = UIView()
    private let loginNoticeCard = UIView()
    private let loginNoticeLabel = UILabel()

    // Format Guide Card
    private let loginGuideCard = UIView()
    private let loginGuideTitleLabel = UILabel()
    private let loginGuideBodyLabel = UILabel()
    private let loginSampleCopyButton = UIButton(type: .system)

    private let loginTextView = UITextView()
    private let loginButtonsStack = UIStackView()
    private let loginFilePickButton = UIButton(type: .system)
    private let loginSubmitButton = UIButton(type: .system)
    private let loginProgressCard = UIView()
    private let loginProgressBar = UIProgressView(progressViewStyle: .default)
    private let loginProgressLabel = UILabel()

    // =========================================================================
    // Section 3: Danh Sách Tài Khoản Đã Quản Lý
    // =========================================================================
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

        setupKeyboardDismissal()
        loadContainers()
        setupScrollView()
        setupSegmentControl()
        setupFormSections()
        setupAccountsTableSection()
        loadAccounts()
        updateSegmentView()
        updateGeneratorPreview()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadContainers()
        loadAccounts()
        updateGeneratorPreview()
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        dismissKeyboard()
    }

    // MARK: - Keyboard Handling

    private func setupKeyboardDismissal() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)

        scrollView.keyboardDismissMode = .onDrag
        accountsTableView.keyboardDismissMode = .onDrag
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func makeKeyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44))
        toolbar.barStyle = .black
        toolbar.isTranslucent = true
        let flex = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let doneBtn = UIBarButtonItem(title: "✓ Đóng Bàn Phím", style: .done, target: self, action: #selector(dismissKeyboard))
        doneBtn.tintColor = ToriumTheme.accentGold
        toolbar.items = [flex, doneBtn]
        return toolbar
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
        ToriumTheme.styleSegmentedControl(segmentControl)
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

    private func setupFormSections() {
        formContainerStack.axis = .vertical
        formContainerStack.spacing = 0
        formContainerStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formContainerStack)

        setupRegisterSection()
        setupLoginSection()

        formContainerStack.addArrangedSubview(registerContainer)
        formContainerStack.addArrangedSubview(loginContainer)

        NSLayoutConstraint.activate([
            formContainerStack.topAnchor.constraint(equalTo: segmentControl.bottomAnchor, constant: 12),
            formContainerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            formContainerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16)
        ])
    }

    // MARK: - Section 1: Tạo Mới (DongVanFB + OTP)

    private func setupRegisterSection() {
        registerContainer.translatesAutoresizingMaskIntoConstraints = false
        ToriumTheme.applyCardStyle(to: registerContainer, radius: ToriumTheme.radiusCard)

        regInfoLabel.text = "TẠO TÀI KHOẢN MỚI (DONGVANFB + OTP)"
        regInfoLabel.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        regInfoLabel.textColor = ToriumTheme.accentGold

        // Notice Card: Auto generation information
        regNoticeCard.backgroundColor = ToriumTheme.graphiteElevated
        regNoticeCard.layer.cornerRadius = 8
        regNoticeCard.layer.borderWidth = 1
        regNoticeCard.layer.borderColor = ToriumTheme.accentGold.withAlphaComponent(0.3).cgColor
        regNoticeCard.translatesAutoresizingMaskIntoConstraints = false

        regNoticeLabel.text = "🤖 TỰ ĐỘNG 100%: Bạn chỉ cần dán chuỗi DongVanFB. Hệ thống tự động tạo Mật khẩu an toàn, tự lấy Mã giới thiệu từ Cài đặt, tự tạo Crane Container và gửi thông báo qua Telegram khi hoàn tất!"
        regNoticeLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        regNoticeLabel.textColor = ToriumTheme.accentGold
        regNoticeLabel.numberOfLines = 0
        regNoticeLabel.translatesAutoresizingMaskIntoConstraints = false
        regNoticeCard.addSubview(regNoticeLabel)

        NSLayoutConstraint.activate([
            regNoticeLabel.topAnchor.constraint(equalTo: regNoticeCard.topAnchor, constant: 8),
            regNoticeLabel.leadingAnchor.constraint(equalTo: regNoticeCard.leadingAnchor, constant: 10),
            regNoticeLabel.trailingAnchor.constraint(equalTo: regNoticeCard.trailingAnchor, constant: -10),
            regNoticeLabel.bottomAnchor.constraint(equalTo: regNoticeCard.bottomAnchor, constant: -8)
        ])

        // DongVanFB Input Area
        regDongVanTitleLabel.text = "CHUỖI DONGVANFB (EMAIL | REFRESH_TOKEN | CLIENT_ID | ...):"
        regDongVanTitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        regDongVanTitleLabel.textColor = ToriumTheme.cyanHighlight

        regDongVanTextView.backgroundColor = ToriumTheme.graphiteElevated
        regDongVanTextView.textColor = ToriumTheme.textPrimary
        regDongVanTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        regDongVanTextView.layer.cornerRadius = 8
        regDongVanTextView.layer.borderWidth = 1
        regDongVanTextView.layer.borderColor = ToriumTheme.graphiteBorder.cgColor
        regDongVanTextView.heightAnchor.constraint(equalToConstant: 68).isActive = true
        regDongVanTextView.inputAccessoryView = makeKeyboardToolbar()
        regDongVanTextView.translatesAutoresizingMaskIntoConstraints = false

        regDongVanPasteButton.setTitle("📋 Dán Từ Bộ Nhớ Tạm (Paste)", for: .normal)
        regDongVanPasteButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        regDongVanPasteButton.setTitleColor(ToriumTheme.cyanHighlight, for: .normal)
        regDongVanPasteButton.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.12)
        regDongVanPasteButton.layer.cornerRadius = 6
        regDongVanPasteButton.heightAnchor.constraint(equalToConstant: 32).isActive = true
        regDongVanPasteButton.addTarget(self, action: #selector(handlePasteDongVan), for: .touchUpInside)

        // Generator Preview Card
        regGeneratorCard.backgroundColor = ToriumTheme.graphiteElevated
        regGeneratorCard.layer.cornerRadius = 8
        regGeneratorCard.layer.borderWidth = 1
        regGeneratorCard.layer.borderColor = ToriumTheme.graphiteBorder.cgColor
        regGeneratorCard.translatesAutoresizingMaskIntoConstraints = false

        regPasswordPreviewLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        regPasswordPreviewLabel.textColor = ToriumTheme.miningGreen
        regPasswordPreviewLabel.translatesAutoresizingMaskIntoConstraints = false

        regRegenPassButton.setTitle("🔄 Đổi Pass Khác", for: .normal)
        regRegenPassButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        regRegenPassButton.setTitleColor(ToriumTheme.accentGold, for: .normal)
        regRegenPassButton.addTarget(self, action: #selector(handleRegenPassword), for: .touchUpInside)
        regRegenPassButton.translatesAutoresizingMaskIntoConstraints = false

        regReferralPreviewLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        regReferralPreviewLabel.textColor = ToriumTheme.textSecondary
        regReferralPreviewLabel.translatesAutoresizingMaskIntoConstraints = false

        regGeneratorCard.addSubview(regPasswordPreviewLabel)
        regGeneratorCard.addSubview(regRegenPassButton)
        regGeneratorCard.addSubview(regReferralPreviewLabel)

        NSLayoutConstraint.activate([
            regPasswordPreviewLabel.topAnchor.constraint(equalTo: regGeneratorCard.topAnchor, constant: 8),
            regPasswordPreviewLabel.leadingAnchor.constraint(equalTo: regGeneratorCard.leadingAnchor, constant: 10),
            regPasswordPreviewLabel.trailingAnchor.constraint(lessThanOrEqualTo: regRegenPassButton.leadingAnchor, constant: -6),

            regRegenPassButton.centerYAnchor.constraint(equalTo: regPasswordPreviewLabel.centerYAnchor),
            regRegenPassButton.trailingAnchor.constraint(equalTo: regGeneratorCard.trailingAnchor, constant: -10),

            regReferralPreviewLabel.topAnchor.constraint(equalTo: regPasswordPreviewLabel.bottomAnchor, constant: 4),
            regReferralPreviewLabel.leadingAnchor.constraint(equalTo: regGeneratorCard.leadingAnchor, constant: 10),
            regReferralPreviewLabel.trailingAnchor.constraint(equalTo: regGeneratorCard.trailingAnchor, constant: -10),
            regReferralPreviewLabel.bottomAnchor.constraint(equalTo: regGeneratorCard.bottomAnchor, constant: -8)
        ])

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
        regSubmitButton.layer.cornerRadius = ToriumTheme.radiusInput
        regSubmitButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        regSubmitButton.addTarget(self, action: #selector(handleStartRegister), for: .touchUpInside)

        // Status Card
        regStatusCard.backgroundColor = ToriumTheme.graphiteElevated
        regStatusCard.layer.cornerRadius = 8
        regStatusCard.layer.borderWidth = 1
        regStatusCard.layer.borderColor = ToriumTheme.graphiteBorder.cgColor

        regStatusDot.backgroundColor = ToriumTheme.miningGreen
        regStatusDot.layer.cornerRadius = 3.5
        regStatusDot.translatesAutoresizingMaskIntoConstraints = false

        regStatusLabel.text = "Sẵn sàng: Dán chuỗi DongVanFB để hệ thống tự động xử lý toàn bộ."
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
            regNoticeCard,
            regDongVanTitleLabel,
            regDongVanTextView,
            regDongVanPasteButton,
            regGeneratorCard,
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
            regStack.topAnchor.constraint(equalTo: registerContainer.topAnchor, constant: 14),
            regStack.leadingAnchor.constraint(equalTo: registerContainer.leadingAnchor, constant: 14),
            regStack.trailingAnchor.constraint(equalTo: registerContainer.trailingAnchor, constant: -14),
            regStack.bottomAnchor.constraint(equalTo: registerContainer.bottomAnchor, constant: -14)
        ])
    }

    // MARK: - Section 2: Đăng Nhập / Import (Không Cần OTP - Tự Chạy)

    private func setupLoginSection() {
        loginContainer.translatesAutoresizingMaskIntoConstraints = false
        ToriumTheme.applyCardStyle(to: loginContainer, radius: ToriumTheme.radiusCard)

        // Notice Card
        loginNoticeCard.backgroundColor = ToriumTheme.graphiteElevated
        loginNoticeCard.layer.cornerRadius = 8
        loginNoticeCard.layer.borderWidth = 1
        loginNoticeCard.layer.borderColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.3).cgColor
        loginNoticeCard.translatesAutoresizingMaskIntoConstraints = false

        loginNoticeLabel.text = "💡 ĐĂNG NHẬP KHÔNG CẦN OTP: Đăng nhập Torium không yêu cầu gửi mã OTP. Chỉ cần nhập danh sách tài khoản theo định dạng bên dưới, hệ thống tự động gán Container, đăng nhập và chạy ngay!"
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

        // Format Guide Card
        loginGuideCard.backgroundColor = ToriumTheme.graphiteElevated
        loginGuideCard.layer.cornerRadius = 8
        loginGuideCard.layer.borderWidth = 1
        loginGuideCard.layer.borderColor = ToriumTheme.graphiteBorder.cgColor
        loginGuideCard.translatesAutoresizingMaskIntoConstraints = false

        loginGuideTitleLabel.text = "📘 HƯỚNG DẪN ĐỊNH DẠNG IMPORT (MỖI DÒNG 1 TÀI KHOẢN):"
        loginGuideTitleLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        loginGuideTitleLabel.textColor = ToriumTheme.accentGold
        loginGuideTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        loginGuideBodyLabel.text = """
        • Định dạng cơ bản: email:password
        • Kèm proxy host/port: email:password:proxy_host:proxy_port
        • Kèm proxy auth: email:password:proxy_host:proxy_port:user:pass
        • Đầy đủ sao lưu: email|password|bearer_token|clerk_id|device_id
        """
        loginGuideBodyLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        loginGuideBodyLabel.textColor = ToriumTheme.textSecondary
        loginGuideBodyLabel.numberOfLines = 0
        loginGuideBodyLabel.translatesAutoresizingMaskIntoConstraints = false

        loginSampleCopyButton.setTitle("📋 Sao Chép Định Dạng Mẫu", for: .normal)
        loginSampleCopyButton.titleLabel?.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        loginSampleCopyButton.setTitleColor(ToriumTheme.cyanHighlight, for: .normal)
        loginSampleCopyButton.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.12)
        loginSampleCopyButton.layer.cornerRadius = 6
        loginSampleCopyButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        loginSampleCopyButton.addTarget(self, action: #selector(handleCopySampleFormat), for: .touchUpInside)

        loginGuideCard.addSubview(loginGuideTitleLabel)
        loginGuideCard.addSubview(loginGuideBodyLabel)
        loginGuideCard.addSubview(loginSampleCopyButton)

        NSLayoutConstraint.activate([
            loginGuideTitleLabel.topAnchor.constraint(equalTo: loginGuideCard.topAnchor, constant: 8),
            loginGuideTitleLabel.leadingAnchor.constraint(equalTo: loginGuideCard.leadingAnchor, constant: 10),
            loginGuideTitleLabel.trailingAnchor.constraint(equalTo: loginGuideCard.trailingAnchor, constant: -10),

            loginGuideBodyLabel.topAnchor.constraint(equalTo: loginGuideTitleLabel.bottomAnchor, constant: 4),
            loginGuideBodyLabel.leadingAnchor.constraint(equalTo: loginGuideCard.leadingAnchor, constant: 10),
            loginGuideBodyLabel.trailingAnchor.constraint(equalTo: loginGuideCard.trailingAnchor, constant: -10),

            loginSampleCopyButton.topAnchor.constraint(equalTo: loginGuideBodyLabel.bottomAnchor, constant: 6),
            loginSampleCopyButton.leadingAnchor.constraint(equalTo: loginGuideCard.leadingAnchor, constant: 10),
            loginSampleCopyButton.trailingAnchor.constraint(equalTo: loginGuideCard.trailingAnchor, constant: -10),
            loginSampleCopyButton.bottomAnchor.constraint(equalTo: loginGuideCard.bottomAnchor, constant: -8)
        ])

        // Multi-line Text Area with accessory toolbar
        loginTextView.backgroundColor = ToriumTheme.graphiteElevated
        loginTextView.textColor = ToriumTheme.textPrimary
        loginTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        loginTextView.layer.cornerRadius = 8
        loginTextView.layer.borderWidth = 1
        loginTextView.layer.borderColor = ToriumTheme.graphiteBorder.cgColor
        loginTextView.heightAnchor.constraint(equalToConstant: 95).isActive = true
        loginTextView.inputAccessoryView = makeKeyboardToolbar()
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

        loginSubmitButton.setTitle("⚡ BẮT ĐẦU ĐĂNG NHẬP (KHÔNG CẦN OTP)", for: .normal)
        loginSubmitButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .heavy)
        loginSubmitButton.setTitleColor(UIColor.black, for: .normal)
        loginSubmitButton.backgroundColor = ToriumTheme.accentGold
        loginSubmitButton.layer.cornerRadius = ToriumTheme.radiusInput
        loginSubmitButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        loginSubmitButton.addTarget(self, action: #selector(handleBatchLogin), for: .touchUpInside)

        loginButtonsStack.addArrangedSubview(loginFilePickButton)
        loginButtonsStack.addArrangedSubview(loginSubmitButton)

        // Progress Card
        loginProgressCard.backgroundColor = ToriumTheme.graphiteElevated
        loginProgressCard.layer.cornerRadius = 8
        loginProgressCard.layer.borderWidth = 1
        loginProgressCard.layer.borderColor = ToriumTheme.graphiteBorder.cgColor

        loginProgressLabel.text = "Chờ nạp danh sách tài khoản cần đăng nhập."
        loginProgressLabel.font = UIFont.systemFont(ofSize: 11, weight: .medium)
        loginProgressLabel.textColor = ToriumTheme.textSecondary
        loginProgressLabel.translatesAutoresizingMaskIntoConstraints = false

        loginProgressBar.progress = 0.0
        loginProgressBar.progressTintColor = ToriumTheme.accentGold
        loginProgressBar.trackTintColor = ToriumTheme.graphiteBorder
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
            loginGuideCard,
            loginTextView,
            loginButtonsStack,
            loginProgressCard
        ])
        loginStack.axis = .vertical
        loginStack.spacing = 10
        loginStack.translatesAutoresizingMaskIntoConstraints = false
        loginContainer.addSubview(loginStack)

        NSLayoutConstraint.activate([
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
            tableSectionHeader.topAnchor.constraint(equalTo: formContainerStack.bottomAnchor, constant: 16),
            tableSectionHeader.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            tableSectionHeader.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            tableSectionHeader.heightAnchor.constraint(equalToConstant: 24),

            tableTitleLabel.centerYAnchor.constraint(equalTo: tableSectionHeader.centerYAnchor),
            tableTitleLabel.leadingAnchor.constraint(equalTo: tableSectionHeader.leadingAnchor),
            tableTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: tableCountBadge.leadingAnchor, constant: -8),

            tableCountBadge.centerYAnchor.constraint(equalTo: tableSectionHeader.centerYAnchor),
            tableCountBadge.trailingAnchor.constraint(equalTo: tableSectionHeader.trailingAnchor),
            tableCountBadge.heightAnchor.constraint(equalToConstant: 20),

            accountsTableView.topAnchor.constraint(equalTo: tableSectionHeader.bottomAnchor, constant: 8),
            accountsTableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            accountsTableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            accountsTableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            heightConstraint
        ])
    }

    private func updateSegmentView() {
        dismissKeyboard()
        let isRegisterMode = segmentControl.selectedSegmentIndex == 0
        registerContainer.isHidden = !isRegisterMode
        loginContainer.isHidden = isRegisterMode
    }

    @objc private func handleSegmentChanged() {
        updateSegmentView()
    }

    private func updateGeneratorPreview() {
        regPasswordPreviewLabel.text = "🎲 Mật khẩu tạo tự động: \(currentGeneratedPassword)"
        let ref = DatabaseManager.shared.getSetting(key: "master_referral_code")
        let displayRef = (ref?.isEmpty == false) ? ref! : "Chưa cài đặt"
        regReferralPreviewLabel.text = "🎟️ Mã ref mặc định (từ Cài đặt): \(displayRef)"
    }

    @objc private func handleRegenPassword() {
        currentGeneratedPassword = AccountGenerator.generateSecurePassword()
        updateGeneratorPreview()
    }

    @objc private func handlePasteDongVan() {
        if let pasteString = UIPasteboard.general.string {
            regDongVanTextView.text = pasteString
        }
    }

    @objc private func handleCopySampleFormat() {
        let sample = """
        user1@hotmail.com:Torium#Pass123!
        user2@gmail.com:Torium#Pass456!:103.14.22.1:8080
        """
        UIPasteboard.general.string = sample
        loginTextView.text = sample
        showAlert(title: "Đã Sao Chép", message: "Đã sao chép và điền mẫu định dạng vào ô nhập tài khoản!")
    }

    // MARK: - Action: Start Registration (DongVanFB + Auto Gen Password + Master Ref)

    @objc private func handleStartRegister() {
        dismissKeyboard()

        guard let dvText = regDongVanTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines), !dvText.isEmpty else {
            showAlert(title: "Thiếu chuỗi DongVanFB", message: "Vui lòng dán chuỗi DongVanFB (chứa email và refresh_token) vào ô nhập.")
            return
        }

        guard let cred = DongVanCredential(line: dvText) else {
            showAlert(title: "Sai định dạng DongVanFB", message: "Chuỗi DongVanFB không hợp lệ. Cần tối thiểu email|refresh_token hoặc email|password|refresh_token|client_id.")
            return
        }

        let targetEmail = cred.email
        let targetPassword = currentGeneratedPassword
        let masterRef = DatabaseManager.shared.getSetting(key: "master_referral_code")
        let proxyStr = regProxyField.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        regSubmitButton.isEnabled = false
        regActivityIndicator.startAnimating()
        regStatusLabel.text = "Đang khởi tạo tài khoản [\(targetEmail)]..."

        Task {
            do {
                _ = try await AccountRegistrar.shared.startRegistration(
                    email: targetEmail,
                    password: targetPassword,
                    referralCode: masterRef,
                    proxyString: proxyStr,
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
                    self.regStatusLabel.text = "✅ Đăng ký thành công! Token đã lưu và gửi qua Telegram."
                    self.regStatusLabel.textColor = ToriumTheme.miningGreen
                    self.regDongVanTextView.text = ""
                    self.currentGeneratedPassword = AccountGenerator.generateSecurePassword()
                    self.updateGeneratorPreview()
                    self.loadAccounts()
                    self.showAlert(
                        title: "Đăng Ký Thành Công!",
                        message: "Tài khoản [\(targetEmail)] đã được tạo với mật khẩu: [\(targetPassword)]. Đã lưu vào CSDL và gửi thông báo qua Telegram!"
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    self.regActivityIndicator.stopAnimating()
                    self.regSubmitButton.isEnabled = true
                    self.regStatusLabel.text = "❌ Thất bại: \(error.localizedDescription)"
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
            regStatusLabel.text = "[2/6] Đang tự động điền form (Mật khẩu tự tạo)..."
        case .waitingForCaptcha, .waitingForUserCaptcha:
            regStatusLabel.text = "[3/6] Chờ giải Cloudflare Turnstile..."
        case .fetchingOTP:
            regStatusLabel.text = "[4/6] Đang đọc mã OTP từ DongVanFB API..."
        case .submittingOTP:
            regStatusLabel.text = "[5/6] Đang tự động điền mã OTP..."
        case .extractingToken:
            regStatusLabel.text = "[6/6] Đang trích xuất Bearer Token & Lưu Telegram..."
        case .completed:
            regStatusLabel.text = "✅ Hoàn tất đăng ký & đã gửi Telegram!"
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
        dismissKeyboard()
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
        dismissKeyboard()
        guard let text = loginTextView.text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(title: "Chưa có dữ liệu", message: "Vui lòng nhập hoặc nạp file danh sách account email:pass.")
            return
        }

        let result = ImportParser.shared.parseText(text)
        let totalCandidates = result.validAccounts.count + result.duplicateAccounts.count
        guard totalCandidates > 0 else {
            showAlert(title: "Không tìm thấy tài khoản", message: "Không tìm thấy tài khoản hợp lệ nào trong nội dung đã nhập (định dạng email:mật khẩu).")
            return
        }

        loginSubmitButton.isEnabled = false
        loginProgressLabel.text = "Đang xử lý \(totalCandidates) tài khoản..."
        loginProgressBar.progress = 0.05

        // 1. Commit new valid accounts with auto Crane provisioning
        if !result.validAccounts.isEmpty {
            _ = ImportParser.shared.commitImport(accounts: result.validAccounts, autoProvisionCrane: true)
        }

        // 2. For duplicate / existing accounts, update password/proxy if provided and ensure container exists
        let currentAccounts = DatabaseManager.shared.getAllAccounts()
        for dup in result.duplicateAccounts {
            if var existing = currentAccounts.first(where: { $0.email.lowercased() == dup.email.lowercased() }) {
                var modified = false
                if !dup.password.isEmpty && existing.password != dup.password {
                    existing.password = dup.password
                    modified = true
                }
                if let ph = dup.proxyHost, ph != existing.proxyHost {
                    existing.proxyHost = ph
                    existing.proxyPort = dup.proxyPort
                    existing.proxyUsername = dup.proxyUsername
                    existing.proxyPassword = dup.proxyPassword
                    existing.proxyProtocol = dup.proxyProtocol
                    modified = true
                }
                if existing.containerId == nil || existing.containerId?.isEmpty == true {
                    let nextIdx = (existing.id.map(Int.init) ?? 1)
                    existing.containerId = CraneManager.shared.provisionContainer(forEmail: existing.email, index: nextIdx)
                    modified = true
                }
                if modified {
                    DatabaseManager.shared.updateAccount(existing)
                }
            }
        }
        loadAccounts()

        // 3. Collect all target accounts for sign-in
        let allCurrent = DatabaseManager.shared.getAllAccounts()
        let targetEmails = Set((result.validAccounts + result.duplicateAccounts).map { $0.email.lowercased() })
        let accountsToLogin = allCurrent.filter { targetEmails.contains($0.email.lowercased()) }

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
                self.loginProgressLabel.text = "🎉 Hoàn tất! Đăng nhập thành công: \(successCount) | Thất bại: \(failCount). Đã tự động kích hoạt cày ngầm."
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
        ToriumTheme.applyInputStyle(to: tf)
        tf.attributedPlaceholder = NSAttributedString(
            string: placeholder,
            attributes: [.foregroundColor: ToriumTheme.textMuted]
        )
        tf.heightAnchor.constraint(equalToConstant: 40).isActive = true
        tf.inputAccessoryView = makeKeyboardToolbar()
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
