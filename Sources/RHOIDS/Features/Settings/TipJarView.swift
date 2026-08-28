import SwiftUI
import StoreKit

struct TipJarSection: View {
    var tipJarService: TipJarService

    var body: some View {
        Section {
            NavigationLink {
                TipJarView(tipService: tipJarService)
            } label: {
                Label("Support RHOIDS", systemImage: "heart.fill")
            }
        } footer: {
            Text("RHOIDS is free with no ads. Tips help keep it that way.")
        }
    }
}

struct TipJarView: View {
    @Bindable var tipService: TipJarService

    var body: some View {
        List {
            Section {
                Text("RHOIDS is built with care and offered completely free, no ads, no subscriptions. If you find it valuable, a tip goes a long way toward keeping development going.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if tipService.isLoadingProducts {
                Section {
                    HStack {
                        Spacer()
                        ProgressView("Loading options...")
                        Spacer()
                    }
                    .padding(.vertical, 20)
                }
            } else if tipService.products.isEmpty {
                Section {
                    if let error = tipService.errorMessage {
                        Label {
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Label {
                            Text("Tip options aren't available right now.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }

                    Button("Try Again") {
                        tipService.resetForRetry()
                        Task { await tipService.loadProducts() }
                    }
                }
            } else {
                Section {
                    ForEach(tipService.products, id: \.id) { product in
                        TipRow(
                            product: product,
                            emoji: emoji(for: product.id),
                            isBuying: tipService.purchasingProductID == product.id,
                            disabled: tipService.isPurchasing
                        ) {
                            Task { await tipService.purchase(product) }
                        }
                    }
                } header: {
                    Text("Choose a Tip")
                }

                if let error = tipService.errorMessage {
                    Section {
                        Label {
                            Text(error)
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .navigationTitle("Support RHOIDS")
        .task {
            await tipService.loadProducts()
        }
        .alert("Thank You!", isPresented: $tipService.showThankYou) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Your support means a lot and helps keep RHOIDS free for everyone.")
        }
    }

    private func emoji(for productID: String) -> String {
        switch productID {
        case "com.wesley.RHOIDS.tip.coffee": "☕️"
        case "com.wesley.RHOIDS.tip.lunch": "🍕"
        case "com.wesley.RHOIDS.tip.highfive": "🙌"
        case "com.wesley.RHOIDS.tip.generous": "💪"
        case "com.wesley.RHOIDS.tip.amazing": "🤩"
        default: "❤️"
        }
    }
}

private struct TipRow: View {
    let product: Product
    let emoji: String
    let isBuying: Bool
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(emoji)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(product.displayName)
                        .font(.body.weight(.medium))
                    Text(product.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if isBuying {
                    ProgressView()
                } else {
                    Text(product.displayPrice)
                        .font(.body.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(disabled)
        .buttonStyle(.plain)
    }
}
