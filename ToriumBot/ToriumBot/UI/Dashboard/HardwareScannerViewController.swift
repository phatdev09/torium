import UIKit

/// High-tech Startup Hardware Diagnostic & Auto-Optimization Screen
public final class HardwareScannerViewController: UIViewController {

    private let backgroundView = UIView()
    private let radarContainer = UIView()
    private let radarIconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    private let statusLabel = UILabel()
    private let progressBar = UIProgressView(progressViewStyle: .default)

    private let reportCard = UIView()
    private let specsStackView = UIStackView()

    private let profileCard = UIView()
    private let profileBadgeLabel = UILabel()
    private let profileExplainLabel = UILabel()

    private let applyButton = UIButton(type: .system)

    private var currentReport: HardwareReport?
    private var scanTimer: Timer?
    private var scanProgress: Float = 0.0

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ToriumTheme.darkNavy
        setupUI()
        startDiagnosticScan()
    }

    private func setupUI() {
        // Background subtle grid styling
        backgroundView.translatesAutoresizingMaskIntoConstraints = false
        backgroundView.backgroundColor = ToriumTheme.darkNavy
        view.addSubview(backgroundView)

        // Radar Container & Icon
        radarContainer.translatesAutoresizingMaskIntoConstraints = false
        radarContainer.backgroundColor = ToriumTheme.darkNavyCard
        radarContainer.layer.cornerRadius = 36
        radarContainer.layer.borderWidth = 1.5
        radarContainer.layer.borderColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.4).cgColor
        view.addSubview(radarContainer)

        radarIconView.translatesAutoresizingMaskIntoConstraints = false
        radarIconView.image = UIImage(systemName: "cpu.fill")
        radarIconView.tintColor = ToriumTheme.cyanHighlight
        radarIconView.contentMode = .scaleAspectFit
        radarContainer.addSubview(radarIconView)

        // Titles
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "HARDWARE SCANNER"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .black)
        titleLabel.textColor = ToriumTheme.textPrimary
        titleLabel.textAlignment = .center
        view.addSubview(titleLabel)

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.text = "Tự động phân tích phần cứng & Tối ưu hóa 100% hệ thống"
        subtitleLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        subtitleLabel.textColor = ToriumTheme.textSecondary
        subtitleLabel.textAlignment = .center
        view.addSubview(subtitleLabel)

        // Progress Bar & Status
        progressBar.translatesAutoresizingMaskIntoConstraints = false
        progressBar.progressTintColor = ToriumTheme.cyanHighlight
        progressBar.trackTintColor = ToriumTheme.darkNavyBorder
        progressBar.layer.cornerRadius = 3
        progressBar.clipsToBounds = true
        view.addSubview(progressBar)

        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.text = "Đang kết nối vi xử lý..."
        statusLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        statusLabel.textColor = ToriumTheme.cyanHighlight
        statusLabel.textAlignment = .center
        view.addSubview(statusLabel)

        // Hardware Specs Card
        setupReportCard()

        // Profile Recommendation Card
        setupProfileCard()

        // Apply Button
        applyButton.translatesAutoresizingMaskIntoConstraints = false
        applyButton.setTitle("⚡ ÁP DỤNG CẤU HÌNH TỐI ƯU & VÀO APP", for: .normal)
        applyButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        applyButton.setTitleColor(UIColor.black, for: .normal)
        applyButton.backgroundColor = ToriumTheme.cyanHighlight
        applyButton.layer.cornerRadius = 12
        applyButton.layer.shadowColor = ToriumTheme.cyanHighlight.cgColor
        applyButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        applyButton.layer.shadowRadius = 8
        applyButton.layer.shadowOpacity = 0.4
        applyButton.alpha = 0.0
        applyButton.addTarget(self, action: #selector(handleApplyAndProceed), for: .touchUpInside)
        view.addSubview(applyButton)

        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
            backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            radarContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            radarContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            radarContainer.widthAnchor.constraint(equalToConstant: 72),
            radarContainer.heightAnchor.constraint(equalToConstant: 72),

            radarIconView.centerXAnchor.constraint(equalTo: radarContainer.centerXAnchor),
            radarIconView.centerYAnchor.constraint(equalTo: radarContainer.centerYAnchor),
            radarIconView.widthAnchor.constraint(equalToConstant: 36),
            radarIconView.heightAnchor.constraint(equalToConstant: 36),

            titleLabel.topAnchor.constraint(equalTo: radarContainer.bottomAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressBar.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
            progressBar.heightAnchor.constraint(equalToConstant: 6),

            statusLabel.topAnchor.constraint(equalTo: progressBar.bottomAnchor, constant: 8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            reportCard.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 16),
            reportCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            reportCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            profileCard.topAnchor.constraint(equalTo: reportCard.bottomAnchor, constant: 12),
            profileCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            profileCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            applyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            applyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            applyButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            applyButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    private func setupReportCard() {
        reportCard.translatesAutoresizingMaskIntoConstraints = false
        reportCard.backgroundColor = ToriumTheme.darkNavyCard
        reportCard.layer.cornerRadius = 12
        reportCard.layer.borderWidth = 1
        reportCard.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        reportCard.alpha = 0.0
        view.addSubview(reportCard)

        specsStackView.translatesAutoresizingMaskIntoConstraints = false
        specsStackView.axis = .vertical
        specsStackView.spacing = 8
        reportCard.addSubview(specsStackView)

        NSLayoutConstraint.activate([
            specsStackView.topAnchor.constraint(equalTo: reportCard.topAnchor, constant: 12),
            specsStackView.leadingAnchor.constraint(equalTo: reportCard.leadingAnchor, constant: 14),
            specsStackView.trailingAnchor.constraint(equalTo: reportCard.trailingAnchor, constant: -14),
            specsStackView.bottomAnchor.constraint(equalTo: reportCard.bottomAnchor, constant: -12)
        ])
    }

    private func setupProfileCard() {
        profileCard.translatesAutoresizingMaskIntoConstraints = false
        profileCard.backgroundColor = ToriumTheme.darkNavyCard
        profileCard.layer.cornerRadius = 12
        profileCard.layer.borderWidth = 1
        profileCard.layer.borderColor = ToriumTheme.toriumYellow.withAlphaComponent(0.4).cgColor
        profileCard.alpha = 0.0
        view.addSubview(profileCard)

        profileBadgeLabel.translatesAutoresizingMaskIntoConstraints = false
        profileBadgeLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        profileBadgeLabel.textColor = ToriumTheme.toriumYellow

        profileExplainLabel.translatesAutoresizingMaskIntoConstraints = false
        profileExplainLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        profileExplainLabel.textColor = ToriumTheme.textSecondary
        profileExplainLabel.numberOfLines = 3

        let stack = UIStackView(arrangedSubviews: [profileBadgeLabel, profileExplainLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 6
        profileCard.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: profileCard.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: profileCard.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: profileCard.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: profileCard.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Scan Flow

    private func startDiagnosticScan() {
        let steps = [
            "Quét vi xử lý SoC & Kiến trúc CPU...",
            "Đo kiểm RAM vật lý & Ngưỡng bộ nhớ khả dụng...",
            "Phát hiện phân vùng Jailbreak (Rootful / Rootless)...",
            "Kiểm tra Dynamic Loader Tweak Crane & ToriumHelper...",
            "Đo kiểm nhiệt độ phần cứng & Pin...",
            "Hoàn tất chẩn đoán! Khởi tạo cấu hình tối ưu..."
        ]

        var stepIndex = 0
        scanTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            self.scanProgress += 0.18
            self.progressBar.setProgress(min(1.0, self.scanProgress), animated: true)

            if stepIndex < steps.count {
                self.statusLabel.text = steps[stepIndex]
                stepIndex += 1
            }

            if self.scanProgress >= 1.0 {
                timer.invalidate()
                self.finalizeScan()
            }
        }
    }

    private func finalizeScan() {
        let report = HardwareOptimizer.shared.scanHardware()
        self.currentReport = report

        statusLabel.text = "✅ Chẩn đoán hoàn tất 100%!"
        statusLabel.textColor = ToriumTheme.miningGreen

        populateReportSpecs(report)
        profileBadgeLabel.text = report.profile.badgeTitle
        profileExplainLabel.text = report.profile.explanation

        UIView.animate(withDuration: 0.4) {
            self.reportCard.alpha = 1.0
            self.profileCard.alpha = 1.0
            self.applyButton.alpha = 1.0
        }
    }

    private func populateReportSpecs(_ report: HardwareReport) {
        specsStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        let rows: [(String, String, String)] = [
            ("Thiết bị", report.friendlyName, "iphone"),
            ("Vi xử lý (SoC)", "\(report.socChip) (\(report.cpuCores) Cores)", "cpu"),
            ("Bộ nhớ RAM", "\(report.totalRAMGB) GB (Khả dụng: \(report.availableRAMMB) MB)", "memorychip"),
            ("Môi trường", report.jailbreakType, "shield.lefthalf.filled"),
            ("Crane Tweak", report.craneStatus, "shippingbox.fill"),
            ("Pin & Nhiệt", "\(report.isCharging ? "⚡" : "🔋") \(report.batteryLevel)% | \(report.thermalStatus)", "bolt.fill")
        ]

        for (label, value, icon) in rows {
            let rowView = makeSpecRow(title: label, value: value, icon: icon)
            specsStackView.addArrangedSubview(rowView)
        }
    }

    private func makeSpecRow(title: String, value: String, icon: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.alignment = .center
        container.spacing = 8

        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = ToriumTheme.cyanHighlight
        iconView.contentMode = .scaleAspectFit
        iconView.widthAnchor.constraint(equalToConstant: 16).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 16).isActive = true

        let titleLbl = UILabel()
        titleLbl.text = title
        titleLbl.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        titleLbl.textColor = ToriumTheme.textSecondary
        titleLbl.widthAnchor.constraint(equalToConstant: 80).isActive = true

        let valLbl = UILabel()
        valLbl.text = value
        valLbl.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        valLbl.textColor = ToriumTheme.textPrimary
        valLbl.textAlignment = .right

        container.addArrangedSubview(iconView)
        container.addArrangedSubview(titleLbl)
        container.addArrangedSubview(valLbl)
        return container
    }

    @objc private func handleApplyAndProceed() {
        guard let report = currentReport else { return }
        HardwareOptimizer.shared.applyOptimalProfile(report)

        guard let window = view.window else { return }
        let mainTabBar = MainTabBarController()

        UIView.transition(with: window, duration: 0.4, options: .transitionCrossDissolve, animations: {
            window.rootViewController = mainTabBar
        }, completion: nil)
    }
}
