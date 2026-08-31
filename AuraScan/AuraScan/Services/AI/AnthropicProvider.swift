//
//  AnthropicProvider.swift
//  AuraScan
//
//  Claude Messages API client. Uses `output_config.format` with a JSON Schema so
//  the model is constrained to emit exactly `AnalysisResponse`, and adaptive
//  thinking, which is on by default on the Opus 5 family.
//
//  NOTE: shipping an API key inside the app binary is not safe for a public
//  release — point `baseURL` at your own relay in production and keep the key
//  server-side. `SecretStore` exists so a developer build can run standalone.
//

import Foundation

struct AnthropicProvider: AIProvider {
    let id: AIProviderID = .anthropic
    let supportsSchemaEnforcement = true

    private let apiKeyProvider: @Sendable () throws -> String
    private let baseURL: URL
    private let http: HTTPClient

    private static let apiVersion = "2023-06-01"

    init(
        baseURL: URL = URL(string: "https://api.anthropic.com/v1/messages")!,
        http: HTTPClient = HTTPClient(),
        apiKeyProvider: @escaping @Sendable () throws -> String
    ) {
        self.baseURL = baseURL
        self.http = http
        self.apiKeyProvider = apiKeyProvider
    }

    func complete(_ request: MultimodalRequest) async throws -> MultimodalCompletion {
        var content: [[String: Any]] = request.images.map { image in
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mimeType,
                    "data": image.base64,
                ],
            ]
        }
        content.append(["type": "text", "text": request.userPrompt])

        var outputConfig: [String: Any] = ["effort": "high"]
        if let schema = request.jsonSchema {
            outputConfig["format"] = ["type": "json_schema", "schema": schema]
        }

        let body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens,
            // The system prompt is stable per modality, so caching it makes
            // repeat readings materially cheaper.
            "system": [
                [
                    "type": "text",
                    "text": request.systemPrompt,
                    "cache_control": ["type": "ephemeral"],
                ]
            ],
            "output_config": outputConfig,
            "messages": [["role": "user", "content": content]],
        ]

        let urlRequest = try URLRequest.json(
            url: baseURL,
            headers: [
                "x-api-key": try apiKeyProvider(),
                "anthropic-version": Self.apiVersion,
            ],
            body: body
        )

        let data = try await http.send(urlRequest) { errorData in
            JSONBody.string(at: ["error", "message"], in: errorData)
        }
        return try Self.parse(data)
    }

    // MARK: - Response parsing

    static func parse(_ data: Data) throws -> MultimodalCompletion {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIProviderError.invalidResponse
        }

        let stopReason = object["stop_reason"] as? String

        if stopReason == "refusal" {
            let explanation = JSONBody.value(at: ["stop_details", "explanation"], in: object) as? String
            throw AIProviderError.refused(explanation)
        }
        if stopReason == "max_tokens" {
            throw AIProviderError.truncated
        }

        // Content is a list of blocks; thinking blocks are interleaved with text
        // and must be skipped rather than concatenated.
        let blocks = object["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.emptyCompletion
        }

        let usage = object["usage"] as? [String: Any]
        return MultimodalCompletion(
            text: text,
            model: object["model"] as? String ?? "",
            inputTokens: usage?["input_tokens"] as? Int,
            outputTokens: usage?["output_tokens"] as? Int,
            stopReason: stopReason
        )
    }
}
