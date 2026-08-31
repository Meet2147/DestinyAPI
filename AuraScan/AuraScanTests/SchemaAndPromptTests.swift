//
//  SchemaAndPromptTests.swift
//  AuraScanTests
//
//  Guards the contract between the prompts, the JSON Schema and the models.
//  These catch the failure mode that is hardest to notice: a vocabulary change
//  in one place that silently invalidates the other two.
//

import Foundation
import Testing
@testable import AuraScan

@Suite("Schema and prompt contract")
struct SchemaAndPromptTests {

    @Test("Schema serialises for every modality", arguments: ModalityType.allCases)
    func schemaSerialises(modality: ModalityType) throws {
        let schema = AnalysisSchema.jsonSchema(for: modality)
        #expect(JSONSerialization.isValidJSONObject(schema))
        let data = try JSONSerialization.data(withJSONObject: schema)
        #expect(!data.isEmpty)
    }

    @Test("Schema pins the zone enum to the modality vocabulary", arguments: ModalityType.allCases)
    func schemaPinsZones(modality: ModalityType) throws {
        let schema = AnalysisSchema.jsonSchema(for: modality)
        let markerZones = JSONBody.value(
            at: ["properties", "markers", "items", "properties", "zone", "enum"],
            in: schema
        ) as? [String]

        #expect(markerZones == modality.zoneVocabulary)
    }

    @Test("Schema pins modality to the requested one", arguments: ModalityType.allCases)
    func schemaPinsModality(modality: ModalityType) throws {
        let values = JSONBody.value(
            at: ["properties", "modality", "enum"],
            in: AnalysisSchema.jsonSchema(for: modality)
        ) as? [String]
        #expect(values == [modality.rawValue])
    }

    @Test("Every prompt names every zone in its vocabulary", arguments: ModalityType.allCases)
    func promptCoversVocabulary(modality: ModalityType) {
        let prompt = AstrologyPrompts.systemPrompt(for: modality)
        for zone in modality.zoneVocabulary {
            #expect(prompt.contains(zone), "Prompt for \(modality.rawValue) never mentions zone '\(zone)'")
        }
    }

    @Test("Every prompt states the output contract", arguments: ModalityType.allCases)
    func promptStatesContract(modality: ModalityType) {
        let prompt = AstrologyPrompts.systemPrompt(for: modality)
        #expect(prompt.contains("OUTPUT CONTRACT"))
        #expect(prompt.contains("element_balance"))
        #expect(prompt.contains("\"\(modality.rawValue)\""))
    }

    @Test("Repair context adds the correction instruction")
    func repairContext() {
        let base = ReadingContext()
        let normal = AstrologyPrompts.userPrompt(for: .palm, context: base)
        let repair = AstrologyPrompts.userPrompt(for: .palm, context: base.repairing())

        #expect(!normal.contains("not valid against the schema"))
        #expect(repair.contains("not valid against the schema"))
    }

    @Test("Focus question reaches the user prompt")
    func focusQuestionIncluded() {
        let context = ReadingContext(focusQuestion: "a decision about work")
        let prompt = AstrologyPrompts.userPrompt(for: .coffee, context: context)
        #expect(prompt.contains("a decision about work"))
    }

    @Test("Gemini sanitiser removes unsupported keywords")
    func geminiSanitiser() {
        let sanitised = GeminiProvider.sanitizedSchema(AnalysisSchema.jsonSchema(for: .face))
        let flattened = String(describing: sanitised)

        #expect(!flattened.contains("additionalProperties"))
        #expect(!flattened.contains("anyOf"))
        #expect(JSONSerialization.isValidJSONObject(sanitised))
    }

    @Test("Gemini sanitiser collapses nullable unions to the concrete type")
    func geminiCollapsesNullable() {
        let sanitised = GeminiProvider.sanitizedSchema([
            "type": "object",
            "properties": ["planet": ["anyOf": [["type": "string"], ["type": "null"]]]],
        ])
        let planetType = JSONBody.value(at: ["properties", "planet", "type"], in: sanitised) as? String
        #expect(planetType == "string")
    }
}

@Suite("Provider response parsing")
struct ProviderParsingTests {

    @Test("Anthropic parser skips thinking blocks")
    func anthropicSkipsThinking() throws {
        let json = """
        {
          "model": "claude-opus-5",
          "stop_reason": "end_turn",
          "content": [
            {"type": "thinking", "thinking": "considering the rim"},
            {"type": "text", "text": "{\\"a\\": 1}"}
          ],
          "usage": {"input_tokens": 1200, "output_tokens": 800}
        }
        """
        let completion = try AnthropicProvider.parse(Data(json.utf8))
        #expect(completion.text == #"{"a": 1}"#)
        #expect(completion.inputTokens == 1_200)
    }

    @Test("Anthropic refusal surfaces as .refused")
    func anthropicRefusal() {
        let json = """
        {"stop_reason": "refusal", "stop_details": {"type": "refusal", "explanation": "declined"}, "content": []}
        """
        #expect(throws: AIProviderError.refused("declined")) {
            try AnthropicProvider.parse(Data(json.utf8))
        }
    }

    @Test("Anthropic max_tokens surfaces as .truncated")
    func anthropicTruncated() {
        let json = #"{"stop_reason": "max_tokens", "content": [{"type": "text", "text": "{"}]}"#
        #expect(throws: AIProviderError.truncated) {
            try AnthropicProvider.parse(Data(json.utf8))
        }
    }

    @Test("OpenAI refusal surfaces as .refused")
    func openAIRefusal() {
        let json = """
        {"choices": [{"finish_reason": "stop", "message": {"refusal": "no"}}]}
        """
        #expect(throws: AIProviderError.refused("no")) {
            try OpenAIProvider.parse(Data(json.utf8))
        }
    }

    @Test("Gemini blocked prompt surfaces as .refused")
    func geminiBlocked() {
        let json = #"{"promptFeedback": {"blockReason": "SAFETY"}}"#
        #expect(throws: AIProviderError.refused("Blocked: SAFETY")) {
            try GeminiProvider.parse(Data(json.utf8), requestedModel: "gemini-2.0-flash")
        }
    }

    @Test("Rate limit honours retry-after, capped at 30s")
    func backoffHonoursRetryAfter() {
        let delay = VisionAnalysisService.backoffDelay(attempt: 1, error: .rateLimited(retryAfter: 12))
        #expect(delay == 12)

        let capped = VisionAnalysisService.backoffDelay(attempt: 1, error: .rateLimited(retryAfter: 600))
        #expect(capped == 30)
    }

    @Test("Backoff grows and stays bounded")
    func backoffGrows() {
        let first = VisionAnalysisService.backoffDelay(attempt: 1, error: .server(status: 503, message: nil))
        let third = VisionAnalysisService.backoffDelay(attempt: 3, error: .server(status: 503, message: nil))
        #expect(first < third)
        #expect(third <= 16)
    }

    @Test("Only transient failures are retryable")
    func retryClassification() {
        #expect(AIProviderError.rateLimited(retryAfter: nil).isRetryable)
        #expect(AIProviderError.server(status: 500, message: nil).isRetryable)
        #expect(!AIProviderError.client(status: 400, message: nil).isRetryable)
        #expect(!AIProviderError.missingAPIKey(.anthropic).isRetryable)
        #expect(!AIProviderError.refused(nil).isRetryable)
    }
}
