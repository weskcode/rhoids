import Testing
import Foundation
@testable import RHOIDS

struct ScienceContentTests {
    @Test func `Hero marks equal the real preset durations in minutes`() {
        #expect(ScienceContent.recommendedMinutes == Int(PresetTimer.recommended.duration / 60))
        #expect(ScienceContent.maxMinutes == Int(PresetTimer.maxAllowed.duration / 60))
        #expect(ScienceContent.recommendedMinutes == 3)
        #expect(ScienceContent.maxMinutes == 5)
    }

    @Test func `Recommended mark sits strictly inside the gauge`() {
        let fraction = ScienceContent.recommendedFraction
        #expect(fraction > 0)
        #expect(fraction < 1)
        #expect(fraction == 0.6)
    }

    @Test func `Phone-use shares are valid gauge values and phone users are the larger share`() {
        let phone = ScienceContent.phoneUsersOverFiveMinutes
        let nonPhone = ScienceContent.nonPhoneUsersOverFiveMinutes
        #expect(phone == 0.37, "Ramprasad et al., PLOS One, 2025: 37% of phone users exceeded 5 min")
        #expect(nonPhone == 0.07, "Ramprasad et al., PLOS One, 2025: 7% of non-phone users exceeded 5 min")
        #expect((0...1).contains(phone))
        #expect((0...1).contains(nonPhone))
        #expect(phone > nonPhone)
    }

    @Test func `All three references survive URL validation`() {
        #expect(ScienceContent.references.count == 3,
                "A reference whose URL fails to parse is dropped, so a typo shrinks this count")
    }

    @Test func `Every reference links to a DOI over https with a unique id`() {
        for reference in ScienceContent.references {
            #expect(reference.url.scheme == "https")
            #expect(reference.url.host == "doi.org")
        }
        let ids = ScienceContent.references.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func `Reference initializer rejects a non-https or malformed URL`() {
        #expect(ScienceContent.Reference(id: "a", title: "T", citation: "C", urlString: "http://doi.org/10.1/x") == nil)
        #expect(ScienceContent.Reference(id: "b", title: "T", citation: "C", urlString: "not a url") == nil)
        #expect(ScienceContent.Reference(id: "c", title: "T", citation: "C", urlString: "https://doi.org/10.1/x") != nil)
    }
}
