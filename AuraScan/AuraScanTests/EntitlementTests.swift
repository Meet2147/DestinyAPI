//
//  EntitlementTests.swift
//  AuraScanTests
//

import Testing
@testable import AuraScan

@MainActor
private final class MemoryStore: EntitlementStoring {
    var isSubscribed = false
    var freeReadingsUsed = 0
}

@MainActor
@Suite("Free allowance")
struct EntitlementTests {

    @Test("A new install gets exactly seven free readings")
    func startsWithSeven() {
        let e = Entitlements(store: MemoryStore())
        #expect(e.freeRemaining == 7)
        #expect(e.allowance == .free(remaining: 7))
    }

    @Test("The allowance runs out after the seventh, not the sixth")
    func exhaustsOnTheSeventh() {
        let e = Entitlements(store: MemoryStore())
        for expected in stride(from: 6, through: 0, by: -1) {
            e.recordSuccessfulReading()
            #expect(e.freeRemaining == expected)
        }
        #expect(e.allowance == .exhausted)
        #expect(!e.allowance.isAllowed)
    }

    @Test("A subscriber never consumes the free allowance")
    func subscriberSpendsNothing() {
        let e = Entitlements(store: MemoryStore())
        e.setSubscribed(true)
        for _ in 0..<50 { e.recordSuccessfulReading() }
        #expect(e.used == 0)
        #expect(e.allowance == .subscribed)
    }

    @Test("Subscribing rescues an exhausted account, and lapsing restores the count")
    func lapsingIsNotPunished() {
        let store = MemoryStore()
        let e = Entitlements(store: store)
        for _ in 0..<7 { e.recordSuccessfulReading() }
        #expect(e.allowance == .exhausted)

        e.setSubscribed(true)
        #expect(e.allowance == .subscribed)

        // A lapsed subscriber falls back to whatever free runs they had left —
        // which is none. They must not silently get seven more.
        e.setSubscribed(false)
        #expect(e.allowance == .exhausted)
    }

    @Test("The count survives a relaunch")
    func persists() {
        let store = MemoryStore()
        let first = Entitlements(store: store)
        first.recordSuccessfulReading()
        first.recordSuccessfulReading()

        let second = Entitlements(store: store)   // as if relaunched
        #expect(second.freeRemaining == 5)
    }

    @Test("Subscription state survives a relaunch")
    func subscriptionPersists() {
        let store = MemoryStore()
        Entitlements(store: store).setSubscribed(true)
        #expect(Entitlements(store: store).allowance == .subscribed)
    }
}
