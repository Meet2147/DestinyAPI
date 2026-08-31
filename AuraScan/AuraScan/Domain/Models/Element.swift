//
//  Element.swift
//  AuraScan
//
//  Classical elements and planetary rulers shared by every modality.
//

import SwiftUI

enum Element: String, Codable, CaseIterable, Identifiable, Sendable {
    case fire
    case earth
    case air
    case water

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var glyph: String {
        switch self {
        case .fire: "🜂"
        case .earth: "🜃"
        case .air: "🜁"
        case .water: "🜄"
        }
    }

    var systemImage: String {
        switch self {
        case .fire: "flame.fill"
        case .earth: "mountain.2.fill"
        case .air: "wind"
        case .water: "drop.fill"
        }
    }

    var color: Color {
        switch self {
        case .fire: Color(hex: 0xF97362)
        case .earth: Color(hex: 0x84CC91)
        case .air: Color(hex: 0xA5B4FC)
        case .water: Color(hex: 0x5EC8E5)
        }
    }

    var keyword: String {
        switch self {
        case .fire: "Drive & initiation"
        case .earth: "Structure & endurance"
        case .air: "Thought & exchange"
        case .water: "Feeling & intuition"
        }
    }

    /// Tolerant decoding: the model occasionally returns "Fire" or " water ".
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let value = Element(rawValue: normalized) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown element '\(raw)'")
            )
        }
        self = value
    }
}

enum Planet: String, Codable, CaseIterable, Identifiable, Sendable {
    case sun, moon, mercury, venus, mars, jupiter, saturn
    case uranus, neptune, pluto
    case rahu, ketu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rahu: "Rahu"
        case .ketu: "Ketu"
        default: rawValue.capitalized
        }
    }

    var glyph: String {
        switch self {
        case .sun: "☉"
        case .moon: "☽"
        case .mercury: "☿"
        case .venus: "♀"
        case .mars: "♂"
        case .jupiter: "♃"
        case .saturn: "♄"
        case .uranus: "♅"
        case .neptune: "♆"
        case .pluto: "♇"
        case .rahu: "☊"
        case .ketu: "☋"
        }
    }

    var domain: String {
        switch self {
        case .sun: "Vitality, identity, recognition"
        case .moon: "Emotion, memory, receptivity"
        case .mercury: "Speech, commerce, analysis"
        case .venus: "Harmony, beauty, attraction"
        case .mars: "Will, conflict, stamina"
        case .jupiter: "Expansion, belief, fortune"
        case .saturn: "Boundaries, time, discipline"
        case .uranus: "Disruption, invention"
        case .neptune: "Dreams, dissolution"
        case .pluto: "Transformation, depth"
        case .rahu: "Hunger, obsession, ascent"
        case .ketu: "Detachment, residue, release"
        }
    }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let value = Planet(rawValue: normalized) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unknown planet '\(raw)'")
            )
        }
        self = value
    }
}

/// Whether a detected marker supports, challenges or merely colours the reading.
enum Polarity: String, Codable, CaseIterable, Sendable {
    case supportive
    case neutral
    case challenging

    var title: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .supportive: Color(hex: 0x6EE7B7)
        case .neutral: Color(hex: 0xB4B0C8)
        case .challenging: Color(hex: 0xFFA98A)
        }
    }

    var systemImage: String {
        switch self {
        case .supportive: "arrow.up.right.circle.fill"
        case .neutral: "circle.circle.fill"
        case .challenging: "exclamationmark.triangle.fill"
        }
    }

    /// Unknown polarities degrade to `.neutral` rather than failing the reading.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self = Polarity(rawValue: normalized) ?? .neutral
    }
}
