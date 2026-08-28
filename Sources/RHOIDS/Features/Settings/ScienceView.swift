import SwiftUI

struct ScienceView: View {
    var body: some View {
        List {
            Section {
                Text("Every timer in this app is based on published medical research. Here's what the doctors say and why it matters.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("The 5-minute rule") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("About 1 in 4 adults have hemorrhoids at any given time. A 2025 meta-analysis in the Annals of Medicine looked at 150 studies covering nearly 9 million people and landed on a global prevalence of 26%. The single most preventable cause? Sitting on the toilet too long.")

                    Text("Multiple doctors from different institutions independently arrived at the same number. Cleveland Clinic colorectal surgeon Dr. Michael Valente: \"Five minutes really should be the maximum.\" Harvard gastroenterologist Dr. Trisha Pasricha: \"If the magic is not happening within five minutes, it's not going to happen.\"")

                    Text("RHOIDS sets the Recommended timer at 3 minutes (a comfortable buffer) and the Max at 5 (the clinical ceiling).")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
            }

            Section("Why the toilet seat is different") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A toilet isn't shaped like a chair. The open cutout lets gravity pull blood down into the rectal veins, and without normal pelvic floor support, pressure builds fast. Sit there long enough and those veins swell. That's a hemorrhoid.")

                    Text("Hunching forward over a phone makes it worse. Dr. Kalakota at Houston Methodist explains that the posture changes the angle where the rectum meets the anus, increasing pressure on the blood vessels even further.")
                }
                .font(.subheadline)
            }

            Section("Your phone is the problem") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A 2025 study from Harvard Medical School (Ramprasad et al., published in PLOS One) surveyed patients getting screening colonoscopies and found that using your phone on the toilet is linked to a 46% higher risk of hemorrhoids.")

                    HStack(alignment: .top, spacing: 12) {
                        StatBlock(value: "37%", caption: "of phone users exceeded 5 min per visit")
                        StatBlock(value: "7%", caption: "of non-phone users exceeded 5 min")
                    }
                    .padding(.vertical, 4)

                    Text("The researchers controlled for straining, fiber intake, and exercise. Phone use, not straining, was the independent predictor. The most common activities? Reading news and scrolling social media.")
                }
                .font(.subheadline)
            }

            Section("Timer values") {
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
            }

            Section("References") {
                Link(destination: URL(string: "https://doi.org/10.1371/journal.pone.0329983")!) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smartphone use on the toilet and the risk of hemorrhoids")
                            .font(.subheadline)
                        Text("Ramprasad et al., PLOS One, 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://doi.org/10.1080/07853890.2025.2606433")!) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Worldwide prevalence of haemorrhoids")
                            .font(.subheadline)
                        Text("Esmaeilnia Shirvani et al., Annals of Medicine, 2025")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Link(destination: URL(string: "https://doi.org/10.3748/wjg.v18.i17.2009")!) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hemorrhoids: from basic pathophysiology to clinical management")
                            .font(.subheadline)
                        Text("Lohsiriwat, World J. Gastroenterology, 2012")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("The Science")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct StatBlock: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.weight(.bold))
                .foregroundStyle(Color.accentColor)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        ScienceView()
    }
}
#endif
