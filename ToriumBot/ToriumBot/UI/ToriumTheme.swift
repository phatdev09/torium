import UIKit

/// Centralized Obsidian Gold Design System constants and styling helpers for ToriumBot
public struct ToriumTheme {
    // MARK: - Obsidian Black & Graphite Foundations
    public static let obsidianBlack = UIColor(red: 8/255, green: 9/255, blue: 11/255, alpha: 1.0)       // #08090B
    public static let secondaryBackground = UIColor(red: 10/255, green: 11/255, blue: 13/255, alpha: 1.0) // #0A0B0D
    public static let graphiteCard = UIColor(red: 17/255, green: 19/255, blue: 22/255, alpha: 1.0)       // #111316
    public static let graphiteElevated = UIColor(red: 23/255, green: 26/255, blue: 31/255, alpha: 1.0)   // #171A1F
    public static let graphiteBorder = UIColor(red: 30/255, green: 35/255, blue: 43/255, alpha: 1.0)     // #1E232B

    // Aliases for seamless backward compatibility
    public static let background = obsidianBlack
    public static let cardBackground = graphiteCard
    public static let cardBorder = graphiteBorder
    public static let darkNavy = secondaryBackground
    public static let darkNavyCard = graphiteCard
    public static let darkNavyBorder = graphiteBorder

    // MARK: - Metallic Gold Accents
    public static let accentGold = UIColor(red: 201/255, green: 168/255, blue: 76/255, alpha: 1.0)     // #C9A84C
    public static let goldDark = UIColor(red: 166/255, green: 135/255, blue: 53/255, alpha: 1.0)
    public static let goldLight = UIColor(red: 223/255, green: 192/255, blue: 104/255, alpha: 1.0)
    public static let goldGlow = accentGold.withAlphaComponent(0.18)

    // MARK: - Neutral Typography Colors
    public static let textPrimary = UIColor(red: 248/255, green: 249/255, blue: 250/255, alpha: 1.0)
    public static let textSecondary = UIColor(red: 148/255, green: 163/255, blue: 184/255, alpha: 1.0) // #94A3B8
    public static let textMuted = UIColor(red: 100/255, green: 116/255, blue: 139/255, alpha: 1.0)     // #64748B

    // MARK: - Semantic Status Colors
    public static let statusGreen = UIColor(red: 0/255, green: 230/255, blue: 118/255, alpha: 1.0)     // #00E676
    public static let miningGreen = statusGreen
    public static let statusYellow = UIColor(red: 245/255, green: 158/255, blue: 11/255, alpha: 1.0)   // Amber #F59E0B
    public static let toriumYellow = statusYellow
    public static let statusRed = UIColor(red: 239/255, green: 68/255, blue: 68/255, alpha: 1.0)       // Red #EF4444
    public static let cyanHighlight = UIColor(red: 34/255, green: 211/255, blue: 238/255, alpha: 1.0)  // Cyan #22D3EE

    public static let border = cardBorder
    public static let success = statusGreen
    public static let danger = statusRed
    public static let warning = statusYellow
    public static let accent = accentGold
    public static let error = statusRed

    // MARK: - Radius Scale
    public static let radiusSmall: CGFloat = 6.0
    public static let radiusControl: CGFloat = 8.0
    public static let radiusInput: CGFloat = 10.0
    public static let radiusCard: CGFloat = 14.0
    public static let radiusHero: CGFloat = 18.0
    public static let radiusCapsule: CGFloat = 26.0
    public static let cornerRadius: CGFloat = radiusCard

    // MARK: - Visual Helpers
    public static func applyCardStyle(to view: UIView, radius: CGFloat = radiusCard, hasGoldAccent: Bool = false) {
        view.backgroundColor = graphiteCard
        view.layer.cornerRadius = radius
        view.layer.borderWidth = 1.0
        view.layer.borderColor = hasGoldAccent ? accentGold.withAlphaComponent(0.35).cgColor : graphiteBorder.cgColor
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8.0
        view.layer.shadowOpacity = 0.45
        view.clipsToBounds = false
    }

    public static func applyInputStyle(to textField: UITextField) {
        textField.backgroundColor = graphiteElevated
        textField.textColor = textPrimary
        textField.tintColor = accentGold
        textField.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        textField.layer.cornerRadius = radiusInput
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = graphiteBorder.cgColor
        let paddingView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 38))
        textField.leftView = paddingView
        textField.leftViewMode = .always
    }

    public static func styleSegmentedControl(_ control: UISegmentedControl) {
        control.backgroundColor = graphiteElevated
        control.selectedSegmentTintColor = accentGold
        control.setTitleTextAttributes([
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 12, weight: .bold)
        ], for: .selected)
        control.setTitleTextAttributes([
            .foregroundColor: textSecondary,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ], for: .normal)
        control.layer.cornerRadius = radiusControl
        control.layer.borderWidth = 1.0
        control.layer.borderColor = graphiteBorder.cgColor
    }

    public static func createPrimaryButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .heavy)
        button.setTitleColor(UIColor.black, for: .normal)
        button.backgroundColor = accentGold
        button.layer.cornerRadius = radiusInput
        button.layer.shadowColor = accentGold.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 6.0
        button.layer.shadowOpacity = 0.30
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return button
    }

    public static func createSecondaryButton(title: String, titleColor: UIColor = accentGold) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        button.setTitleColor(titleColor, for: .normal)
        button.backgroundColor = titleColor.withAlphaComponent(0.12)
        button.layer.cornerRadius = radiusInput
        button.layer.borderWidth = 1.0
        button.layer.borderColor = titleColor.withAlphaComponent(0.35).cgColor
        button.heightAnchor.constraint(equalToConstant: 40).isActive = true
        return button
    }
}

// MARK: - Official Brand Assets

extension UIImage {
    /// The official golden Torium cybernetic logo (P-symbol)
    public static var toriumLogo: UIImage? {
        if let img = UIImage(named: "app_logo") { return img }
        if let img = UIImage(named: "AppIcon60x60@2x") { return img }
        if let path = Bundle.main.path(forResource: "app_logo", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        if let path = Bundle.main.path(forResource: "app_logo_small", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        if let path = Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        if let path = Bundle.main.path(forResource: "icon", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            return img
        }
        return UIImage(systemName: "bolt.shield.fill")
    }
}
