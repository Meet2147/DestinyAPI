//
//  ReadingRepository.swift
//  AuraScan
//
//  SwiftData access for readings. `@Model` objects are not `Sendable`, so the
//  repository is main-actor bound and views hold the models directly.
//

import Foundation
import OSLog
import SwiftData
import UIKit

@MainActor
protocol ReadingStoring {
    @discardableResult
    func save(
        analysis: AnalysisResult,
        modality: ModalityType,
        image: UIImage?
    ) throws -> Reading

    func recent(limit: Int) throws -> [Reading]
    func all(modality: ModalityType?) throws -> [Reading]
    func favorites() throws -> [Reading]
    func delete(_ reading: Reading) throws
    func toggleFavorite(_ reading: Reading) throws
    func setNote(_ note: String?, on reading: Reading) throws
}

@MainActor
final class ReadingRepository: ReadingStoring {
    private let context: ModelContext
    private let imageProcessor: any ImageProcessing
    private let logger = Logger(subsystem: "ai.aurascan", category: "store")

    init(context: ModelContext, imageProcessor: any ImageProcessing = ImageProcessor()) {
        self.context = context
        self.imageProcessor = imageProcessor
    }

    @discardableResult
    func save(
        analysis: AnalysisResult,
        modality: ModalityType,
        image: UIImage?
    ) throws -> Reading {
        let reading = try Reading(
            modality: modality,
            analysis: analysis.response,
            imageData: image.flatMap(imageProcessor.archiveData),
            thumbnailData: image.flatMap(imageProcessor.thumbnailData),
            provider: analysis.provider,
            modelIdentifier: analysis.model
        )
        context.insert(reading)
        try context.save()
        logger.info("Saved \(modality.rawValue, privacy: .public) reading")
        return reading
    }

    func recent(limit: Int) throws -> [Reading] {
        var descriptor = FetchDescriptor<Reading>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func all(modality: ModalityType?) throws -> [Reading] {
        let descriptor: FetchDescriptor<Reading>
        if let modality {
            let raw = modality.rawValue
            descriptor = FetchDescriptor<Reading>(
                predicate: #Predicate { $0.modalityRaw == raw },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<Reading>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        }
        return try context.fetch(descriptor)
    }

    func favorites() throws -> [Reading] {
        try context.fetch(
            FetchDescriptor<Reading>(
                predicate: #Predicate { $0.isFavorite },
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    func delete(_ reading: Reading) throws {
        context.delete(reading)
        try context.save()
    }

    func toggleFavorite(_ reading: Reading) throws {
        reading.isFavorite.toggle()
        try context.save()
    }

    func setNote(_ note: String?, on reading: Reading) throws {
        reading.note = note?.isEmpty == true ? nil : note
        try context.save()
    }
}
