import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("RHOIDS is a focused, single purpose app that helps you avoid sitting on the toilet too long, a primary behavioral cause of hemorrhoids.")

                Text("It is not a wellness tracker. It is not social. It does not collect data. It just does one thing extremely well: it gets you off the toilet.")

                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1.0")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .scenePadding(.horizontal)
            .padding(.vertical)
        }
        .navigationTitle("About RHOIDS")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        AboutView()
    }
}
#endif
