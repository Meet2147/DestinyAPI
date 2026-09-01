//
//  PaywallView.swift
//  AuraScan
//
//  Shown when the free readings run out, and from Settings.
//
//  Prices come from StoreKit rather than being hardcoded: the store knows the
//  local currency, the regional price and any introductory offer, and a
//  hardcoded "$4.99" is wrong for most of the world.
//

import StoreKit
import SwiftUI

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    private let store: SubscriptionStore
    @State private var selection: SubscriptionProduct = .annual
    @State private var isPurchasing = false
    @State private var message: String?

    private let entitlements: Entitlements

    init(entitlements: Entitlements, store: SubscriptionStore) {
        self.entitlements = entitlements
        self.store = store
    }

    var body: some View {
        ZStack {
            CosmicBackground()
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    header
                    benefits
                    plans
                    callToAction
                    smallPrint
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.lg)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Close") { dismiss() }
                    .foregroundStyle(Theme.Palette.moonlight)
            }
        }
        .task { await store.load() }
        .alert("Purchase", isPresented: .constant(message != nil)) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Palette.gold)
                .frame(width: 74, height: 74)
                .softRaised(Circle(), depth: .pronounced, tint: Theme.Palette.aura)

            Text("Keep reading")
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Palette.starlight)

            Text(entitlements.freeRemaining > 0
                 ? "You have \(entitlements.freeRemaining) free reading\(entitlements.freeRemaining == 1 ? "" : "s") left."
                 : "You have used all seven free readings.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.moonlight)
                .multilineTextAlignment(.center)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private var benefits: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                benefit("infinity", "Unlimited readings",
                        "Face, palm, coffee and space, as often as you like.")
                benefit("square.stack.3d.up", "Every modality",
                        "All four traditions, and everything added later.")
                benefit("clock.arrow.circlepath", "Your full history",
                        "Every reading kept, searchable, and yours to revisit.")
                benefit("bolt.fill", "Priority readings",
                        "Your scans go first when things are busy.")
            }
        }
    }

    private func benefit(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.Palette.glow)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Palette.starlight)
                Text(detail)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.dusk)
            }
        }
    }

    private var plans: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(SubscriptionProduct.allCases, id: \.self) { plan in
                PlanRow(
                    plan: plan,
                    product: store.product(for: plan),
                    isSelected: selection == plan,
                    badge: badge(for: plan)
                )
                .onTapGesture {
                    withAnimation(.snappy(duration: 0.18)) { selection = plan }
                }
            }
            if store.loadFailed {
                Text("Could not reach the App Store. Prices shown are approximate.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.gold)
            }
        }
    }

    /// Computed from the real prices so it cannot drift out of date if the
    /// store prices change or a region differs.
    private func badge(for plan: SubscriptionProduct) -> String? {
        guard plan == .annual,
              let monthly = store.product(for: .monthly),
              let annual = store.product(for: .annual)
        else { return plan == .annual ? "Best value" : nil }
        let yearAtMonthly = monthly.price * 12
        guard yearAtMonthly > 0 else { return "Best value" }
        let saved = (yearAtMonthly - annual.price) / yearAtMonthly
        return "Save \(Int((saved as NSDecimalNumber).doubleValue * 100))%"
    }

    private var callToAction: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Button {
                Task { await buy() }
            } label: {
                HStack {
                    if isPurchasing { ProgressView().tint(Theme.Palette.void) }
                    Text(isPurchasing ? "Confirming…" : ctaTitle)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AuraButtonStyle())
            .disabled(isPurchasing || store.product(for: selection) == nil)

            Button("Restore purchases") {
                Task { await restore() }
            }
            .buttonStyle(AuraButtonStyle(isProminent: false))
            .disabled(isPurchasing)
        }
    }

    private var ctaTitle: String {
        selection == .lifetime ? "Unlock forever" : "Start subscription"
    }

    private var smallPrint: some View {
        VStack(spacing: 6) {
            Text(selection.isSubscription
                 ? "Renews automatically until cancelled. Manage or cancel any time in Settings."
                 : "A one-time purchase. No renewal, nothing to cancel.")
            Text("AuraScan is for reflection and entertainment. It is not advice.")
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Palette.dusk)
        .multilineTextAlignment(.center)
        .padding(.horizontal, Theme.Spacing.sm)
    }

    // MARK: - Actions

    private func buy() async {
        guard let product = store.product(for: selection) else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await store.purchase(product) {
            case .purchased: dismiss()
            case .pending:
                message = "That purchase needs approval before it completes. "
                    + "You will get access as soon as it is approved."
            case .cancelled: break   // saying anything here would be nagging
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await store.restore()
            message = store.isSubscribed
                ? "Restored. Welcome back."
                : "No previous purchase was found on this Apple Account."
            if store.isSubscribed { dismiss() }
        } catch {
            message = error.localizedDescription
        }
    }
}

// MARK: - Plan row

private struct PlanRow: View {
    let plan: SubscriptionProduct
    let product: Product?
    let isSelected: Bool
    let badge: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(isSelected ? Theme.Palette.aura : Theme.Palette.dusk)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Palette.starlight)
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                }
            }

            Spacer(minLength: Theme.Spacing.xs)

            if let badge {
                Text(badge)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.void)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Theme.Palette.glow))
            }

            Text(product?.displayPrice ?? plan.fallbackPrice)
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Palette.starlight)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .softRaised(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous),
            depth: isSelected ? .pronounced : .subtle,
            tint: isSelected ? Theme.Palette.aura : nil
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var title: String {
        switch plan {
        case .monthly: "Monthly"
        case .annual: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    private var subtitle: String? {
        switch plan {
        case .monthly: "Billed every month"
        case .annual: "Billed once a year"
        case .lifetime: "Pay once, keep forever"
        }
    }
}
