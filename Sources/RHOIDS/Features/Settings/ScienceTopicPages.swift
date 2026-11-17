import SwiftUI

// One reading page per Science topic. The text here is the research the app is built on, so
// every paragraph, quote and citation from the old single page lives on one of these pages.

struct FiveMinuteRulePage: View {
    var body: some View {
        List {
            Section {
                ScienceProse {
                    Text("About 1 in 4 adults have hemorrhoids at any given time. A 2025 meta-analysis in the Annals of Medicine looked at 150 studies covering nearly 9 million people and landed on a global prevalence of 26%. The single most preventable cause? Sitting on the toilet too long.")

                    Text("Multiple doctors from different institutions independently arrived at the same number.")

                    ScienceQuote(
                        quote: "Five minutes really should be the maximum.",
                        attribution: "Dr. Michael Valente, colorectal surgeon, Cleveland Clinic"
                    )

                    ScienceQuote(
                        quote: "If the magic is not happening within five minutes, it's not going to happen.",
                        attribution: "Dr. Trisha Pasricha, gastroenterologist, Harvard"
                    )

                    Text("RHOIDS sets the Recommended timer at 3 minutes (a comfortable buffer) and the Max at 5 (the clinical ceiling).")
                        .fontWeight(.medium)
                }
            } header: {
                Text("The 5-minute rule")
            }
        }
        .navigationTitle("The 5-minute rule")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ToiletSeatPage: View {
    var body: some View {
        List {
            Section {
                ScienceProse {
                    Text("A toilet isn't shaped like a chair. The open cutout lets gravity pull blood down into the rectal veins, and without normal pelvic floor support, pressure builds fast. Sit there long enough and those veins swell. That's a hemorrhoid.")

                    Text("Hunching forward over a phone makes it worse. Dr. Kalakota at Houston Methodist explains that the posture changes the angle where the rectum meets the anus, increasing pressure on the blood vessels even further.")
                }
            } header: {
                Text("Why the toilet seat is different")
            }
        }
        .navigationTitle("Why the toilet seat is different")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PhonePage: View {
    var body: some View {
        List {
            Section {
                ScienceProse {
                    Text("A 2025 study from Harvard Medical School (Ramprasad et al., published in PLOS One) surveyed patients getting screening colonoscopies and found that using your phone on the toilet is linked to a 46% higher risk of hemorrhoids.")

                    ScienceGaugeRow(
                        fraction: ScienceContent.phoneUsersOverFiveMinutes,
                        caption: "of phone users exceeded 5 min per visit",
                        tint: .brand
                    )

                    ScienceGaugeRow(
                        fraction: ScienceContent.nonPhoneUsersOverFiveMinutes,
                        caption: "of non-phone users exceeded 5 min",
                        tint: .secondary
                    )

                    Text("The researchers controlled for straining, fiber intake, and exercise. Phone use, not straining, was the independent predictor. The most common activities? Reading news and scrolling social media.")
                }
            } header: {
                Text("Your phone is the problem")
            }
        }
        .navigationTitle("Your phone is the problem")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TimerValuesPage: View {
    var body: some View {
        List {
            Section {
                LabeledContent("Recommended (3 min)") {
                    Text("Safe buffer below the clinical ceiling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Max (5 min)") {
                    Text("Consensus limit from Cleveland Clinic and Harvard")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                LabeledContent("Custom") {
                    Text("Your call, but the science is clear past 5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Timer values")
            }
        }
        .navigationTitle("Timer values")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReferencesPage: View {
    var body: some View {
        List {
            Section {
                ForEach(ScienceContent.references) { reference in
                    // A `Link` tints all of its text, which turns the citation line into a pale
                    // green that is hard to read. Explicit label colors keep the text legible
                    // and the arrow carries the link affordance.
                    Link(destination: reference.url) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                                Text(reference.title)
                                    .font(.subheadline)
                                    .foregroundStyle(Color(.label))
                                Text(reference.citation)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "arrow.up.right.square")
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .accessibilityHidden(true)
                        }
                    }
                }
            } header: {
                Text("References")
            }
        }
        .navigationTitle("References")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Building blocks

/// A column of paragraphs in one grouped row, in the subheadline size the old page used.
private struct ScienceProse<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            content
        }
        .font(.subheadline)
    }
}

/// A doctor's words with a brand rule down the left edge and the speaker underneath.
private struct ScienceQuote: View {
    let quote: LocalizedStringResource
    let attribution: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(verbatim: quotationMarks.open + String(localized: quote) + quotationMarks.close)
                .font(.headline)
            Text(attribution)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.leading, AppSpacing.lg)
        .overlay(alignment: .leading) {
            Capsule()
                .fill(Color.brand)
                .frame(width: 4)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    /// The old paragraph put the doctors' words in quotation marks. The marks follow the
    /// language the app shows, so French gets « » and German gets „ “.
    private var quotationMarks: (open: String, close: String) {
        let locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "en")
        return (locale.quotationBeginDelimiter ?? "\u{201C}", locale.quotationEndDelimiter ?? "\u{201D}")
    }
}

/// A percentage as a large figure, its caption, and a bar that shows the share.
private struct ScienceGaugeRow: View {
    let fraction: Double
    let caption: LocalizedStringKey
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(fraction, format: .percent)
                .font(.title.weight(.bold))
                .monospacedDigit()
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            Gauge(value: fraction) {
                EmptyView()
            }
            .gaugeStyle(.linearCapacity)
            .tint(tint)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview("5-minute rule") {
    NavigationStack { FiveMinuteRulePage() }
}

#Preview("Phone") {
    NavigationStack { PhonePage() }
        .dynamicTypeSize(.accessibility3)
}
#endif
