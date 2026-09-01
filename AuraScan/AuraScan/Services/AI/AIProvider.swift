//
//  AIProvider.swift
//  AuraScan
//
//  Transport abstraction over the multimodal vision APIs. `VisionAnalysisService`
//  owns prompt construction and decoding; a provider only has to turn a
//  `MultimodalRequest` into HTTP and hand back raw text.
//

import Foundation

enum AIProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case anthropic
    case openAI = "openai"
    case gemini

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic: "Anthropic Claude"
        case .openAI: "OpenAI"
        case .gemini: "Google Gemini"
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: "claude-opus-5"
        case .openAI: "gpt-4o"
        case .gemini: "gemini-2.0-flash"
        }
    }

    var keychainAccount: String { "ai.aurascan.apikey.\(rawValue)" }
}

/// One image attached to a request.
struct ImagePayload: Sendable {
    let mimeType: String
    let base64: String

    var dataURL: String { "data:\(mimeType);base64,\(base64)" }
}

struct MultimodalRequest: @unchecked Sendable {
    let model: String
    let systemPrompt: String
    let userPrompt: String
    let images: [ImagePayload]
    let maxTokens: Int
    /// JSON Schema the response must satisfy. Providers that support
    /// constrained decoding wire it up; the rest rely on prompt instructions.
    let jsonSchema: [String: Any]?
    let schemaName: String

    init(
        model: String,
        systemPrompt: String,
        userPrompt: String,
        images: [ImagePayload],
        maxTokens: Int = 8_000,
        jsonSchema: [String: Any]? = nil,
        schemaName: String = AnalysisSchema.name
    ) {
        self.model = model
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.images = images
        self.maxTokens = maxTokens
        self.jsonSchema = jsonSchema
        self.schemaName = schemaName
    }
}

struct MultimodalCompletion: Sendable {
    let text: String
    let model: String
    let inputTokens: Int?
    let outputTokens: Int?
    /// Set when the provider stopped for a reason other than a finished answer.
    let stopReason: String?
}

protocol AIProvider: Sendable {
    var id: AIProviderID { get }
    /// Whether the provider enforces the JSON Schema server-side. When `false`,
    /// `VisionAnalysisService` leans harder on prompt-level enforcement and the
    /// repair pass.
    var supportsSchemaEnforcement: Bool { get }

    func complete(_ request: MultimodalRequest) async throws -> MultimodalCompletion
}

// MARK: - Errors

enum AIProviderError: LocalizedError, Equatable, Sendable {
    case missingAPIKey(AIProviderID)
    case invalidResponse
    case emptyCompletion
    /// The model declined the request (Anthropic `stop_reason: "refusal"`).
    case refused(String?)
    /// Output hit the token ceiling — the JSON is truncated and unparseable.
    case truncated
    case rateLimited(retryAfter: TimeInterval?)
    case server(status: Int, message: String?)
    case client(status: Int, message: String?)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case let .missingAPIKey(provider):
            "No API key set for \(provider.title). Add one in Settings."
        case .invalidResponse:
            "The service returned a response AuraScan could not read."
        case .emptyCompletion:
            "The service returned an empty reading."
        case let .refused(explanation):
            explanation ?? "The model declined to analyse this image."
        case .truncated:
            "The reading was cut off before it finished. Try again."
        case .rateLimited:
            "Too many readings in a short window. Give it a moment."
        case let .server(status, message):
            message ?? "The service is having trouble (\(status)). Try again shortly."
        case let .client(status, message):
            message ?? "The request was rejected (\(status))."
        case let .transport(message):
            message
        }
    }

    /// Whether `VisionAnalysisService` should retry with backoff.
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .server, .transport: true
        case .missingAPIKey, .invalidResponse, .emptyCompletion, .refused, .truncated, .client: false
        }
    }
}
