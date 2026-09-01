//
//  StoreKitBridge.swift
//  AuraScan
//
//  The signed JWS for a current purchase, which the relay verifies.
//  Kept apart from `SubscriptionStore` so the provider does not have to reach
//  into a @MainActor object from a background request.
//

import Foundation
import StoreKit

enum StoreKitBridge {
    /// Signed representations of every unrevoked entitlement, newest first.
    static func currentEntitlements() -> AsyncStream<String> {
        AsyncStream { continuation in
            Task {
                for await result in Transaction.currentEntitlements {
                    guard case let .verified(transaction) = result,
                          transaction.revocationDate == nil,
                          SubscriptionProduct(rawValue: transaction.productID) != nil
                    else { continue }
                    // `jsonRepresentation` is the signed payload Apple issued;
                    // the relay checks its certificate chain rather than
                    // trusting anything this app says about it.
                    continuation.yield(result.jwsRepresentation)
                }
                continuation.finish()
            }
        }
    }
}
