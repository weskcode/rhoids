import StoreKit
import Foundation

@MainActor
@Observable
final class TipJarService {
    private(set) var products: [Product] = []
    private(set) var isPurchasing = false
    private(set) var isLoadingProducts = false
    private(set) var purchasingProductID: String?
    var showThankYou = false
    var errorMessage: String?

    // nonisolated(unsafe) so deinit can cancel without actor isolation.
    // Safe because Task.cancel() is thread-safe and we only write from @MainActor methods.
    @ObservationIgnored
    nonisolated(unsafe) private var transactionListener: Task<Void, Never>?

    nonisolated static let productIDs: [String] = [
        "com.wesley.RHOIDS.tip.coffee",
        "com.wesley.RHOIDS.tip.lunch",
        "com.wesley.RHOIDS.tip.highfive",
        "com.wesley.RHOIDS.tip.generous",
        "com.wesley.RHOIDS.tip.amazing"
    ]

    /// Starts the transaction listener at init so unfinished transactions
    /// (e.g., Ask to Buy approvals, interrupted purchases) are caught
    /// immediately at launch - not only when the Tip Jar view appears.
    init() {
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                guard self != nil else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }

    /// Retained for backward compatibility; safe to call more than once
    /// since the listener is already started in `init()`.
    func listenForTransactions() {
        // No-op - listener started at init.
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.price < $1.price }
            errorMessage = nil

            if products.isEmpty {
                errorMessage = "No tip options are available right now."
            }
        } catch {
            errorMessage = "Unable to load tip options. Check your connection and try again."
        }
    }

    /// Clears cached state so the next `loadProducts()` call fetches fresh data.
    func resetForRetry() {
        products = []
        errorMessage = nil
    }

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchasingProductID = product.id
        errorMessage = nil
        defer {
            isPurchasing = false
            purchasingProductID = nil
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                showThankYou = true
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch is TipJarError {
            errorMessage = "Purchase could not be verified. You were not charged."
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw TipJarError.verificationFailed
        case .verified(let value):
            return value
        }
    }

    deinit {
        transactionListener?.cancel()
    }
}

/// Internal error type for distinguishing verification failures from network errors.
enum TipJarError: Error {
    case verificationFailed
}
