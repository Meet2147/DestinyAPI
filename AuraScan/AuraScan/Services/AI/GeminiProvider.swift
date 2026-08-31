//
//  GeminiProvider.swift
//  AuraScan
//
//  Gemini `generateContent` client. Gemini's schema dialect is a restricted
//  subset of JSON Schema, so the schema is sanitised before being sent and the
//  prompt keeps carrying the contract as a backstop.
//

import Foundation

struct GeminiProvider: AIProvider {
    let id: AIProviderID = .gemini
    let supportsSchemaEnforcement = true

    private let apiKeyProvider: @Sendable () throws -> String
    private let baseURL: URL
    private let http: HTTPClient

    init(
        baseURL: URL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models")!,
        http: HTTPClient = HTTPClient(),
        apiKeyProvider: @escaping @Sendable () throws -> String
    ) {
        self.baseURL = baseURL
        self.http = http
        self.apiKeyProvider = apiKeyProvider
    }

    func complete(_ request: MultimodalRequest) async throws -> MultimodalCompletion {
        var parts: [[String: Any]] = request.images.map { image in
            ["inline_data": ["mime_type": image.mimeType, "data": image.base64]]
        }
        parts.append(["text": request.userPrompt])

        var generationConfig: [String: Any] = [
            "temperature": 0.4,
            "maxOutputTokens": request.maxTokens,
            "responseMimeType": "application/json",
        ]
        if let schema = request.jsonSchema {
            generationConfig["responseSchema"] = Self.sanitizedSchema(schema)
        }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": request.systemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": generationConfig,
        ]

        let url = baseURL.appendingPathComponent("\(request.model):generateContent")
        let urlRequest = try URLRequest.json(
            url: url,
            headers: ["x-goog-api-key": try apiKeyProvider()],
            body: body
        )

        let data = try await http.send(urlRequest) { errorData in
            JSONBody.string(at: ["error", "message"], in: errorData)
        }
        return try Self.parse(data, requestedModel: request.model)
    }

    static func parse(_ data: Data, requestedModel: String) throws -> MultimodalCompletion {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.invalidResponse
        }

        if let blockReason = JSONBody.value(at: ["promptFeedback", "blockReason"], in: object) as? String {
            throw AIProviderError.refused("Blocked: \(blockReason)")
        }

        guard let candidate = (object["candidates"] as? [[String: Any]])?.first else {
            throw AIProviderError.emptyCompletion
        }

        let finishReason = candidate["finishReason"] as? String
        switch finishReason {
        case "MAX_TOKENS": throw AIProviderError.truncated
        case "SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST": throw AIProviderError.refused(nil)
        default: break
        }

        let parts = JSONBody.value(at: ["content", "parts"], in: candidate) as? [[String: Any]] ?? []
        let text = parts.compactMap { $0["text"] as? String }.joined()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.emptyCompletion
        }

        let usage = object["usageMetadata"] as? [String: Any]
        return MultimodalCompletion(
            text: text,
            model: object["modelVersion"] as? String ?? requestedModel,
            inputTokens: usage?["promptTokenCount"] as? Int,
            outputTokens: usage?["candidatesTokenCount"] as? Int,
            stopReason: finishReason
        )
    }

    /// Strips keywords Gemini's schema dialect rejects (`additionalProperties`,
    /// `anyOf` null-unions, `pattern`) while preserving structure.
    static func sanitizedSchema(_ schema: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        let unsupported: Set<String> = ["additionalProperties", "pattern", "$schema"]

        for (key, value) in schema where !unsupported.contains(key) {
            // `anyOf: [T, null]` collapses to T with the field made optional by
            // simply not listing it under `required`.
            if key == "anyOf", let branches = value as? [[String: Any]] {
                let concrete = branches.first { ($0["type"] as? String) != "null" }
                if let concrete {
                    for (innerKey, innerValue) in sanitizedSchema(concrete) {
                        result[innerKey] = innerValue
                    }
                }
                continue
            }
            // Gemini accepts a single type string only.
            if key == "type", let types = value as? [String] {
                result[key] = types.first { $0 != "null" } ?? "string"
                continue
            }
            switch value {
            case let dictionary as [String: Any]:
                result[key] = sanitizedSchema(dictionary)
            case let array as [[String: Any]]:
                result[key] = array.map(sanitizedSchema)
            default:
                result[key] = value
            }
        }
        return result
    }
}
