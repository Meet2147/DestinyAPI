//
//  AppEnvironment.swift
//  AuraScan
//
//  Composition root. Views never construct services; they read them from here,
//  which keeps previews and tests able to swap in fakes.
//

import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
@Observable
final class AppEnvironment {
    /// Persisted provider selection. The key itself lives in the Keychain.
    var providerID: AIProviderID {
        didSet {
            UserDefaults.standard.set(providerID.rawValue, forKey: Self.providerKey)
            modelIdentifier = UserDefaults.standard.string(forKey: Self.modelKey(for: providerID))
                ?? providerID.defaultModel
        }
    }

    var modelIdentifier: String {
        didSet {
            UserDefaults.standard.set(modelIdentifier, forKey: Self.modelKey(for: providerID))
        }
    }

    let secretStore: any SecretStoring
    let repository: any ReadingStoring
    let container: ModelContainer
    /// Shared so the paywall, Settings and every capture screen agree on how
    /// many free readings are left.
    let entitlements: Entitlements
    /// One instance for the whole app: StoreKit transaction updates arrive
    /// whether or not a paywall happens to be open.
    let subscriptionStore: SubscriptionStore

    private let analyzerFactory: @MainActor (AIProviderID, String, any SecretStoring) -> any VisionAnalyzing

    init(
        container: ModelContainer,
        secretStore: any SecretStoring = KeychainSecretStore(),
        entitlements: Entitlements = Entitlements(),
        repository: (any ReadingStoring)? = nil,
        analyzerFactory: (@MainActor (AIProviderID, String, any SecretStoring) -> any VisionAnalyzing)? = nil
    ) {
        self.container = container
        self.secretStore = secretStore
        self.entitlements = entitlements
        self.subscriptionStore = SubscriptionStore(entitlements: entitlements)
        self.repository = repository ?? ReadingRepository(context: container.mainContext)
        self.analyzerFactory = analyzerFactory ?? AppEnvironment.makeDefaultAnalyzer

        let storedProvider = UserDefaults.standard.string(forKey: Self.providerKey)
            .flatMap(AIProviderID.init(rawValue:)) ?? .anthropic
        providerID = storedProvider
        modelIdentifier = UserDefaults.standard.string(forKey: Self.modelKey(for: storedProvider))
            ?? storedProvider.defaultModel
    }

    /// Analyzer for the currently selected provider/model.
    var analyzer: any VisionAnalyzing {
        analyzerFactory(providerID, modelIdentifier, secretStore)
    }

    /// With a relay configured the app needs no key of its own, so this is
    /// always satisfied — otherwise the capture screen would refuse to run
    /// against a perfectly working relay.
    var hasCredentials: Bool {
        Self.relayURL != nil || secretStore.hasAPIKey(for: providerID)
    }

    // MARK: - Factory

    private static func makeDefaultAnalyzer(
        providerID: AIProviderID,
        model: String,
        secretStore: any SecretStoring
    ) -> any VisionAnalyzing {
        let keyProvider: @Sendable () throws -> String = { try secretStore.apiKey(for: providerID) }

        // A configured relay wins: it holds the key, so the app does not
        // need one and the user is never asked for one.
        if let relay = Self.relayURL {
            // `model` is carried for the request shape only — the relay pins
            // the real one, so a client cannot choose an expensive model.
            return VisionAnalysisService(
                provider: RelayProvider(baseURL: relay),
                model: model
            )
        }

        let provider: any AIProvider = switch providerID {
        case .anthropic: AnthropicProvider(apiKeyProvider: keyProvider)
        case .openAI: OpenAIProvider(apiKeyProvider: keyProvider)
        case .gemini: GeminiProvider(apiKeyProvider: keyProvider)
        }

        return VisionAnalysisService(provider: provider, model: model)
    }

    // MARK: - Defaults keys

    private static let providerKey = "aurascan.provider"

    /// The relay's base URL. Set `RELAY_URL` in Info.plist for a real build;
    /// leaving it empty falls back to calling the provider directly with a
    /// key from the Keychain, which is how development works.
    static var relayURL: URL? {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "RELAY_URL") as? String)
            ?? ProcessInfo.processInfo.environment["RELAY_URL"]
            ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.hasPrefix("https://") else { return nil }
        return URL(string: trimmed)
    }

    private static func modelKey(for provider: AIProviderID) -> String {
        "aurascan.model.\(provider.rawValue)"
    }
}

// MARK: - Previews

extension AppEnvironment {
    /// In-memory environment backed by a canned reading — used by every preview.
    static func preview(seeded: Bool = true) -> AppEnvironment {
        let container = ModelContainer.inMemory()
        let environment = AppEnvironment(
            container: container,
            secretStore: InMemorySecretStore(seed: [.anthropic: "preview-key"]),
            analyzerFactory: { _, _, _ in StubVisionAnalyzer() }
        )
        if seeded {
            for (offset, modality) in ModalityType.allCases.enumerated() {
                let analysis = AnalysisResponse.sample(for: modality)
                if let reading = try? Reading(
                    createdAt: .now.addingTimeInterval(-Double(offset + 1) * 3_600),
                    modality: modality,
                    analysis: analysis,
                    imageData: nil,
                    thumbnailData: nil,
                    provider: .anthropic,
                    modelIdentifier: "claude-opus-5"
                ) {
                    container.mainContext.insert(reading)
                }
            }
        }
        return environment
    }
}

/// Returns a canned reading after a short delay; no network, no key needed.
struct StubVisionAnalyzer: VisionAnalyzing {
    var delay: Duration = .seconds(2)
    var failure: AnalysisError?

    func analyze(
        image: UIImage,
        modality: ModalityType,
        context: ReadingContext
    ) async throws -> AnalysisResult {
        try await Task.sleep(for: delay)
        if let failure { throw failure }
        return AnalysisResult(
            response: .sample(for: modality),
            provider: .anthropic,
            model: "claude-opus-5",
            inputTokens: 1_820,
            outputTokens: 940,
            didRepair: false
        )
    }
}
