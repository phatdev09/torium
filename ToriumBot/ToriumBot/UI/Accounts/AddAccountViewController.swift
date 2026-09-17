import UIKit

/// Form for creating/registering a new account with Crane container selection and manual captcha modal
public final class AddAccountViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    private let emailField = UITextField()
    private let passwordField = UITextField()
    private let dongvanCredField = UITextField()
    private let containerPicker = UIPickerView()
    private let statusLabel = UILabel()
    private let submitButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .large)

    private var containers: [CraneContainer] = []
    private var selectedContainerId: String = "default"

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.background
        navigationItem.title = "Thêm Account Mới"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Đóng", style: .plain, target: self, action: #selector(dismissSelf))

        loadContainers()
        setupViews()
    }

    private func loadContainers() {
        self.containers = CraneManager.shared.fetchContainers()
        if let first = containers.first {
            self.selectedContainerId = first.id
        }
    }

    private func setupViews() {
        let scrollView = UIScrollView()
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])

        styleTextField(emailField, placeholder: "Email (vd: user@hotmail.com)")
        styleTextField(passwordField, placeholder: "Password")
        passwordField.isSecureTextEntry = true

        styleTextField(dongvanCredField, placeholder: "dongvanfb: refresh_token|client_id (tùy chọn)")

        let containerLabel = UILabel()
        containerLabel.text = "Chọn Crane Container:"
        containerLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        containerLabel.textColor = ToriumTheme.textSecondary

        containerPicker.dataSource = self
        containerPicker.delegate = self
        containerPicker.heightAnchor.constraint(equalToConstant: 100).isActive = true

        submitButton.setTitle("Bắt Đầu Đăng Ký / Thiết Lập", for: .normal)
        submitButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        submitButton.setTitleColor(UIColor.black, for: .normal)
        submitButton.backgroundColor = ToriumTheme.accentGold
        submitButton.layer.cornerRadius = ToriumTheme.cornerRadius
        submitButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        submitButton.addTarget(self, action: #selector(handleSubmit), for: .touchUpInside)

        statusLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        statusLabel.textColor = ToriumTheme.textSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0

        activityIndicator.color = ToriumTheme.accentGold
        activityIndicator.hidesWhenStopped = true

        stackView.addArrangedSubview(emailField)
        stackView.addArrangedSubview(passwordField)
        stackView.addArrangedSubview(dongvanCredField)
        stackView.addArrangedSubview(containerLabel)
        stackView.addArrangedSubview(containerPicker)
        stackView.addArrangedSubview(submitButton)
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(statusLabel)
    }

    private func styleTextField(_ field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.textColor = ToriumTheme.textPrimary
        field.backgroundColor = ToriumTheme.cardBackground
        field.layer.cornerRadius = 8
        field.layer.borderWidth = 1
        field.layer.borderColor = ToriumTheme.cardBorder.cgColor
        field.heightAnchor.constraint(equalToConstant: 44).isActive = true
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        field.leftView = padding
        field.leftViewMode = .always
    }

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }

    @objc private func handleSubmit() {
        guard let email = emailField.text, !email.isEmpty,
              let password = passwordField.text, !password.isEmpty else {
            showAlert(title: "Lỗi", message: "Vui lòng nhập đầy đủ Email và Password.")
            return
        }

        var cred: DongVanCredential?
        if let dvText = dongvanCredField.text, !dvText.isEmpty {
            let combined = "\(email)|\(password)|\(dvText)"
            cred = DongVanCredential(line: combined)
        }

        submitButton.isEnabled = false
        activityIndicator.startAnimating()

        Task {
            do {
                _ = try await AccountRegistrar.shared.startRegistration(
                    email: email,
                    password: password,
                    credential: cred,
                    containerId: self.selectedContainerId,
                    onStepUpdate: { [weak self] step in
                        DispatchQueue.main.async {
                            self?.updateStepUI(step: step)
                        }
                    },
                    onRequestCaptchaSolve: { [weak self] (completion: @escaping () -> Void) in
                        DispatchQueue.main.async {
                            let alert = UIAlertController(
                                title: "Giải Captcha Cloudflare",
                                message: "Torium app đã được mở trong container. Vui lòng hoàn thành Cloudflare Turnstile captcha trên màn hình rồi nhấn nút bên dưới.",
                                preferredStyle: .alert
                            )
                            alert.addAction(UIAlertAction(title: "Đã solve xong", style: .default, handler: { _ in
                                completion()
                            }))
                            self?.present(alert, animated: true)
                        }
                    }
                )

                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlert(title: "Thành công", message: "Tài khoản đã được đăng ký và lưu vào database!") {
                        self.dismiss(animated: true)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.submitButton.isEnabled = true
                    self.statusLabel.text = "Thất bại: \(error.localizedDescription)"
                    self.statusLabel.textColor = ToriumTheme.statusRed
                }
            }
        }
    }

    private func updateStepUI(step: AccountRegistrar.RegistrationStep) {
        switch step {
        case .idle:
            statusLabel.text = "Sẵn sàng"
        case .openingContainer, .switchingContainer:
            statusLabel.text = "Đang mở Crane container..."
        case .fillingCredentials, .fillingForm:
            statusLabel.text = "Đang điền thông tin đăng ký..."
        case .waitingForUserCaptcha, .waitingForCaptcha:
            statusLabel.text = "Đang chờ giải captcha Cloudflare..."
        case .fetchingOTP:
            statusLabel.text = "Đang kiểm tra OTP qua dongvanfb..."
        case .submittingOTP:
            statusLabel.text = "Đang gửi OTP..."
        case .extractingToken:
            statusLabel.text = "Đang trích xuất Bearer token..."
        case .completed:
            statusLabel.text = "Đã hoàn thành!"
            statusLabel.textColor = ToriumTheme.statusGreen
        case .paused:
            statusLabel.text = "Đã tạm dừng"
        case .failed(let msg):
            statusLabel.text = "Lỗi: \(msg)"
            statusLabel.textColor = ToriumTheme.statusRed
        }
    }

    private func showAlert(title: String, message: String, onDismiss: (() -> Void)? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
            onDismiss?()
        }))
        present(alert, animated: true)
    }

    // MARK: - UIPickerViewDataSource & Delegate

    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return containers.count
    }

    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return containers[row].name
    }

    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        selectedContainerId = containers[row].id
    }
}
