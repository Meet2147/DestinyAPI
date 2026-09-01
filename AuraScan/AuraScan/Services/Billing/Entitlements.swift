//
//  Entitlements.swift
//  AuraScan
//
//  Who is allowed another reading, and why.
//
//  The free allowance is stored per-install rather than per-Apple-ID: it is a
//  trial, not a balance, so it does not need to survive a reinstall. Anything
//  stronger would need a server, and this is not worth a server.
//

import Foundation

/// Product identifiers, as configured in App Store Connect.
enum SubscriptionProduct: String, CaseIterable, Sendable {
    case monthly  = "ai.aurascan.pro.monthly"
    case annual   = "ai.aurascan.pro.annual"
    case lifetime = "ai.aurascan.pro.lifetime"

    var isSubscription: Bool { self != .lifetime }

    /// Shown only if the store lookup fails; StoreKit's localised price wins.
    var fallbackPrice: String {
        switch self {
        case .monthly: "$4.99"
        case .annual: "$49.99"
        case .lifetime: "$149"
        }
    }
}

/// What a reading attempt is allowed to do right now.
enum ReadingAllowance: Equatable, Sendable {
    case subscribed
    case free(remaining: Int)
    case exhausted

    var isAllowed: Bool { self != .exhausted }

    var remainingFreeReadings: Int? {
        if case let .free(remaining) = self { return remaining }
        return nil
    }
}

@MainActor
protocol EntitlementStoring: AnyObject {
    var isSubscribed: Bool { get set }
    var freeReadingsUsed: Int { get set }
}

/// UserDefaults-backed store. The subscription flag is owned by StoreKit and
/// only mirrored here so the UI has something synchronous to read.
@MainActor
final class DefaultsEntitlementStore: EntitlementStoring {
    private enum Key {
        static let used = "ai.aurascan.freeReadingsUsed"
        static let subscribed = "ai.aurascan.isSubscribed"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var isSubscribed: Bool {
        get { defaults.bool(forKey: Key.subscribed) }
        set { defaults.set(newValue, forKey: Key.subscribed) }
    }

    var freeReadingsUsed: Int {
        get { defaults.integer(forKey: Key.used) }
        set { defaults.set(max(0, newValue), forKey: Key.used) }
    }
}

@MainActor
@Observable
final class Entitlements {
    /// Readings before the paywall. Seven is enough to try every modality and
    /// come back once, which is when someone decides whether they care.
    static let freeAllowance = 7

    private let store: any EntitlementStoring

    init(store: any EntitlementStoring = DefaultsEntitlementStore()) {
        self.store = store
        self.isSubscribed = store.isSubscribed
        self.used = store.freeReadingsUsed
    }

    private(set) var isSubscribed: Bool
    private(set) var used: Int

    var allowance: ReadingAllowance {
        if isSubscribed { return .subscribed }
        let left = Self.freeAllowance - used
        return left > 0 ? .free(remaining: left) : .exhausted
    }

    var freeRemaining: Int { max(0, Self.freeAllowance - used) }

    /// Call only once a reading has actually succeeded. A failed request must
    /// not cost someone a free run — that is the fastest way to lose them
    /// before they have seen anything work.
    func recordSuccessfulReading() {
        guard !isSubscribed else { return }
        used += 1
        store.freeReadingsUsed = used
    }

    func setSubscribed(_ value: Bool) {
        isSubscribed = value
        store.isSubscribed = value
    }

    #if DEBUG
    func resetFreeReadings() {
        used = 0
        store.freeReadingsUsed = 0
    }
    #endif
}
