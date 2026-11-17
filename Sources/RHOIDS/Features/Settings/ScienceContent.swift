import Foundation

/// The numbers and links the Science screens show, kept apart from the views so tests can
/// check them. The 3 and 5 minute marks come from the real presets, so the page cannot drift
/// from the timers.
enum ScienceContent {
    /// The Recommended timer, in whole minutes.
    static let recommendedMinutes = Int(PresetTimer.recommended.duration / 60)

    /// The Max timer, in whole minutes.
    static let maxMinutes = Int(PresetTimer.maxAllowed.duration / 60)

    /// How far along the hero gauge the Recommended mark sits (0 to 1).
    static var recommendedFraction: Double {
        Double(recommendedMinutes) / Double(maxMinutes)
    }

    /// Ramprasad et al., PLOS One, 2025: share of each group that stayed longer than 5 minutes.
    static let phoneUsersOverFiveMinutes = 0.37
    static let nonPhoneUsersOverFiveMinutes = 0.07

    struct Reference: Identifiable {
        let id: String
        let title: LocalizedStringResource
        let citation: LocalizedStringResource
        let url: URL

        init?(id: String, title: LocalizedStringResource, citation: LocalizedStringResource, urlString: String) {
            guard let url = URL(string: urlString), url.scheme == "https" else { return nil }
            self.id = id
            self.title = title
            self.citation = citation
            self.url = url
        }
    }

    static let references: [Reference] = [
        Reference(
            id: "ramprasad-2025",
            title: "Smartphone use on the toilet and the risk of hemorrhoids",
            citation: "Ramprasad et al., PLOS One, 2025",
            urlString: "https://doi.org/10.1371/journal.pone.0329983"
        ),
        Reference(
            id: "esmaeilnia-shirvani-2025",
            title: "Worldwide prevalence of haemorrhoids",
            citation: "Esmaeilnia Shirvani et al., Annals of Medicine, 2025",
            urlString: "https://doi.org/10.1080/07853890.2025.2606433"
        ),
        Reference(
            id: "lohsiriwat-2012",
            title: "Hemorrhoids: from basic pathophysiology to clinical management",
            citation: "Lohsiriwat, World J. Gastroenterology, 2012",
            urlString: "https://doi.org/10.3748/wjg.v18.i17.2009"
        ),
    ].compactMap { $0 }
}
