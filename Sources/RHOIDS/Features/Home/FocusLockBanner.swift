import SwiftUI

struct FocusLockBanner: View {
    let onUnlock: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.title3)
                .foregroundStyle(.brand)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Lock Active")
                    .font(.subheadline.weight(.semibold))
                Text("Distracting apps are blocked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Unlock", action: onUnlock)
                .font(.subheadline.weight(.medium))
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}
