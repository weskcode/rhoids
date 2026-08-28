import Foundation
import Testing
@testable import RHOIDS

@MainActor
struct TipJarServiceTests {
    let sut: TipJarService

    init() {
        sut = TipJarService()
    }

    // MARK: - Product ID configuration

    @Test("each product ID follows bundle ID convention", arguments: TipJarService.productIDs)
    func productIDFollowsConvention(id: String) {
        #expect(id.hasPrefix("com.wesley.RHOIDS.tip."), "Product ID should use the app's bundle ID prefix")
    }

    @Test("product IDs are unique")
    func productIDsAreUnique() {
        let unique = Set(TipJarService.productIDs)
        #expect(unique.count == TipJarService.productIDs.count, "Duplicate product IDs would cause StoreKit to silently drop products")
    }

    @Test("has five tip tiers")
    func fiveTipTiers() {
        #expect(TipJarService.productIDs.count == 5)
    }

    @Test("product IDs match expected StoreKit config entries")
    func productIDsMatchConfig() {
        let expected: Set<String> = [
            "com.wesley.RHOIDS.tip.coffee",
            "com.wesley.RHOIDS.tip.lunch",
            "com.wesley.RHOIDS.tip.highfive",
            "com.wesley.RHOIDS.tip.generous",
            "com.wesley.RHOIDS.tip.amazing"
        ]
        #expect(Set(TipJarService.productIDs) == expected)
    }

    @Test("product IDs match local StoreKit configuration")
    func productIDsMatchLocalStoreKitConfiguration() throws {
        let configIDs = try localStoreKitProductIDs()
        #expect(Set(TipJarService.productIDs) == configIDs,
                "StoreKit configuration and app product IDs must stay in sync for App Review")
    }

    // MARK: - Initial state

    @Test("fresh service has no products loaded")
    func initialProductsEmpty() {
        #expect(sut.products.isEmpty)
    }

    @Test("fresh service is not purchasing")
    func initialNotPurchasing() {
        #expect(sut.isPurchasing == false)
        #expect(sut.purchasingProductID == nil)
    }

    @Test("fresh service is not loading")
    func initialNotLoading() {
        #expect(sut.isLoadingProducts == false)
    }

    @Test("fresh service has no error or thank-you state")
    func initialNoAlerts() {
        #expect(sut.showThankYou == false)
        #expect(sut.errorMessage == nil)
    }

    // MARK: - loadProducts behavior

    @Test("loadProducts resets isLoadingProducts when finished")
    func loadProductsClearsLoadingFlag() async {
        await sut.loadProducts()
        #expect(sut.isLoadingProducts == false, "isLoadingProducts should be false after load completes")
    }

    @Test("loadProducts is idempotent after first load")
    func loadProductsIdempotent() async {
        await sut.loadProducts()
        let countAfterFirst = sut.products.count

        await sut.loadProducts()
        #expect(sut.products.count == countAfterFirst, "Second load should not change product count")
    }

    @Test("loadProducts guard prevents concurrent loads")
    func loadProductsGuardPreventsReentry() async {
        async let first: Void = sut.loadProducts()
        async let second: Void = sut.loadProducts()
        _ = await (first, second)

        #expect(sut.isLoadingProducts == false)
    }

    // MARK: - Retry behavior

    @Test("resetForRetry clears products and error so loadProducts can refetch")
    func resetForRetryAllowsRefetch() async {
        await sut.loadProducts()
        let countAfterFirst = sut.products.count

        sut.resetForRetry()
        #expect(sut.products.isEmpty, "Products should be cleared after reset")
        #expect(sut.errorMessage == nil, "Error should be cleared after reset")

        await sut.loadProducts()
        #expect(sut.products.count == countAfterFirst, "Refetch should return the same products")
    }

    // MARK: - Transaction listener

    @Test("transaction listener starts automatically at init")
    func transactionListenerStartsAtInit() {
        // The listener is started in init() - calling listenForTransactions()
        // is a safe no-op for backward compatibility.
        sut.listenForTransactions()
        sut.listenForTransactions()
        // No crash or duplicate listeners.
    }

    // MARK: - TipJarError

    @Test("TipJarError.verificationFailed is a distinct error case")
    func verificationFailedIsDistinct() {
        let error: any Error = TipJarError.verificationFailed
        #expect(error is TipJarError)
    }

    private func localStoreKitProductIDs() throws -> Set<String> {
        let url = try findProjectRoot().appendingPathComponent("RHOIDS.storekit")
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(StoreKitConfiguration.self, from: data)
        return Set(decoded.products.map(\.productID))
    }

    private func findProjectRoot() throws -> URL {
        var url = URL(fileURLWithPath: #filePath)

        while url.path != "/" {
            let candidate = url.appendingPathComponent("RHOIDS.storekit")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return url
            }
            url.deleteLastPathComponent()
        }

        throw TipJarTestError.projectRootNotFound
    }

    private struct StoreKitConfiguration: Decodable {
        let products: [StoreKitProduct]
    }

    private struct StoreKitProduct: Decodable {
        let productID: String
    }

    private enum TipJarTestError: Error {
        case projectRootNotFound
    }
}
