//
//  ModelContainer+AuraScan.swift
//  AuraScan
//

import Foundation
import SwiftData

extension ModelContainer {
    static let schema = Schema([Reading.self])

    /// On-disk container. Falls back to memory if the store cannot be opened so
    /// a corrupt store degrades the app to "history unavailable" instead of a crash.
    static func aurascan() -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        if let container = try? ModelContainer(for: schema, configurations: [configuration]) {
            return container
        }
        return .inMemory()
    }

    static func inMemory() -> ModelContainer {
        // A memory-only container has no I/O to fail on; a throw here would mean
        // the schema itself is invalid, which is a programmer error.
        try! ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
    }
}
