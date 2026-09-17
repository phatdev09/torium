import UIKit

/// High-tech cybernetic cell displaying detailed Account & Crane Container status on Dashboard
public final class AccountSummaryCell: UITableViewCell {
    public static let reuseIdentifier = "AccountSummaryCell"

    private let cardContainer = UIView()
    private let topRowStack = UIStackView()
    private let containerBadge = UILabel()
    private let statusBadge = UILabel()

    private let middleRowStack = UIStackView()
    private let emailLabel = UILabel()
    private let clerkIdLabel = UILabel()

    private let metricStack = UIStackView()
    private let metricRow1 = UIStackView()
    private let metricRow2 = UIStackView()
    private let balancePill = UILabel()
    private let adsPill = UILabel()
    private let proxyPill = UILabel()
    private let countdownPill = UILabel()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        backgroundColor = .clear
        selectionStyle = .none

        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        ToriumTheme.applyCardStyle(to: cardContainer, radius: ToriumTheme.radiusCard)
        contentView.addSubview(cardContainer)

        // Top Row: Container Badge (Left) + Status Badge (Right)
        topRowStack.axis = .horizontal
        topRowStack.distribution = .equalSpacing
        topRowStack.alignment = .center
        topRowStack.translatesAutoresizingMaskIntoConstraints = false

        containerBadge.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .bold)
        containerBadge.textColor = ToriumTheme.cyanHighlight
        containerBadge.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.12)
        containerBadge.layer.cornerRadius = 5
        containerBadge.layer.borderWidth = 0.8
        containerBadge.layer.borderColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.35).cgColor
        containerBadge.clipsToBounds = true
        containerBadge.textAlignment = .center
        containerBadge.adjustsFontSizeToFitWidth = true
        containerBadge.minimumScaleFactor = 0.75

        statusBadge.font = UIFont.systemFont(ofSize: 10, weight: .black)
        statusBadge.layer.cornerRadius = 5
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center
        statusBadge.adjustsFontSizeToFitWidth = true
        statusBadge.minimumScaleFactor = 0.75

        topRowStack.addArrangedSubview(containerBadge)
        topRowStack.addArrangedSubview(statusBadge)

        // Middle Row: Email + Clerk / Device ID
        middleRowStack.axis = .horizontal
        middleRowStack.distribution = .fill
        middleRowStack.alignment = .firstBaseline
        middleRowStack.spacing = 8
        middleRowStack.translatesAutoresizingMaskIntoConstraints = false

        emailLabel.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        emailLabel.textColor = ToriumTheme.textPrimary
        emailLabel.adjustsFontSizeToFitWidth = true
        emailLabel.minimumScaleFactor = 0.85
        emailLabel.lineBreakMode = .byTruncatingMiddle
        emailLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        emailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        clerkIdLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        clerkIdLabel.textColor = ToriumTheme.textMuted
        clerkIdLabel.textAlignment = .right
        clerkIdLabel.setContentHuggingPriority(.required, for: .horizontal)
        clerkIdLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        middleRowStack.addArrangedSubview(emailLabel)
        middleRowStack.addArrangedSubview(clerkIdLabel)

        // Bottom 2-Row Metric Grid: Prevents text clipping on all mobile screen widths
        metricStack.axis = .vertical
        metricStack.spacing = 6
        metricStack.distribution = .fillEqually
        metricStack.translatesAutoresizingMaskIntoConstraints = false

        metricRow1.axis = .horizontal
        metricRow1.distribution = .fillEqually
        metricRow1.spacing = 8

        metricRow2.axis = .horizontal
        metricRow2.distribution = .fillEqually
        metricRow2.spacing = 8

        styleMetricPill(balancePill, color: ToriumTheme.accentGold)
        styleMetricPill(adsPill, color: ToriumTheme.toriumYellow)
        styleMetricPill(proxyPill, color: ToriumTheme.textSecondary)
        styleMetricPill(countdownPill, color: ToriumTheme.miningGreen)

        metricRow1.addArrangedSubview(balancePill)
        metricRow1.addArrangedSubview(adsPill)

        metricRow2.addArrangedSubview(proxyPill)
        metricRow2.addArrangedSubview(countdownPill)

        metricStack.addArrangedSubview(metricRow1)
        metricStack.addArrangedSubview(metricRow2)

        cardContainer.addSubview(topRowStack)
        cardContainer.addSubview(middleRowStack)
        cardContainer.addSubview(metricStack)

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            topRowStack.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 10),
            topRowStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 12),
            topRowStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -12),
            topRowStack.heightAnchor.constraint(equalToConstant: 20),

            containerBadge.heightAnchor.constraint(equalToConstant: 20),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),

            middleRowStack.topAnchor.constraint(equalTo: topRowStack.bottomAnchor, constant: 6),
            middleRowStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 12),
            middleRowStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -12),
            middleRowStack.heightAnchor.constraint(equalToConstant: 18),

            metricStack.topAnchor.constraint(equalTo: middleRowStack.bottomAnchor, constant: 8),
            metricStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 12),
            metricStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -12),
            metricStack.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -10),
            metricStack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func styleMetricPill(_ label: UILabel, color: UIColor) {
        label.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        label.textColor = color
        label.backgroundColor = color.withAlphaComponent(0.10)
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
    }

    public func configure(with account: Account, stats: MiningStats?, isCurrentlyMining: Bool = false) {
        // 1. Container ID badge
        let cId = account.containerId ?? "default"
        if cId.count > 16 {
            containerBadge.text = " 📦 Crane: \(cId.prefix(10))... "
        } else {
            containerBadge.text = " 📦 Crane: \(cId) "
        }

        // 2. Status badge & dynamic glowing border
        if account.isBanned {
            statusBadge.text = " 🚫 BANNED (403) "
            statusBadge.backgroundColor = ToriumTheme.statusRed.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.statusRed
            cardContainer.layer.borderColor = ToriumTheme.statusRed.withAlphaComponent(0.5).cgColor
        } else if !account.isActive {
            statusBadge.text = " ⏸ TẠM DỪNG "
            statusBadge.backgroundColor = UIColor.darkGray.withAlphaComponent(0.3)
            statusBadge.textColor = UIColor.lightGray
            cardContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        } else if isCurrentlyMining {
            statusBadge.text = " ⚡ ĐANG CÀY (ACTIVE) "
            statusBadge.backgroundColor = ToriumTheme.miningGreen.withAlphaComponent(0.28)
            statusBadge.textColor = ToriumTheme.miningGreen
            cardContainer.layer.borderColor = ToriumTheme.miningGreen.withAlphaComponent(0.6).cgColor
        } else if let stats = stats, stats.adsRemainingHour == 0 {
            statusBadge.text = " ⏳ CHỜ COOLDOWN "
            statusBadge.backgroundColor = ToriumTheme.toriumYellow.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.toriumYellow
            cardContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        } else {
            statusBadge.text = " 🟢 SẴN SÀNG (IDLE) "
            statusBadge.backgroundColor = ToriumTheme.miningGreen.withAlphaComponent(0.16)
            statusBadge.textColor = ToriumTheme.miningGreen
            cardContainer.layer.borderColor = ToriumTheme.darkNavyBorder.cgColor
        }

        // 3. Email & Clerk ID
        emailLabel.text = account.email
        if let clerk = account.clerkId, !clerk.isEmpty {
            clerkIdLabel.text = "ID: \(clerk.prefix(12))..."
        } else if let dev = account.deviceId, !dev.isEmpty {
            clerkIdLabel.text = "Dev: \(dev.prefix(8))..."
        } else {
            clerkIdLabel.text = "Chưa link token"
        }

        // 4. Balance Pill
        let balance = stats?.torBalance ?? 0.0
        balancePill.text = " 💰 \(String(format: "%.3f", balance)) TOR "

        // 5. Ads Pill
        let ads = stats?.adsWatched ?? 0
        adsPill.text = " 📺 \(ads)/120 Ads "

        // 6. Proxy Pill
        if let host = account.proxyHost, let port = account.proxyPort, !host.isEmpty {
            let shortHost = host.count > 12 ? "\(host.prefix(9)).." : host
            proxyPill.text = " 🌐 \(shortHost):\(port) "
            proxyPill.textColor = ToriumTheme.cyanHighlight
            proxyPill.backgroundColor = ToriumTheme.cyanHighlight.withAlphaComponent(0.12)
        } else {
            proxyPill.text = " 🏠 Direct IP "
            proxyPill.textColor = ToriumTheme.textMuted
            proxyPill.backgroundColor = ToriumTheme.cardBorder.withAlphaComponent(0.4)
        }

        // 7. Next ad countdown Pill
        if let nextAd = stats?.nextAdAt {
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let remainingSec = max(0, (nextAd - nowMs) / 1000)
            if remainingSec == 0 {
                countdownPill.text = " ⚡ Ad sẵn sàng "
                countdownPill.textColor = ToriumTheme.miningGreen
                countdownPill.backgroundColor = ToriumTheme.miningGreen.withAlphaComponent(0.15)
            } else {
                let mins = remainingSec / 60
                let secs = remainingSec % 60
                countdownPill.text = " ⏱ \(mins)m\(secs)s "
                countdownPill.textColor = ToriumTheme.toriumYellow
                countdownPill.backgroundColor = ToriumTheme.toriumYellow.withAlphaComponent(0.12)
            }
        } else {
            countdownPill.text = " ⏱ Sẵn sàng "
            countdownPill.textColor = ToriumTheme.textMuted
            countdownPill.backgroundColor = ToriumTheme.darkNavyBorder
        }
    }
}
