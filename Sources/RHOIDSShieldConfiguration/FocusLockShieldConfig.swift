import ManagedSettings
import ManagedSettingsUI
import UIKit

class FocusLockShieldConfig: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfig()
    }

    override func configuration(shielding application: Application,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfig()
    }

    override func configuration(shielding webDomain: WebDomain,
                                in category: ActivityCategory) -> ShieldConfiguration {
        makeConfig()
    }

    private func makeConfig() -> ShieldConfiguration {
        let brandGreen = UIColor(red: 0.196, green: 0.808, blue: 0.416, alpha: 1)

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThickMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.85),
            icon: nil,
            title: ShieldConfiguration.Label(
                text: String(localized: "Cooldown in Progress"),
                color: brandGreen
            ),
            subtitle: ShieldConfiguration.Label(
                text: String(localized: "Your timer is finished. These apps will unlock automatically when your cooldown ends."),
                color: .white
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: primaryButtonTitle,
                color: .white
            ),
            primaryButtonBackgroundColor: brandGreen,
            secondaryButtonLabel: secondaryButtonLabel
        )
    }

    private var primaryButtonTitle: String {
        if #available(iOS 26.5, *) {
            return String(localized: "Open RHOIDS")
        }
        return String(localized: "Close App")
    }

    private var secondaryButtonLabel: ShieldConfiguration.Label? {
        guard #available(iOS 26.5, *) else { return nil }
        return ShieldConfiguration.Label(
            text: String(localized: "Close App"),
            color: .systemGray
        )
    }
}
