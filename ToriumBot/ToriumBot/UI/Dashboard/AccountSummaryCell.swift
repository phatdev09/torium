import UIKit

/// Custom TableView cell displaying account status, balance, and next ad countdown on Dashboard
public final class AccountSummaryCell: UITableViewCell {
    public static let reuseIdentifier = "AccountSummaryCell"

    private let cardContainer = UIView()
    private let emailLabel = UILabel()
    private let statusBadge = UILabel()
    private let balanceLabel = UILabel()
    private let adsCountLabel = UILabel()
    private let countdownLabel = UILabel()

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

        ToriumTheme.applyCardStyle(to: cardContainer)
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cardContainer)

        emailLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        emailLabel.textColor = ToriumTheme.textPrimary
        emailLabel.translatesAutoresizingMaskIntoConstraints = false

        statusBadge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        statusBadge.layer.cornerRadius = 4
        statusBadge.clipsToBounds = true
        statusBadge.textAlignment = .center
        statusBadge.translatesAutoresizingMaskIntoConstraints = false

        balanceLabel.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        balanceLabel.textColor = ToriumTheme.accentGold
        balanceLabel.translatesAutoresizingMaskIntoConstraints = false

        adsCountLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        adsCountLabel.textColor = ToriumTheme.textSecondary
        adsCountLabel.translatesAutoresizingMaskIntoConstraints = false

        countdownLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        countdownLabel.textColor = ToriumTheme.textMuted
        countdownLabel.textAlignment = .right
        countdownLabel.translatesAutoresizingMaskIntoConstraints = false

        cardContainer.addSubview(emailLabel)
        cardContainer.addSubview(statusBadge)
        cardContainer.addSubview(balanceLabel)
        cardContainer.addSubview(adsCountLabel)
        cardContainer.addSubview(countdownLabel)

        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            emailLabel.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 12),
            emailLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 14),
            emailLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusBadge.leadingAnchor, constant: -8),

            statusBadge.centerYAnchor.constraint(equalTo: emailLabel.centerYAnchor),
            statusBadge.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            statusBadge.heightAnchor.constraint(equalToConstant: 20),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),

            balanceLabel.topAnchor.constraint(equalTo: emailLabel.bottomAnchor, constant: 8),
            balanceLabel.leadingAnchor.constraint(equalTo: emailLabel.leadingAnchor),

            adsCountLabel.centerYAnchor.constraint(equalTo: balanceLabel.centerYAnchor),
            adsCountLabel.leadingAnchor.constraint(equalTo: balanceLabel.trailingAnchor, constant: 14),

            countdownLabel.centerYAnchor.constraint(equalTo: balanceLabel.centerYAnchor),
            countdownLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -14),
            countdownLabel.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -12)
        ])
    }

    public func configure(with account: Account, stats: MiningStats?) {
        // Email truncate
        if account.email.count > 24 {
            let prefix = account.email.prefix(12)
            let suffix = account.email.suffix(8)
            emailLabel.text = "\(prefix)...\(suffix)"
        } else {
            emailLabel.text = account.email
        }

        // Status badge
        if account.isBanned {
            statusBadge.text = " BANNED "
            statusBadge.backgroundColor = ToriumTheme.statusRed.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.statusRed
        } else if !account.isActive {
            statusBadge.text = " PAUSED "
            statusBadge.backgroundColor = UIColor.darkGray.withAlphaComponent(0.4)
            statusBadge.textColor = UIColor.lightGray
        } else {
            statusBadge.text = " ACTIVE "
            statusBadge.backgroundColor = ToriumTheme.statusGreen.withAlphaComponent(0.2)
            statusBadge.textColor = ToriumTheme.statusGreen
        }

        // Balance & Ads
        let balance = stats?.torBalance ?? 0.0
        balanceLabel.text = "💰 \(String(format: "%.3f", balance)) TOR"

        let ads = stats?.adsWatched ?? 0
        adsCountLabel.text = "📺 Ad \(ads)/120"

        // Next ad countdown
        if let nextAd = stats?.nextAdAt {
            let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
            let remainingSec = max(0, (nextAd - nowMs) / 1000)
            if remainingSec == 0 {
                countdownLabel.text = "Sẵn sàng"
                countdownLabel.textColor = ToriumTheme.statusGreen
            } else {
                let mins = remainingSec / 60
                let secs = remainingSec % 60
                countdownLabel.text = "Ad tiếp: \(mins)m\(secs)s"
                countdownLabel.textColor = ToriumTheme.textMuted
            }
        } else {
            countdownLabel.text = "Chưa lên lịch"
            countdownLabel.textColor = ToriumTheme.textMuted
        }
    }
}
