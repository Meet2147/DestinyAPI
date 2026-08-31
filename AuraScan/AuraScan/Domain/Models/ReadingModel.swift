//
//  ReadingModel.swift
//  AuraScan
//
//  SwiftData record for a completed reading. The full `AnalysisResponse` is
//  archived as JSON rather than being shredded into relationships: readings are
//  immutable once written, and storing the payload verbatim means a schema
//  addition never migrates history.
//

import Foundation
import SwiftData

@Model
final class Reading {
    /// Stable identity used by share links and NavigationPath.
    @Attribute(.unique) var id: UUID
    var createdAt: Date

    /// `ModalityType.rawValue`. Stored raw so SwiftData never needs the enum.
    var modalityRaw: String

    /// Full-size capture, kept out of the store file.
    @Attribute(.externalStorage) var imageData: Data?
    /// Small square JPEG for lists and the share card.
    @Attribute(.externalStorage) var thumbnailData: Data?

    /// JSON-encoded `AnalysisResponse`.
    @Attribute(.externalStorage) var analysisData: Data

    // Denormalised for cheap sorting/filtering without decoding the payload.
    var headline: String
    var dominantElementRaw: String
    var energyScore: Int

    var isFavorite: Bool
    var note: String?

    /// Which provider/model produced this reading, for reproducibility.
    var providerRaw: String
    var modelIdentifier: String

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        modality: ModalityType,
        analysis: AnalysisResponse,
        imageData: Data?,
        thumbnailData: Data?,
        provider: AIProviderID,
        modelIdentifier: String,
        isFavorite: Bool = false,
        note: String? = nil
    ) throws {
        self.id = id
        self.createdAt = createdAt
        self.modalityRaw = modality.rawValue
        self.imageData = imageData
        self.thumbnailData = thumbnailData
        self.analysisData = try Reading.encoder.encode(analysis)
        self.headline = analysis.headline
        self.dominantElementRaw = analysis.dominantElement.rawValue
        self.energyScore = analysis.energyScore
        self.isFavorite = isFavorite
        self.note = note
        self.providerRaw = provider.rawValue
        self.modelIdentifier = modelIdentifier
    }

    // MARK: - Derived

    var modality: ModalityType {
        ModalityType(rawValue: modalityRaw) ?? .face
    }

    var dominantElement: Element {
        Element(rawValue: dominantElementRaw) ?? .air
    }

    var provider: AIProviderID {
        AIProviderID(rawValue: providerRaw) ?? .anthropic
    }

    /// Decoded payload. Returns `nil` only if the archive predates a breaking
    /// model change; callers fall back to the denormalised columns.
    var analysis: AnalysisResponse? {
        try? Reading.decoder.decode(AnalysisResponse.self, from: analysisData)
    }

    // MARK: - Coders

    nonisolated(unsafe) static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    nonisolated(unsafe) static let decoder = JSONDecoder()
}
