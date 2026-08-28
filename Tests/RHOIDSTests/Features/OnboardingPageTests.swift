import Testing
import Foundation
@testable import RHOIDS

struct OnboardingPageTests {

    // MARK: - Page Collection Integrity

    @Test("Onboarding has exactly 4 pages")
    func pageCount() {
        #expect(OnboardingPage.all.count == 4,
                "Rule, bathroom-mode choice, notifications, and habit: one concise page each")
    }

    @Test("Page order is rule → focus mode → notifications → habit")
    func pageOrder() {
        let pages = OnboardingPage.all
        #expect(pages[0].id == OnboardingPage.theRule.id)
        #expect(pages[1].id == OnboardingPage.focusMode.id)
        #expect(pages[2].id == OnboardingPage.notifications.id)
        #expect(pages[3].id == OnboardingPage.makeItStick.id)
    }

    @Test("All pages have unique IDs")
    func uniquePageIDs() {
        let ids = OnboardingPage.all.map(\.id)
        #expect(Set(ids).count == ids.count,
                "Duplicate page IDs would break TabView selection")
    }

    @Test("Static page instances have stable identity across accesses")
    func staticIdentityStability() {
        let firstAccess = OnboardingPage.theRule.id
        let secondAccess = OnboardingPage.theRule.id
        #expect(firstAccess == secondAccess,
                "Static let should return the same instance each time")
    }

    // MARK: - Individual Page Content

    @Test("The Rule page has 3 features")
    func theRuleFeatureCount() {
        #expect(OnboardingPage.theRule.features.count == 3)
    }

    @Test("Notifications page has 2 features")
    func notificationsFeatureCount() {
        #expect(OnboardingPage.notifications.features.count == 2)
    }

    @Test("Make It Stick page has 3 features")
    func makeItStickFeatureCount() {
        #expect(OnboardingPage.makeItStick.features.count == 3)
    }

    @Test("Every page has a non-empty title and subtitle",
          arguments: OnboardingPage.all)
    func pagesHaveContent(page: OnboardingPage) {
        #expect(page.title.isEmpty == false, "Page title must not be empty")
        #expect(page.subtitle.isEmpty == false, "Page subtitle must not be empty")
        #expect(page.heroSymbol.isEmpty == false, "Page hero symbol must not be empty")
    }

    @Test("Every feature has non-empty title, description, and symbol",
          arguments: OnboardingPage.all.flatMap(\.features))
    func featuresHaveContent(feature: OnboardingFeature) {
        #expect(feature.title.isEmpty == false, "Feature title must not be empty")
        #expect(feature.description.isEmpty == false, "Feature description must not be empty")
        #expect(feature.symbol.isEmpty == false, "Feature symbol must not be empty")
    }

    @Test("All feature IDs are unique across all pages")
    func uniqueFeatureIDs() {
        let allFeatures = OnboardingPage.all.flatMap(\.features)
        let ids = allFeatures.map(\.id)
        #expect(Set(ids).count == ids.count,
                "Duplicate feature IDs would cause SwiftUI rendering issues")
    }

    // MARK: - Page Identity Matching (used by OnboardingView routing)

    @Test("Focus Mode page ID matches the static instance used for routing")
    func focusModePageRouting() {
        let pages = OnboardingPage.all
        let focusModePage = pages.first { $0.id == OnboardingPage.focusMode.id }
        #expect(focusModePage != nil,
                "OnboardingView routes by comparing page.id == OnboardingPage.focusMode.id")
    }

    @Test("Notifications page ID matches the static instance used for routing")
    func notificationsPageRouting() {
        let pages = OnboardingPage.all
        let notificationsPage = pages.first { $0.id == OnboardingPage.notifications.id }
        #expect(notificationsPage != nil,
                "OnboardingView routes by comparing page.id == OnboardingPage.notifications.id")
    }

    @Test("Make It Stick page ID matches the static instance used for routing")
    func makeItStickPageRouting() {
        let pages = OnboardingPage.all
        let habitPage = pages.first { $0.id == OnboardingPage.makeItStick.id }
        #expect(habitPage != nil,
                "OnboardingView routes by comparing page.id == OnboardingPage.makeItStick.id")
    }

    @Test("The Rule page does NOT match notifications or makeItStick IDs")
    func theRuleIsNotSpecialRouted() {
        let rulePage = OnboardingPage.theRule
        #expect(rulePage.id != OnboardingPage.notifications.id)
        #expect(rulePage.id != OnboardingPage.makeItStick.id)
    }

    // MARK: - Science Reference

    @Test("The Rule page mentions the Science page")
    func sciencePageReference() {
        let scienceFeature = OnboardingPage.theRule.features.first {
            $0.title.localizedCaseInsensitiveContains("science")
        }
        #expect(scienceFeature != nil,
                "Users should know the Science page exists for full research details")
    }

    // MARK: - RootView Key Stability

    @Test("Onboarded key has not changed")
    @MainActor
    func onboardedKeyStability() {
        #expect(RootView.onboardedKey == "hasOnboarded.v1",
                "Changing the onboarded key would force all existing users through onboarding again")
    }
}
