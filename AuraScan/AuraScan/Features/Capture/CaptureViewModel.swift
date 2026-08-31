//
//  CaptureViewModel.swift
//  AuraScan
//
//  Owns the capture → analyse → persist pipeline for one modality.
//

import Foundation
import Observation
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class CaptureViewModel {
    enum Phase: Equatable {
        case framing
        case reviewing
        case analyzing
        case failed(message: String, recovery: String?)
    }

    let modality: ModalityType

    private(set) var phase: Phase = .framing
    private(set) var image: UIImage?
    private(set) var result: ReadingPayload?

    var focusQuestion = ""
    var roomKind = ""
    var handedness: ReadingContext.Handedness = .dominant
    var photosSelection: PhotosPickerItem? {
        didSet { Task { await loadPickedPhoto() } }
    }

    let camera = CameraManager()

    private let analyzer: any VisionAnalyzing
    private let repository: any ReadingStoring
    private let imageProcessor: any ImageProcessing
    private var analysisTask: Task<Void, Never>?

    init(
        modality: ModalityType,
        analyzer: any VisionAnalyzing,
        repository: any ReadingStoring,
        imageProcessor: any ImageProcessing = ImageProcessor()
    ) {
        self.modality = modality
        self.analyzer = analyzer
        self.repository = repository
        self.imageProcessor = imageProcessor
    }

    // MARK: - Camera

    func startCamera() async {
        // Selfies for face readings, rear camera for everything else.
        await camera.start(preferring: modality == .face ? .front : .back)
    }

    func stopCamera() {
        camera.stop()
    }

    func capture() async {
        do {
            let captured = try await camera.capturePhoto()
            image = captured
            phase = .reviewing
            camera.stop()
        } catch {
            phase = .failed(message: error.localizedDescription, recovery: "Try the shutter again.")
        }
    }

    func retake() {
        image = nil
        result = nil
        phase = .framing
        Task { await startCamera() }
    }

    private func loadPickedPhoto() async {
        guard let photosSelection else { return }
        do {
            guard
                let data = try await photosSelection.loadTransferable(type: Data.self),
                let picked = UIImage(data: data)
            else {
                phase = .failed(message: "That photo could not be opened.", recovery: "Pick a different image.")
                return
            }
            image = picked
            phase = .reviewing
            camera.stop()
        } catch {
            phase = .failed(message: error.localizedDescription, recovery: "Pick a different image.")
        }
    }

    // MARK: - Analysis

    func analyze() {
        guard let image else { return }
        analysisTask?.cancel()
        phase = .analyzing

        analysisTask = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await analyzer.analyze(
                    image: image,
                    modality: modality,
                    context: makeContext()
                )
                guard !Task.isCancelled else { return }

                let saved = try repository.save(analysis: result, modality: modality, image: image)
                self.result = ReadingPayload(
                    id: saved.id,
                    modality: modality,
                    analysis: result.response,
                    imageData: saved.imageData,
                    isFreshlySaved: true
                )
            } catch is CancellationError {
                phase = .framing
            } catch let error as AnalysisError {
                phase = .failed(message: error.localizedDescription, recovery: error.recoverySuggestion)
            } catch {
                phase = .failed(message: error.localizedDescription, recovery: nil)
            }
        }
    }

    /// Called when the view disappears — `deinit` cannot touch main-actor state.
    func tearDown() {
        analysisTask?.cancel()
        analysisTask = nil
        camera.stop()
    }

    func cancelAnalysis() {
        analysisTask?.cancel()
        analysisTask = nil
        phase = image == nil ? .framing : .reviewing
    }

    func dismissError() {
        phase = image == nil ? .framing : .reviewing
    }

    private func makeContext() -> ReadingContext {
        ReadingContext(
            timestamp: .now,
            focusQuestion: focusQuestion.isEmpty ? nil : focusQuestion,
            handedness: modality == .palm ? handedness : nil,
            roomKind: modality == .space && !roomKind.isEmpty ? roomKind : nil
        )
    }
}
