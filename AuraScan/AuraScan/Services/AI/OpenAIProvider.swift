//
//  OpenAIProvider.swift
//  AuraScan
//
//  Chat Completions client using `response_format: json_schema` for strict
//  structured output and data-URL image parts.
//

import Foundation

struct OpenAIProvider: AIProvider {
    let id: AIProviderID = .openAI
    let supportsSchemaEnforcement = true

    private let apiKeyProvider: @Sendable () throws -> String
    private let baseURL: URL
    private let http: HTTPClient

    init(
        baseURL: URL = URL(string: "https://api.openai.com/v1/chat/completions")!,
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
                "type": "image_url",
                "image_url": ["url": image.dataURL, "detail": "high"],
            ]
        }
        content.append(["type": "text", "text": request.userPrompt])

        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens,
            "temperature": 0.4,
            "messages": [
                ["role": "system", "content": request.systemPrompt],
                ["role": "user", "content": content],
            ],
        ]

        if let schema = request.jsonSchema {
            body["response_format"] = [
                "type": "json_schema",
                "json_schema": [
                    "name": request.schemaName,
                    "strict": true,
                    "schema": schema,
                ],
            ]
        } else {
            body["response_format"] = ["type": "json_object"]
        }

        let urlRequest = try URLRequest.json(
            url: baseURL,
            headers: ["Authorization": "Bearer \(try apiKeyProvider())"],
            body: body
        )

        let data = try await http.send(urlRequest) { errorData in
            JSONBody.string(at: ["error", "message"], in: errorData)
        }
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> MultimodalCompletion {
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choice = (object["choices"] as? [[String: Any]])?.first
        else {
            throw AIProviderError.invalidResponse
        }

        let finishReason = choice["finish_reason"] as? String
        if finishReason == "length" { throw AIProviderError.truncated }
        if finishReason == "content_filter" { throw AIProviderError.refused(nil) }

        if let refusal = JSONBody.value(at: ["message", "refusal"], in: choice) as? String {
            throw AIProviderError.refused(refusal)
        }
        guard
            let text = JSONBody.value(at: ["message", "content"], in: choice) as? String,
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIProviderError.emptyCompletion
        }

        let usage = object["usage"] as? [String: Any]
        return MultimodalCompletion(
            text: text,
            model: object["model"] as? String ?? "",
            inputTokens: usage?["prompt_tokens"] as? Int,
            outputTokens: usage?["completion_tokens"] as? Int,
            stopReason: finishReason
        )
    }
}
