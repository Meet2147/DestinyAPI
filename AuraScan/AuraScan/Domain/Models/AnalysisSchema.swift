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
        properties["confidence"] = ["type": "number", "minimum": 0, "maximum": 1]
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
        return ["type": "array", "minItems": 4, "maxItems": 4, "items": entry]
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
        return ["type": "array", "minItems": 3, "maxItems": 12, "items": item]
    }

    private static var boundingBox: [String: Any] {
        let unitInterval: [String: Any] = ["type": "number", "minimum": 0, "maximum": 1]
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
        return ["type": "array", "minItems": 3, "items": item]
    }

    private static var guidance: [String: Any] {
        var properties: [String: Any] = [:]
        properties["focus"] = ["type": "string"]
        properties["affirmation"] = ["type": "string"]
        properties["actions"] = actions
        properties["cautions"] = ["type": "array", "items": ["type": "string"], "maxItems": 3]
        properties["lucky_color"] = nullable(luckyColor)
        properties["lucky_number"] = ["type": ["integer", "null"], "minimum": 0, "maximum": 99]
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
        return ["type": "array", "minItems": 2, "maxItems": 5, "items": item]
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

    private static func boundedInteger(_ minimum: Int, _ maximum: Int) -> [String: Any] {
        ["type": "integer", "minimum": minimum, "maximum": maximum]
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
