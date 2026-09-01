//
//  AnalysisResponse.swift
//  AuraScan
//
//  The structured payload every modality returns. The shape is shared across
//  all four readings so the results screen stays generic; modality-specific
//  nuance lives in `zones`, `markers` and the vocabulary the prompt enforces.
//

import SwiftUI

struct AnalysisResponse: Codable, Hashable, Sendable {
    let modality: ModalityType
    /// 0...1 — how confident the model is in the reading given image quality.
    let confidence: Double
    let imageQuality: ImageQuality
    let headline: String
    let summary: String
    let dominantElement: Element
    let elementBalance: [ElementScore]
    /// 0...100 overall energy/vitality score used by the summary gauge.
    let energyScore: Int
    let markers: [Marker]
    let zones: [ZoneInsight]
    let guidance: DayGuidance

    enum CodingKeys: String, CodingKey {
        case modality, confidence
        case imageQuality = "image_quality"
        case headline, summary
        case dominantElement = "dominant_element"
        case elementBalance = "element_balance"
        case energyScore = "energy_score"
        case markers, zones, guidance
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        modality = try c.decode(ModalityType.self, forKey: .modality)
        confidence = (try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 0.5).clamped(to: 0...1)
        imageQuality = try c.decodeIfPresent(ImageQuality.self, forKey: .imageQuality) ?? .acceptable
        headline = try c.decode(String.self, forKey: .headline)
        summary = try c.decode(String.self, forKey: .summary)
        dominantElement = try c.decode(Element.self, forKey: .dominantElement)
        elementBalance = ElementScore.normalized(try c.decodeIfPresent([ElementScore].self, forKey: .elementBalance) ?? [])
        energyScore = (try c.decodeIfPresent(Int.self, forKey: .energyScore) ?? 50).clamped(to: 0...100)
        markers = try c.decodeIfPresent([Marker].self, forKey: .markers) ?? []
        zones = try c.decodeIfPresent([ZoneInsight].self, forKey: .zones) ?? []
        guidance = try c.decode(DayGuidance.self, forKey: .guidance)
    }

    init(
        modality: ModalityType,
        confidence: Double,
        imageQuality: ImageQuality,
        headline: String,
        summary: String,
        dominantElement: Element,
        elementBalance: [ElementScore],
        energyScore: Int,
        markers: [Marker],
        zones: [ZoneInsight],
        guidance: DayGuidance
    ) {
        self.modality = modality
        self.confidence = confidence.clamped(to: 0...1)
        self.imageQuality = imageQuality
        self.headline = headline
        self.summary = summary
        self.dominantElement = dominantElement
        self.elementBalance = ElementScore.normalized(elementBalance)
        self.energyScore = energyScore.clamped(to: 0...100)
        self.markers = markers
        self.zones = zones
        self.guidance = guidance
    }

    /// Whether this reading actually says anything.
    ///
    /// The thresholds are deliberately generous — this is meant to catch a
    /// failed read, not to second-guess a cautious one. The prompt asks for
    /// 4–9 markers across 3+ zones, so two markers in one zone already means
    /// something went wrong with the image rather than with the subject.
    var isSubstantive: Bool {
        confidence >= 0.15 && markers.count >= 2 && !zones.isEmpty
    }

    /// Markers grouped by zone, preserving the model's ordering of zones.
    /// A named type rather than a tuple: `ForEach` needs a key path, and Swift
    /// has no key paths into tuple elements.
    var markersByZone: [ZoneGroup] {
        zones.map { zone in
            ZoneGroup(
                zone: zone,
                markers: markers.filter { $0.zone.caseInsensitiveCompare(zone.zone) == .orderedSame }
            )
        }
    }

    var unzonedMarkers: [Marker] {
        let known = Set(zones.map { $0.zone.lowercased() })
        return markers.filter { !known.contains($0.zone.lowercased()) }
    }
}

/// One zone paired with the markers found inside it.
struct ZoneGroup: Identifiable, Hashable, Sendable {
    let zone: ZoneInsight
    let markers: [Marker]

    var id: String { zone.id }
}

// MARK: - Image quality

struct ImageQuality: Codable, Hashable, Sendable {
    /// `false` means the reading is best discarded and the shot retaken.
    let usable: Bool
    let issues: [String]
    let suggestion: String?

    static let acceptable = ImageQuality(usable: true, issues: [], suggestion: nil)

    init(usable: Bool, issues: [String], suggestion: String?) {
        self.usable = usable
        self.issues = issues
        self.suggestion = suggestion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        usable = try c.decodeIfPresent(Bool.self, forKey: .usable) ?? true
        issues = try c.decodeIfPresent([String].self, forKey: .issues) ?? []
        suggestion = try c.decodeIfPresent(String.self, forKey: .suggestion)
    }
}

// MARK: - Elemental balance

struct ElementScore: Codable, Hashable, Identifiable, Sendable {
    let element: Element
    /// 0...100. The four scores are normalised to sum to 100 on decode.
    let score: Int

    var id: String { element.rawValue }

    init(element: Element, score: Int) {
        self.element = element
        self.score = score.clamped(to: 0...100)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        element = try c.decode(Element.self, forKey: .element)
        score = (try c.decodeIfPresent(Int.self, forKey: .score) ?? 25).clamped(to: 0...100)
    }

    /// Guarantees exactly one entry per element, ordered fire→earth→air→water
    /// and summing to 100 so the balance bar always renders correctly.
    static func normalized(_ scores: [ElementScore]) -> [ElementScore] {
        var byElement: [Element: Int] = [:]
        for score in scores {
            byElement[score.element, default: 0] += score.score
        }
        let total = Element.allCases.reduce(0) { $0 + (byElement[$1] ?? 0) }
        guard total > 0 else {
            return Element.allCases.map { ElementScore(element: $0, score: 25) }
        }
        var result = Element.allCases.map {
            ElementScore(element: $0, score: Int((Double(byElement[$0] ?? 0) / Double(total) * 100).rounded()))
        }
        // Absorb rounding drift into the largest bucket.
        let drift = 100 - result.reduce(0) { $0 + $1.score }
        if drift != 0, let index = result.indices.max(by: { result[$0].score < result[$1].score }) {
            result[index] = ElementScore(element: result[index].element, score: result[index].score + drift)
        }
        return result
    }
}

// MARK: - Markers

struct Marker: Codable, Hashable, Identifiable, Sendable {
    let id: String
    /// Human-readable name of the sign, e.g. "Bird near the rim".
    let name: String
    /// Machine-ish zone key drawn from `ModalityType.zoneVocabulary`.
    let zone: String
    /// What is literally visible in the image.
    let observation: String
    /// What the tradition makes of it.
    let interpretation: String
    let element: Element?
    let planet: Planet?
    let polarity: Polarity
    /// 1...5 — how strongly this marker colours the reading.
    let intensity: Int
    /// Optional normalized location, used to pin markers onto the photo.
    let boundingBox: NormalizedRect?

    enum CodingKeys: String, CodingKey {
        case id, name, zone, observation, interpretation, element, planet, polarity, intensity
        case boundingBox = "bounding_box"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        zone = (try c.decodeIfPresent(String.self, forKey: .zone) ?? "general")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        observation = try c.decode(String.self, forKey: .observation)
        interpretation = try c.decode(String.self, forKey: .interpretation)
        element = try c.decodeIfPresent(Element.self, forKey: .element)
        planet = try c.decodeIfPresent(Planet.self, forKey: .planet)
        polarity = try c.decodeIfPresent(Polarity.self, forKey: .polarity) ?? .neutral
        intensity = (try c.decodeIfPresent(Int.self, forKey: .intensity) ?? 3).clamped(to: 1...5)
        boundingBox = try c.decodeIfPresent(NormalizedRect.self, forKey: .boundingBox)
        // The model is asked for an id but we never depend on it being there.
        id = try c.decodeIfPresent(String.self, forKey: .id).flatMap { $0.isEmpty ? nil : $0 }
            ?? "\(zone)-\(name)".lowercased()
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        zone: String,
        observation: String,
        interpretation: String,
        element: Element? = nil,
        planet: Planet? = nil,
        polarity: Polarity = .neutral,
        intensity: Int = 3,
        boundingBox: NormalizedRect? = nil
    ) {
        self.id = id
        self.name = name
        self.zone = zone
        self.observation = observation
        self.interpretation = interpretation
        self.element = element
        self.planet = planet
        self.polarity = polarity
        self.intensity = intensity.clamped(to: 1...5)
        self.boundingBox = boundingBox
    }
}

/// Origin-top-left rect in 0...1 image space.
struct NormalizedRect: Codable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    func rect(in size: CGSize) -> CGRect {
        CGRect(
            x: x.clamped(to: 0...1) * size.width,
            y: y.clamped(to: 0...1) * size.height,
            width: width.clamped(to: 0...1) * size.width,
            height: height.clamped(to: 0...1) * size.height
        )
    }
}

// MARK: - Zones

struct ZoneInsight: Codable, Hashable, Identifiable, Sendable {
    /// Key from the modality vocabulary, e.g. "rim" or "mount-of-venus".
    let zone: String
    /// Presentation label, e.g. "Rim — the next few days".
    let label: String
    /// What span of time or life area this zone speaks to.
    let timeframe: String
    let summary: String
    /// 0...100 strength of the signal in this zone.
    let score: Int
    let element: Element?

    var id: String { zone }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        zone = try c.decode(String.self, forKey: .zone)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? zone.replacingOccurrences(of: "-", with: " ").capitalized
        timeframe = try c.decodeIfPresent(String.self, forKey: .timeframe) ?? ""
        summary = try c.decode(String.self, forKey: .summary)
        score = (try c.decodeIfPresent(Int.self, forKey: .score) ?? 50).clamped(to: 0...100)
        element = try c.decodeIfPresent(Element.self, forKey: .element)
    }

    init(zone: String, label: String, timeframe: String, summary: String, score: Int, element: Element?) {
        self.zone = zone
        self.label = label
        self.timeframe = timeframe
        self.summary = summary
        self.score = score.clamped(to: 0...100)
        self.element = element
    }
}

// MARK: - Guidance

struct DayGuidance: Codable, Hashable, Sendable {
    let focus: String
    let affirmation: String
    let actions: [ActionTip]
    let cautions: [String]
    let luckyColor: LuckyColor?
    let luckyNumber: Int?
    /// Free-form window, e.g. "Between 4pm and 7pm".
    let favorableWindow: String?
    /// A small ritual or adjustment to make today.
    let ritual: String?

    enum CodingKeys: String, CodingKey {
        case focus, affirmation, actions, cautions, ritual
        case luckyColor = "lucky_color"
        case luckyNumber = "lucky_number"
        case favorableWindow = "favorable_window"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        focus = try c.decode(String.self, forKey: .focus)
        affirmation = try c.decodeIfPresent(String.self, forKey: .affirmation) ?? ""
        actions = try c.decodeIfPresent([ActionTip].self, forKey: .actions) ?? []
        cautions = try c.decodeIfPresent([String].self, forKey: .cautions) ?? []
        luckyColor = try c.decodeIfPresent(LuckyColor.self, forKey: .luckyColor)
        luckyNumber = try c.decodeIfPresent(Int.self, forKey: .luckyNumber)
        favorableWindow = try c.decodeIfPresent(String.self, forKey: .favorableWindow)
        ritual = try c.decodeIfPresent(String.self, forKey: .ritual)
    }

    init(
        focus: String,
        affirmation: String,
        actions: [ActionTip],
        cautions: [String],
        luckyColor: LuckyColor?,
        luckyNumber: Int?,
        favorableWindow: String?,
        ritual: String?
    ) {
        self.focus = focus
        self.affirmation = affirmation
        self.actions = actions
        self.cautions = cautions
        self.luckyColor = luckyColor
        self.luckyNumber = luckyNumber
        self.favorableWindow = favorableWindow
        self.ritual = ritual
    }
}

struct ActionTip: Codable, Hashable, Identifiable, Sendable {
    enum Horizon: String, Codable, Sendable {
        case now, today, week

        var title: String {
            switch self {
            case .now: "Right now"
            case .today: "Today"
            case .week: "This week"
            }
        }

        init(from decoder: Decoder) throws {
            let raw = try decoder.singleValueContainer().decode(String.self)
            self = Horizon(rawValue: raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) ?? .today
        }
    }

    let title: String
    let detail: String
    let horizon: Horizon

    var id: String { title }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        horizon = try c.decodeIfPresent(Horizon.self, forKey: .horizon) ?? .today
    }

    init(title: String, detail: String, horizon: Horizon) {
        self.title = title
        self.detail = detail
        self.horizon = horizon
    }
}

struct LuckyColor: Codable, Hashable, Sendable {
    let name: String
    /// `#RRGGBB`. Falls back to white if the model returns something odd.
    let hex: String

    var color: Color { Color(hexString: hex) ?? .white }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        hex = try c.decodeIfPresent(String.self, forKey: .hex) ?? "#FFFFFF"
    }

    init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }
}
