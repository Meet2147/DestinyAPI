//
//  JSONExtractionTests.swift
//  AuraScanTests
//
//  The extractor is the last line of defence when a provider ignores the
//  schema and wraps its JSON in prose or fences.
//

import Foundation
import Testing
@testable import AuraScan

@Suite("JSON extraction")
struct JSONExtractionTests {

    @Test("Returns a bare object unchanged")
    func bareObject() {
        let extracted = VisionAnalysisService.extractJSONObject(from: #"{"a": 1}"#)
        #expect(extracted == #"{"a": 1}"#)
    }

    @Test("Strips a fenced code block")
    func fencedBlock() {
        let raw = """
        ```json
        {"a": 1, "b": {"c": 2}}
        ```
        """
        #expect(VisionAnalysisService.extractJSONObject(from: raw) == #"{"a": 1, "b": {"c": 2}}"#)
    }

    @Test("Ignores prose around the object")
    func prose() {
        let raw = "Here is your reading:\n{\"a\": 1}\nHope that helps!"
        #expect(VisionAnalysisService.extractJSONObject(from: raw) == #"{"a": 1}"#)
    }

    @Test("Braces inside strings do not end the object")
    func bracesInStrings() {
        let raw = #"{"note": "a } inside", "n": 1}"#
        #expect(VisionAnalysisService.extractJSONObject(from: raw) == raw)
    }

    @Test("Escaped quotes do not confuse the scanner")
    func escapedQuotes() {
        let raw = #"{"note": "he said \"} \" loudly", "n": 1}"#
        #expect(VisionAnalysisService.extractJSONObject(from: raw) == raw)
    }

    @Test("Returns nil when the object never closes")
    func unbalanced() {
        #expect(VisionAnalysisService.extractJSONObject(from: #"{"a": 1"#) == nil)
    }

    @Test("Returns nil when there is no object at all")
    func noObject() {
        #expect(VisionAnalysisService.extractJSONObject(from: "I can't read this image.") == nil)
    }
}
