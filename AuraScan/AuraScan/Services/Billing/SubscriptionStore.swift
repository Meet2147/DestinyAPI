//
//  SubscriptionStore.swift
//  AuraScan
//
//  StoreKit 2. Entitlement is derived from `Transaction.currentEntitlements`
//  rather than tracked locally, so a lapsed subscription, a refund or a family
//  share all resolve correctly without any bookkeeping of our own.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class SubscriptionStore {
    enum PurchaseOutcome: Equatable {
        case purchased
        case pending          // Ask to Buy, or a payment needing SCA
        case cancelled
    }

    private(set) var products: [Product] = []
    private(set) var isSubscribed = false
    private(set) var isLoading = false
    private(set) var loadFailed = false

    private let entitlements: Entitlements

    // Deliberately never cancelled: this object lives for the lifetime of the
    // app (AppEnvironment owns it), and transaction updates must be observed
    // the whole time — a renewal or an Ask to Buy approval can land while no
    // paywall is on screen. Cancelling it in `deinit` is also impossible under
    // Swift 6, since `deinit` is nonisolated and this type is @MainActor.
    private var updatesTask: Task<Void, Never>?

    init(entitlements: Entitlements) {
        self.entitlements = entitlements
        // Transactions can arrive when the app is not in a purchase flow at all
        // — an Ask to Buy approval, a renewal, a purchase made on another
        // device. This listener has to outlive any one screen.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard case let .verified(transaction) = update else { continue }
                await transaction.finish()
                await self?.refreshEntitlement()
            }
        }
    }

    func load() async {
        isLoading = true
        loadFailed = false
        defer { isLoading = false }
        do {
            let ids = SubscriptionProduct.allCases.map(\.rawValue)
            products = try await Product.products(for: ids)
                .sorted { lhs, rhs in lhs.price < rhs.price }
        } catch {
            loadFailed = true
        }
        await refreshEntitlement()
    }

    func product(for id: SubscriptionProduct) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                // Failed verification means the receipt is not trustworthy;
                // treat it as no purchase rather than granting access.
                throw StoreError.unverified
            }
            await transaction.finish()
            await refreshEntitlement()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    /// The single source of truth for access.
    func refreshEntitlement() async {
        var entitled = false
        for await entitlement in Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement,
                  SubscriptionProduct(rawValue: transaction.productID) != nil
            else { continue }
            // A revoked transaction (refund, family removal) still appears here.
            if transaction.revocationDate == nil {
                entitled = true
                break
            }
        }
        isSubscribed = entitled
        entitlements.setSubscribed(entitled)
    }

    enum StoreError: LocalizedError {
        case unverified
        var errorDescription: String? {
            switch self {
            case .unverified:
                "That purchase could not be verified with the App Store."
            }
        }
    }
}
