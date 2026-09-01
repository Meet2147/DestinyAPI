//
//  RelayProvider.swift
//  AuraScan
//
//  Talks to our own relay instead of Anthropic directly.
//
//  The app ships no API key. The relay holds it, decides who may take a reading,
//  and pins the model — so the request below deliberately does not say which
//  model to use or how many tokens to spend. Anything it did say would be
//  overridden there anyway, because a client cannot be trusted with either.
//

import Foundation
import UIKit

struct RelayProvider: AIProvider {
    let id: AIProviderID = .anthropic
    let supportsSchemaEnforcement = true

    private let baseURL: URL
    private let http: HTTPClient
    private let deviceID: @Sendable () -> String
    private let transactionJWS: @Sendable () async -> String?

    init(
        baseURL: URL,
        http: HTTPClient = HTTPClient(),
        deviceID: @escaping @Sendable () -> String = { RelayProvider.installIdentifier },
        transactionJWS: @escaping @Sendable () async -> String? = {
            await RelayProvider.currentTransactionJWS()
        }
    ) {
        self.baseURL = baseURL
        self.http = http
        self.deviceID = deviceID
        self.transactionJWS = transactionJWS
    }

    func complete(_ request: MultimodalRequest) async throws -> MultimodalCompletion {
        var content: [[String: Any]] = []
        for image in request.images {
            content.append([
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": image.mimeType,
                    "data": image.base64,
                ],
            ])
        }
        content.append(["type": "text", "text": request.userPrompt])

        var body: [String: Any] = [
            "system": request.systemPrompt,
            "messages": [["role": "user", "content": content]],
        ]
        if let schema = request.jsonSchema {
            body["output_config"] = ["format": ["type": "json_schema", "schema": schema]]
        }

        var headers = ["x-device-id": deviceID()]
        if let jws = await transactionJWS() {
            headers["x-transaction"] = jws
        }

        let urlRequest = try URLRequest.json(
            url: baseURL.appendingPathComponent("v1/reading"),
            headers: headers,
            body: body
        )

        let data = try await http.send(urlRequest) { errorData in
            JSONBody.string(at: ["detail"], in: errorData)
        }
        // The relay passes Anthropic's `content` and `stop_reason` through
        // unchanged, so the existing parser applies as-is.
        return try AnthropicProvider.parse(data)
    }

    // MARK: - Identity

    /// Stable for as long as the app stays installed, and shared by nothing
    /// else. It identifies an install for rate limiting, not a person.
    static var installIdentifier: String {
        let key = "ai.aurascan.installID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let fresh = UIDevice.current.identifierForVendor?.uuidString
            ?? UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: key)
        return fresh
    }

    /// The signed transaction for an active purchase, which the relay verifies
    /// against Apple's root. Nil when there is nothing to prove.
    static func currentTransactionJWS() async -> String? {
        for await entitlement in StoreKitBridge.currentEntitlements() {
            return entitlement
        }
        return nil
    }
}
