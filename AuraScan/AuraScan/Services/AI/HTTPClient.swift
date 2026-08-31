//
//  HTTPClient.swift
//  AuraScan
//
//  Thin URLSession wrapper shared by every provider: it performs the request,
//  maps HTTP status codes onto `AIProviderError`, and lets each provider
//  extract a provider-specific error message from the body.
//

import Foundation

struct HTTPClient: Sendable {
    let session: URLSession

    init(session: URLSession = .aurascan) {
        self.session = session
    }

    /// - Parameter errorMessage: pulls a human message out of an error body.
    func send(
        _ request: URLRequest,
        errorMessage: @Sendable (Data) -> String? = { _ in nil }
    ) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw AIProviderError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIProviderError.invalidResponse
        }

        switch http.statusCode {
        case 200..<300:
            return data
        case 429:
            let retryAfter = (http.value(forHTTPHeaderField: "retry-after")).flatMap(TimeInterval.init)
            throw AIProviderError.rateLimited(retryAfter: retryAfter)
        case 500...:
            throw AIProviderError.server(status: http.statusCode, message: errorMessage(data))
        default:
            throw AIProviderError.client(status: http.statusCode, message: errorMessage(data))
        }
    }
}

extension URLSession {
    /// Vision calls routinely run 20–40s; the default 60s resource timeout is
    /// too tight once retries are layered on top.
    static let aurascan: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 180
        configuration.waitsForConnectivity = true
        configuration.httpAdditionalHeaders = ["User-Agent": "AuraScan/1.0 (iOS)"]
        return URLSession(configuration: configuration)
    }()
}

// MARK: - JSON helpers

extension URLRequest {
    static func json(
        url: URL,
        method: String = "POST",
        headers: [String: String],
        body: [String: Any]
    ) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }
}

enum JSONBody {
    /// Digs a nested value out of an untyped JSON object.
    static func value(at path: [String], in object: Any?) -> Any? {
        var current = object
        for key in path {
            guard let dictionary = current as? [String: Any] else { return nil }
            current = dictionary[key]
        }
        return current
    }

    static func string(at path: [String], in data: Data) -> String? {
        let object = try? JSONSerialization.jsonObject(with: data)
        return value(at: path, in: object) as? String
    }
}
