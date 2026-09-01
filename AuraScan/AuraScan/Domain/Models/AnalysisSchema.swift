//
//  AnalysisSchema.swift
//  AuraScan
//
//  A hand-maintained JSON Schema mirroring `AnalysisResponse`. Providers that
//  support constrained decoding (Anthropic `output_config.format`, OpenAI
//  `response_format.json_schema`, Gemini `responseSchema`) are handed this so
//  malformed JSON never reaches the decoder in the first place.
//
//  Keep it in sync with `AnalysisResponse` — `SchemaAndPromptTests` asserts that
//  the zone enums match `ModalityType.zoneVocabulary`.
//
//  Anthropic's constrained decoding accepts only a subset of JSON Schema, and
//  rejects the whole request rather than ignoring what it does not know:
//
//      minimum / maximum   unsupported on number AND integer
//      maxItems            unsupported
//      minItems            only 0 or 1
//
//  `maxLength`, `enum`, `anyOf`, `description` and nullable type arrays are
//  fine. So ranges and counts are expressed as `description` text, which the
//  model honours, and enforced for real in `AnalysisResponse`, which clamps
//  every numeric field as it decodes.
//
//  The schema is assembled from small fragments rather than one literal: a
//  single nested `[String: Any]` this large is a well-known way to stall the
//  type checker.
//

import Foundation

enum AnalysisSchema {
    static let name = "aurascan_reading"

    /// Draft 2020-12 subset accepted by all three providers.
    static func jsonSchema(for modality: ModalityType) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["modality"] = ["type": "string", "enum": [modality.rawValue]]
        properties["confidence"] = boundedNumber(0, 1, "how confident the reading is")
        properties["image_quality"] = imageQuality
        properties["headline"] = ["type": "string", "maxLength": 80]
        properties["summary"] = ["type": "string"]
        properties["dominant_element"] = elementEnum
        properties["element_balance"] = elementBalance
        properties["energy_score"] = boundedInteger(0, 100)
        properties["markers"] = markers(for: modality)
        properties["zones"] = zones(for: modality)
        properties["guidance"] = guidance

        return object(
            properties: properties,
            required: [
                "modality", "confidence", "image_quality", "headline", "summary",
                "dominant_element", "element_balance", "energy_score",
                "markers", "zones", "guidance",
            ]
        )
    }

    // MARK: - Fragments

    private static var imageQuality: [String: Any] {
        object(
            properties: [
                "usable": ["type": "boolean"],
                "issues": ["type": "array", "items": ["type": "string"]],
                "suggestion": nullableString,
            ],
            required: ["usable", "issues", "suggestion"]
        )
    }

    private static var elementBalance: [String: Any] {
        let entry = object(
            properties: ["element": elementEnum, "score": boundedInteger(0, 100)],
            required: ["element", "score"]
        )
        return array(of: entry, min: 4, max: 4, what: "entries, one per element")
    }

    private static func markers(for modality: ModalityType) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["id"] = ["type": "string"]
        properties["name"] = ["type": "string", "maxLength": 60]
        properties["zone"] = ["type": "string", "enum": modality.zoneVocabulary]
        properties["observation"] = ["type": "string"]
        properties["interpretation"] = ["type": "string"]
        properties["element"] = nullable(elementEnum)
        properties["planet"] = nullable(planetEnum)
        properties["polarity"] = ["type": "string", "enum": Polarity.allCases.map(\.rawValue)]
        properties["intensity"] = boundedInteger(1, 5)
        properties["bounding_box"] = nullable(boundingBox)

        let item = object(
            properties: properties,
            required: [
                "id", "name", "zone", "observation", "interpretation",
                "element", "planet", "polarity", "intensity", "bounding_box",
            ]
        )
        return array(of: item, min: 3, max: 12, what: "markers")
    }

    private static var boundingBox: [String: Any] {
        let unitInterval = boundedNumber(0, 1, "fraction of the image edge")
        return object(
            properties: [
                "x": unitInterval,
                "y": unitInterval,
                "width": unitInterval,
                "height": unitInterval,
            ],
            required: ["x", "y", "width", "height"]
        )
    }

    private static func zones(for modality: ModalityType) -> [String: Any] {
        var properties: [String: Any] = [:]
        properties["zone"] = ["type": "string", "enum": modality.zoneVocabulary]
        properties["label"] = ["type": "string"]
        properties["timeframe"] = ["type": "string"]
        properties["summary"] = ["type": "string"]
        properties["score"] = boundedInteger(0, 100)
        properties["element"] = nullable(elementEnum)

        let item = object(
            properties: properties,
            required: ["zone", "label", "timeframe", "summary", "score", "element"]
        )
        return array(of: item, min: 3, what: "zones")
    }

    private static var guidance: [String: Any] {
        var properties: [String: Any] = [:]
        properties["focus"] = ["type": "string"]
        properties["affirmation"] = ["type": "string"]
        properties["actions"] = actions
        properties["cautions"] = array(of: ["type": "string"], min: 0, max: 3,
                                       what: "short cautions")
        properties["lucky_color"] = nullable(luckyColor)
        properties["lucky_number"] = [
            "type": ["integer", "null"],
            "description": "Integer from 0 to 99, or null.",
        ]
        properties["favorable_window"] = nullableString
        properties["ritual"] = nullableString

        return object(
            properties: properties,
            required: [
                "focus", "affirmation", "actions", "cautions",
                "lucky_color", "lucky_number", "favorable_window", "ritual",
            ]
        )
    }

    private static var actions: [String: Any] {
        let item = object(
            properties: [
                "title": ["type": "string", "maxLength": 60],
                "detail": ["type": "string"],
                "horizon": ["type": "string", "enum": ["now", "today", "week"]],
            ],
            required: ["title", "detail", "horizon"]
        )
        return array(of: item, min: 2, max: 5, what: "actions")
    }

    private static var luckyColor: [String: Any] {
        object(
            properties: [
                "name": ["type": "string"],
                "hex": ["type": "string", "pattern": "^#[0-9A-Fa-f]{6}$"],
            ],
            required: ["name", "hex"]
        )
    }

    // MARK: - Primitives

    private static var elementEnum: [String: Any] {
        ["type": "string", "enum": Element.allCases.map(\.rawValue)]
    }

    private static var planetEnum: [String: Any] {
        ["type": "string", "enum": Planet.allCases.map(\.rawValue)]
    }

    private static var nullableString: [String: Any] {
        ["type": ["string", "null"]]
    }

    /// The range lives in `description` because the numeric bounds keywords are
    /// rejected outright. `AnalysisResponse` clamps on decode regardless.
    private static func boundedInteger(_ minimum: Int, _ maximum: Int) -> [String: Any] {
        ["type": "integer", "description": "Integer from \(minimum) to \(maximum)."]
    }

    private static func boundedNumber(_ minimum: Double, _ maximum: Double,
                                      _ note: String? = nil) -> [String: Any] {
        var text = "Number from \(minimum) to \(maximum)."
        if let note { text += " \(note.prefix(1).capitalized + note.dropFirst())." }
        return ["type": "number", "description": text]
    }

    /// `maxItems` is rejected and `minItems` accepts only 0 or 1, so an exact
    /// count is stated in `description` instead.
    private static func array(of item: [String: Any], min: Int, max: Int? = nil,
                              what: String) -> [String: Any] {
        let count: String
        if let max {
            count = min == max ? "Exactly \(min) \(what)."
                               : "Between \(min) and \(max) \(what)."
        } else {
            count = "At least \(min) \(what)."
        }
        var schema: [String: Any] = ["type": "array", "items": item,
                                     "description": count]
        if min >= 1 { schema["minItems"] = 1 }
        return schema
    }

    private static func object(properties: [String: Any], required: [String]) -> [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": required,
            "properties": properties,
        ]
    }

    /// `anyOf` keeps nullability expressible for object-valued fields, which the
    /// `"type": [..., "null"]` shorthand cannot cover under strict validation.
    private static func nullable(_ schema: [String: Any]) -> [String: Any] {
        ["anyOf": [schema, ["type": "null"]]]
    }

    /// Compact, deterministic rendering of the schema — useful when debugging a
    /// provider that rejects it.
    static func prettyPrinted(for modality: ModalityType) -> String {
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: jsonSchema(for: modality),
                options: [.prettyPrinted, .sortedKeys]
            ),
            let string = String(data: data, encoding: .utf8)
        else {
            return "{}"
        }
        return string
    }
}
