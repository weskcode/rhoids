import Foundation

/// App Store and support-contact constants used by user-initiated support actions.
enum AppStoreInfo {
    /// Numeric App Store ID from App Store Connect (the digits after `id`).
    static let appID = "6772689484"

    /// Destination for the in-app feedback form.
    static let supportEmail = "wesleyk@duck.com"

    static var writeReviewURL: URL? {
        guard !appID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appID)?action=write-review")
    }

    static var productURL: URL? {
        guard !appID.isEmpty else { return nil }
        return URL(string: "https://apps.apple.com/app/id\(appID)")
    }
}
