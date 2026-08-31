//
//  HomeDashboardViewModel.swift
//  AuraScan
//

import Foundation
import Observation

@MainActor
@Observable
final class HomeDashboardViewModel {
    private(set) var recent: [Reading] = []
    private(set) var loadError: String?

    private let repository: any ReadingStoring

    init(repository: any ReadingStoring) {
        self.repository = repository
    }

    func refresh(limit: Int = 6) {
        do {
            recent = try repository.recent(limit: limit)
            loadError = nil
        } catch {
            recent = []
            loadError = error.localizedDescription
        }
    }

    func delete(_ reading: Reading) {
        try? repository.delete(reading)
        refresh()
    }

    /// Copy for the greeting line, keyed off the hour.
    var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: "Good morning"
        case 12..<17: "Good afternoon"
        case 17..<22: "Good evening"
        default: "Still awake"
        }
    }

    var subtitle: String {
        recent.isEmpty
            ? "Choose a modality to take your first reading."
            : "The field is quiet. What would you like to read?"
    }
}
