//
//  VisionAnalysisService.swift
//  AuraScan
//
//  Orchestrates a reading: prepare the image → build the modality prompt →
//  call the provider with retry → extract and decode strict JSON → repair once
//  if the model drifted off-schema.
//

import Foundation
import OSLog
import UIKit

protocol VisionAnalyzing: Sendable {
    func analyze(
        image: UIImage,
        modality: ModalityType,
        context: ReadingContext
    ) async throws -> AnalysisResult
}

/// A decoded reading plus the provenance needed to persist it.
struct AnalysisResult: Sendable {
    let response: AnalysisResponse
    let provider: AIProviderID
    let model: String
    let inputTokens: Int?
    let outputTokens: Int?
    /// Whether the repair pass was needed. Surfaced in debug builds only.
    let didRepair: Bool
}

enum AnalysisError: LocalizedError {
    case imageEncodingFailed
    case noJSONInResponse(raw: String)
    case decodingFailed(underlying: any Error, raw: String)
    case unusableImage(suggestion: String?)
    case provider(AIProviderError)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            "That photo could not be prepared for analysis. Try retaking it."
        case .noJSONInResponse:
            "The reading came back in an unexpected format. Try again."
        case .decodingFailed:
            "The reading came back incomplete. Try again."
        case let .unusableImage(suggestion):
            suggestion ?? "The image is too unclear to read. Try retaking it with more light."
        case let .provider(error):
            error.errorDescription
        }
    }

    /// Copy for the "what should I do" line under the error.
    var recoverySuggestion: String? {
        switch self {
        case .unusableImage: "Retake the photo following the on-screen guide."
        case let .provider(error) where error.isRetryable: "Tap retry — the service should recover shortly."
        case .provider(.missingAPIKey): "Open Settings and add your API key."
        default: "Tap retry, or retake the photo if the problem persists."
        }
    }
}

// MARK: - Service

struct VisionAnalysisService: VisionAnalyzing {
    private let provider: any AIProvider
    private let model: String
    private let imageProcessor: any ImageProcessing
    private let maxRetries: Int
    private let logger = Logger(subsystem: "ai.aurascan", category: "vision")

    init(
        provider: any AIProvider,
        model: String,
        imageProcessor: any ImageProcessing = ImageProcessor(),
        maxRetries: Int = 3
    ) {
        self.provider = provider
        self.model = model
        self.imageProcessor = imageProcessor
        self.maxRetries = maxRetries
    }

    func analyze(
        image: UIImage,
        modality: ModalityType,
        context: ReadingContext
    ) async throws -> AnalysisResult {
        guard let payload = imageProcessor.payload(from: image) else {
            throw AnalysisError.imageEncodingFailed
        }

        let systemPrompt = AstrologyPrompts.systemPrompt(for: modality)
        let schema = provider.supportsSchemaEnforcement ? AnalysisSchema.jsonSchema(for: modality) : nil

        func request(_ context: ReadingContext) -> MultimodalRequest {
            MultimodalRequest(
                model: model,
                systemPrompt: systemPrompt,
                userPrompt: AstrologyPrompts.userPrompt(for: modality, context: context),
                images: [payload],
                maxTokens: 8_000,
                jsonSchema: schema
            )
        }

        let completion = try await send(request(context))

        do {
            let response = try decode(completion.text, expecting: modality)
            return result(response, completion: completion, didRepair: false)
        } catch let error as AnalysisError {
            // A model that judged the image unreadable will judge it unreadable
            // again — only schema misses are worth a second round trip.
            if case .unusableImage = error { throw error }
            // One repair pass: the model saw its own contract and missed. Asking
            // again with the failure flagged recovers the large majority of these.
            logger.warning("Schema miss on \(modality.rawValue, privacy: .public); attempting repair")
            let repaired = try await send(request(context.repairing()))
            let response = try decode(repaired.text, expecting: modality)
            return result(response, completion: repaired, didRepair: true)
        }
    }

    // MARK: - Transport with backoff

    private func send(_ request: MultimodalRequest) async throws -> MultimodalCompletion {
        var attempt = 0
        while true {
            do {
                return try await provider.complete(request)
            } catch let error as AIProviderError {
                attempt += 1
                guard error.isRetryable, attempt < maxRetries else {
                    throw AnalysisError.provider(error)
                }
                let delay = Self.backoffDelay(attempt: attempt, error: error)
                logger.notice("Retry \(attempt)/\(self.maxRetries) in \(delay, format: .fixed(precision: 1))s")
                try await Task.sleep(for: .seconds(delay))
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                throw AnalysisError.provider(.transport(error.localizedDescription))
            }
        }
    }

    /// Exponential backoff with jitter, honouring `retry-after` when present.
    static func backoffDelay(attempt: Int, error: AIProviderError) -> Double {
        if case let .rateLimited(retryAfter) = error, let retryAfter {
            return min(retryAfter, 30)
        }
        let exponential = pow(2.0, Double(attempt - 1))
        return min(exponential + Double.random(in: 0...0.5), 16)
    }

    // MARK: - Decoding

    func decode(_ text: String, expecting modality: ModalityType) throws -> AnalysisResponse {
        guard let json = Self.extractJSONObject(from: text) else {
            throw AnalysisError.noJSONInResponse(raw: text)
        }
        do {
            let response = try JSONDecoder().decode(AnalysisResponse.self, from: Data(json.utf8))
            guard response.modality == modality else {
                throw AnalysisError.decodingFailed(
                    underlying: DecodingError.dataCorrupted(
                        .init(codingPath: [], debugDescription: "Modality mismatch: expected \(modality.rawValue), got \(response.modality.rawValue)")
                    ),
                    raw: json
                )
            }
            guard response.imageQuality.usable else {
                throw AnalysisError.unusableImage(suggestion: response.imageQuality.suggestion)
            }
            return response
        } catch let error as AnalysisError {
            throw error
        } catch {
            throw AnalysisError.decodingFailed(underlying: error, raw: json)
        }
    }

    /// Pulls the first balanced JSON object out of a completion, tolerating
    /// markdown fences and any stray prose the model wrapped it in.
    static func extractJSONObject(from text: String) -> String? {
        var working = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if working.hasPrefix("```") {
            // Drop the opening fence (with or without a language tag) and the closing one.
            if let firstNewline = working.firstIndex(of: "\n") {
                working = String(working[working.index(after: firstNewline)...])
            }
            if let fenceRange = working.range(of: "```", options: .backwards) {
                working = String(working[working.startIndex..<fenceRange.lowerBound])
            }
            working = working.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let start = working.firstIndex(of: "{") else { return nil }

        var depth = 0
        var inString = false
        var isEscaped = false

        for index in working[start...].indices {
            let character = working[index]
            if isEscaped {
                isEscaped = false
                continue
            }
            switch character {
            case "\\" where inString:
                isEscaped = true
            case "\"":
                inString.toggle()
            case "{" where !inString:
                depth += 1
            case "}" where !inString:
                depth -= 1
                if depth == 0 {
                    return String(working[start...index])
                }
            default:
                break
            }
        }
        return nil
    }

    private func result(
        _ response: AnalysisResponse,
        completion: MultimodalCompletion,
        didRepair: Bool
    ) -> AnalysisResult {
        AnalysisResult(
            response: response,
            provider: provider.id,
            model: completion.model.isEmpty ? model : completion.model,
            inputTokens: completion.inputTokens,
            outputTokens: completion.outputTokens,
            didRepair: didRepair
        )
    }
}
