//
//  AnalysisDecodingTests.swift
//  AuraScanTests
//
//  Covers the decoding paths that protect the app from model drift.
//

import Foundation
import Testing
@testable import AuraScan

@Suite("Analysis decoding")
struct AnalysisDecodingTests {

    @Test("Decodes a well-formed response")
    func decodesWellFormedResponse() throws {
        let response = try decode(Fixtures.wellFormed)

        #expect(response.modality == .coffee)
        #expect(response.dominantElement == .air)
        #expect(response.markers.count == 3)
        #expect(response.zones.first?.zone == "rim")
        #expect(response.guidance.actions.first?.horizon == .now)
    }

    @Test("Normalises element balance to sum to 100")
    func normalisesElementBalance() throws {
        let response = try decode(Fixtures.lopsidedBalance)
        #expect(response.elementBalance.count == 4)
        #expect(response.elementBalance.reduce(0) { $0 + $1.score } == 100)
    }

    @Test("Fills in a missing element with zero rather than failing")
    func fillsMissingElement() throws {
        let response = try decode(Fixtures.missingElement)
        #expect(response.elementBalance.map(\.element) == Element.allCases)
        #expect(response.elementBalance.first { $0.element == .water }?.score == 0)
    }

    @Test("Tolerates capitalised and padded enum values")
    func tolerantEnums() throws {
        let response = try decode(Fixtures.messyEnums)
        #expect(response.dominantElement == .fire)
        #expect(response.markers.first?.planet == .jupiter)
        #expect(response.markers.first?.zone == "forehead")
    }

    @Test("Unknown polarity degrades to neutral")
    func unknownPolarityDegrades() throws {
        let response = try decode(Fixtures.unknownPolarity)
        #expect(response.markers.first?.polarity == .neutral)
    }

    @Test("Clamps out-of-range scores")
    func clampsScores() throws {
        let response = try decode(Fixtures.outOfRange)
        #expect(response.energyScore == 100)
        #expect(response.confidence == 1.0)
        #expect(response.markers.first?.intensity == 5)
    }

    @Test("Synthesises a marker id when the model omits it")
    func synthesisesMarkerID() throws {
        let response = try decode(Fixtures.noMarkerID)
        #expect(response.markers.first?.id.isEmpty == false)
    }

    @Test("Rejects an unknown element")
    func rejectsUnknownElement() {
        #expect(throws: (any Error).self) {
            try decode(Fixtures.badElement)
        }
    }

    @Test("Every sample reading round-trips through JSON")
    func samplesRoundTrip() throws {
        for modality in ModalityType.allCases {
            let original = AnalysisResponse.sample(for: modality)
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(AnalysisResponse.self, from: data)
            #expect(decoded == original)
        }
    }

    private func decode(_ json: String) throws -> AnalysisResponse {
        try JSONDecoder().decode(AnalysisResponse.self, from: Data(json.utf8))
    }
}

// MARK: - Fixtures

/// Fixture builders take bare values and do their own quoting, so no fixture
/// needs a string literal nested inside an interpolation.
private enum Fixtures {
    static let defaultBalance = """
    [{"element":"fire","score":18},{"element":"earth","score":30},\
    {"element":"air","score":37},{"element":"water","score":15}]
    """

    static let defaultZones = """
    [{"zone":"rim","label":"Rim","timeframe":"Days","summary":"Active.","score":80,"element":"air"}]
    """

    static func envelope(
        modality: String = "coffee",
        confidence: String = "0.7",
        energy: String = "62",
        dominant: String = "air",
        balance: String = defaultBalance,
        markers: [String],
        zones: String = defaultZones
    ) -> String {
        let markerList = markers.joined(separator: ",")
        return """
        {
          "modality": "\(modality)",
          "confidence": \(confidence),
          "image_quality": {"usable": true, "issues": [], "suggestion": null},
          "headline": "A bird at the rim",
          "summary": "News before the matter settles.",
          "dominant_element": "\(dominant)",
          "element_balance": \(balance),
          "energy_score": \(energy),
          "markers": [\(markerList)],
          "zones": \(zones),
          "guidance": {
            "focus": "Receive before deciding.",
            "affirmation": "I can welcome what arrives.",
            "actions": [{"title": "Answer it", "detail": "Respond today.", "horizon": "now"}],
            "cautions": [],
            "lucky_color": {"name": "Copper", "hex": "#B87333"},
            "lucky_number": 7,
            "favorable_window": "Early evening",
            "ritual": null
          }
        }
        """
    }

    /// `planet` is a bare name, or nil for a JSON null.
    static func marker(
        id: String? = "rim-bird",
        zone: String = "rim",
        planet: String? = "mercury",
        polarity: String = "supportive",
        intensity: String = "5"
    ) -> String {
        let idField = id.map { #""id": "\#($0)","# } ?? ""
        let planetField = planet.map { #""\#($0)""# } ?? "null"
        return """
        {
          \(idField)
          "name": "Bird at the rim",
          "zone": "\(zone)",
          "observation": "A winged shape sits on the rim.",
          "interpretation": "News in motion.",
          "element": "air",
          "planet": \(planetField),
          "polarity": "\(polarity)",
          "intensity": \(intensity),
          "bounding_box": {"x": 0.58, "y": 0.12, "width": 0.16, "height": 0.14}
        }
        """
    }

    static let wellFormed = envelope(
        markers: [marker(id: "a"), marker(id: "b"), marker(id: "c")]
    )

    static let lopsidedBalance = envelope(
        balance: """
        [{"element":"fire","score":10},{"element":"earth","score":10},\
        {"element":"air","score":10},{"element":"water","score":10}]
        """,
        markers: [marker()]
    )

    static let missingElement = envelope(
        balance: """
        [{"element":"fire","score":40},{"element":"earth","score":30},{"element":"air","score":30}]
        """,
        markers: [marker()]
    )

    static let messyEnums = envelope(
        modality: "face",
        dominant: "  Fire ",
        markers: [marker(zone: "  FOREHEAD  ", planet: "Jupiter")],
        zones: """
        [{"zone":"forehead","label":"Forehead","timeframe":"Season","summary":"Open.","score":80,"element":"fire"}]
        """
    )

    static let unknownPolarity = envelope(markers: [marker(polarity: "auspicious")])

    static let outOfRange = envelope(
        confidence: "1.9",
        energy: "180",
        markers: [marker(intensity: "11")]
    )

    static let noMarkerID = envelope(markers: [marker(id: nil)])

    static let badElement = envelope(dominant: "aether", markers: [marker()])
}
