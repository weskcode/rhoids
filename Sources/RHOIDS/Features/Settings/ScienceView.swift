import SwiftUI

/// The Science hub: the 3 and 5 minute marks up top, then one row per topic. Each row opens a
/// reading page in `ScienceTopicPages.swift` that holds the full text and its sources.
struct ScienceView: View {
    var body: some View {
        List {
            Section {
                ScienceHero()
            }

            Section {
                NavigationLink {
                    FiveMinuteRulePage()
                } label: {
                    ScienceTopicRow(
                        title: "The 5-minute rule",
                        subtitle: "Several doctors from different institutions arrived at five minutes as the maximum.",
                        systemImage: "timer"
                    )
                }

                NavigationLink {
                    ToiletSeatPage()
                } label: {
                    ScienceTopicRow(
                        title: "Why the toilet seat is different",
                        subtitle: "A toilet isn't shaped like a chair.",
                        systemImage: "toilet"
                    )
                }

                NavigationLink {
                    PhonePage()
                } label: {
                    ScienceTopicRow(
                        title: "Your phone is the problem",
                        subtitle: "Phone use on the toilet is linked to a 46% higher risk of hemorrhoids.",
                        systemImage: "iphone"
                    )
                }

                NavigationLink {
                    TimerValuesPage()
                } label: {
                    ScienceTopicRow(
                        title: "Timer values",
                        subtitle: "How 3 and 5 minutes were chosen.",
                        systemImage: "slider.horizontal.3",
                        tint: .gray
                    )
                }

                NavigationLink {
                    ReferencesPage()
                } label: {
                    ScienceTopicRow(
                        title: "References",
                        subtitle: "The published research behind these numbers.",
                        systemImage: "text.book.closed",
                        tint: .gray
                    )
                }
            } footer: {
                Text("Not medical advice. If you have bleeding, pain, or symptoms that do not go away, talk with a qualified healthcare professional.")
            }
        }
        .navigationTitle("The Science")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The intro line, the two timer marks and a gauge that shows where 3 sits on the way to 5.
private struct ScienceHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text("Every timer in this app is based on published medical research. Here's what the doctors say and why it matters.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                marks {
                    MinuteMark(minutes: ScienceContent.recommendedMinutes, label: "Recommended")
                    MinuteMark(minutes: ScienceContent.maxMinutes, label: "Max")
                }

                Gauge(value: ScienceContent.recommendedFraction) {
                    EmptyView()
                }
                .gaugeStyle(.linearCapacity)
                .tint(.brand)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Recommended: \(ScienceContent.recommendedMinutes) min. Max: \(ScienceContent.maxMinutes) min."))
        }
        .padding(.vertical, AppSpacing.xs)
    }

    /// Side by side at normal sizes; stacked at accessibility sizes so neither mark gets squeezed.
    private var marksLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.md))
            : AnyLayout(HStackLayout(alignment: .top, spacing: AppSpacing.xxxl))
    }

    private func marks<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        marksLayout { content() }
    }
}

private struct MinuteMark: View {
    let minutes: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("\(minutes) min")
                .font(.title.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

/// A hub row: symbol tile, title, a one-line takeaway and the disclosure chevron the
/// enclosing `NavigationLink` draws.
private struct ScienceTopicRow: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    let systemImage: String
    var tint: Color = .brand

    @ScaledMetric(relativeTo: .body) private var tileSize: CGFloat = 29
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At accessibility sizes the tile moves above the text so the words get the full row
        // width instead of wrapping one or two to a line.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout(spacing: AppSpacing.md))

        layout {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: tileSize, height: tileSize)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, AppSpacing.xxs)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ScienceView()
    }
}

#Preview("Largest text") {
    NavigationStack {
        ScienceView()
    }
    .dynamicTypeSize(.accessibility5)
}
#endif
