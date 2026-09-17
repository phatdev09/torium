import UIKit

/// Centralized UI Design System constants and styling helpers for ToriumBot
public struct ToriumTheme {
    // Colors
    public static let background = UIColor(red: 10/255, green: 10/255, blue: 10/255, alpha: 1.0) // #0A0A0A
    public static let cardBackground = UIColor(red: 22/255, green: 22/255, blue: 24/255, alpha: 1.0) // #161618
    public static let cardBorder = UIColor(red: 38/255, green: 38/255, blue: 42/255, alpha: 1.0)
    public static let accentGold = UIColor(red: 201/255, green: 168/255, blue: 76/255, alpha: 1.0) // #C9A84C
    public static let textPrimary = UIColor(white: 0.95, alpha: 1.0)
    public static let textSecondary = UIColor(white: 0.60, alpha: 1.0)
    public static let textMuted = UIColor(white: 0.40, alpha: 1.0)

    // Official Torium App Colors (Matching Screenshots)
    public static let miningGreen = UIColor(red: 0/255, green: 230/255, blue: 118/255, alpha: 1.0) // #00E676
    public static let toriumYellow = UIColor(red: 255/255, green: 179/255, blue: 0/255, alpha: 1.0) // #FFB300
    public static let darkNavy = UIColor(red: 9/255, green: 13/255, blue: 22/255, alpha: 1.0) // #090D16
    public static let darkNavyCard = UIColor(red: 19/255, green: 27/255, blue: 42/255, alpha: 1.0) // #131B2A
    public static let darkNavyBorder = UIColor(red: 31/255, green: 45/255, blue: 68/255, alpha: 1.0) // #1F2D44
    public static let cyanHighlight = UIColor(red: 34/255, green: 211/255, blue: 238/255, alpha: 1.0) // #22D3EE for Hardware Scanner

    // Status Colors
    public static let statusGreen = UIColor(red: 46/255, green: 189/255, blue: 89/255, alpha: 1.0)
    public static let statusRed = UIColor(red: 235/255, green: 77/255, blue: 75/255, alpha: 1.0)
    public static let statusYellow = UIColor(red: 240/255, green: 178/255, blue: 50/255, alpha: 1.0)

    // Aliases
    public static let border = cardBorder
    public static let success = statusGreen
    public static let danger = statusRed
    public static let warning = statusYellow
    public static let accent = accentGold
    public static let error = statusRed

    // Corner Radius & Elevations
    public static let cornerRadius: CGFloat = 12.0

    public static func applyCardStyle(to view: UIView) {
        view.backgroundColor = cardBackground
        view.layer.cornerRadius = cornerRadius
        view.layer.borderWidth = 1.0
        view.layer.borderColor = cardBorder.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 2)
        view.layer.shadowRadius = 4.0
        view.layer.shadowOpacity = 0.35
        view.clipsToBounds = false
    }

    public static func createPrimaryButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(UIColor.black, for: .normal)
        button.backgroundColor = accentGold
        button.layer.cornerRadius = cornerRadius
        button.heightAnchor.constraint(equalToConstant: 48).isActive = true
        return button
    }
}
