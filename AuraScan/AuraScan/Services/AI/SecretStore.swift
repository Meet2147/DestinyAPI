//
//  SecretStore.swift
//  AuraScan
//
//  Keychain-backed storage for provider API keys. Keys are never written to
//  UserDefaults, never logged, and never bundled — a debug build can seed one
//  from `AURASCAN_API_KEY` in the scheme environment.
//

import Foundation
import Security

protocol SecretStoring: Sendable {
    func apiKey(for provider: AIProviderID) throws -> String
    func setAPIKey(_ key: String?, for provider: AIProviderID) throws
    func hasAPIKey(for provider: AIProviderID) -> Bool
}

struct KeychainSecretStore: SecretStoring {
    private let service = "ai.aurascan.credentials"

    init() {}

    func apiKey(for provider: AIProviderID) throws -> String {
        if let stored = read(account: provider.keychainAccount), !stored.isEmpty {
            return stored
        }
        #if DEBUG
        // Convenience for simulator runs: set AURASCAN_API_KEY in the scheme.
        if let environmentKey = ProcessInfo.processInfo.environment["AURASCAN_API_KEY"],
           !environmentKey.isEmpty {
            return environmentKey
        }
        #endif
        throw AIProviderError.missingAPIKey(provider)
    }

    func setAPIKey(_ key: String?, for provider: AIProviderID) throws {
        let account = provider.keychainAccount
        guard let key, !key.trimmingCharacters(in: .whitespaces).isEmpty else {
            delete(account: account)
            return
        }
        try write(key.trimmingCharacters(in: .whitespacesAndNewlines), account: account)
    }

    func hasAPIKey(for provider: AIProviderID) -> Bool {
        (try? apiKey(for: provider)) != nil
    }

    // MARK: - Keychain primitives

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    private func read(account: String) -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        guard
            SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
            let data = item as? Data
        else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func write(_ value: String, account: String) throws {
        let data = Data(value.utf8)
        let query = baseQuery(account: account)

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return }

        guard updateStatus == errSecItemNotFound else {
            throw SecretStoreError.keychain(updateStatus)
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecretStoreError.keychain(addStatus)
        }
    }

    private func delete(account: String) {
        SecItemDelete(baseQuery(account: account) as CFDictionary)
    }
}

enum SecretStoreError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case let .keychain(status):
            let message = SecCopyErrorMessageString(status, nil) as String? ?? "status \(status)"
            return "Keychain error: \(message)"
        }
    }
}

/// In-memory store for previews and tests.
final class InMemorySecretStore: SecretStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [AIProviderID: String]

    init(seed: [AIProviderID: String] = [:]) {
        storage = seed
    }

    func apiKey(for provider: AIProviderID) throws -> String {
        lock.lock()
        defer { lock.unlock() }
        guard let key = storage[provider], !key.isEmpty else {
            throw AIProviderError.missingAPIKey(provider)
        }
        return key
    }

    func setAPIKey(_ key: String?, for provider: AIProviderID) throws {
        lock.lock()
        defer { lock.unlock() }
        storage[provider] = key
    }

    func hasAPIKey(for provider: AIProviderID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !(storage[provider] ?? "").isEmpty
    }
}
