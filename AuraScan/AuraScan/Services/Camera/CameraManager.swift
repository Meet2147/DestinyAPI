//
//  CameraManager.swift
//  AuraScan
//
//  AVFoundation capture session driving `CaptureView`. All session mutation runs
//  on a private serial queue (AVCaptureSession blocks the caller); published
//  state stays on the main actor.
//

import AVFoundation
import Combine
import OSLog
import UIKit

@MainActor
@Observable
final class CameraManager: NSObject {
    enum Status: Equatable {
        case idle
        case configuring
        case running
        case denied
        case failed(String)
    }

    private(set) var status: Status = .idle
    private(set) var isCapturing = false
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var isTorchOn = false
    private(set) var isTorchAvailable = false

    /// AVFoundation types are not `Sendable`; the session and its output are
    /// only ever touched from `sessionQueue` or from `AVCaptureVideoPreviewLayer`,
    /// which is documented as safe to attach from the main thread.
    nonisolated(unsafe) let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "ai.aurascan.camera.session")
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    private var videoInput: AVCaptureDeviceInput?
    private var isConfigured = false
    private var delegates: [Int64: PhotoCaptureDelegate] = [:]
    private let logger = Logger(subsystem: "ai.aurascan", category: "camera")

    // MARK: - Lifecycle

    /// Requests authorization, configures inputs, and starts the session.
    /// Safe to call repeatedly — configuration happens once.
    func start(preferring position: AVCaptureDevice.Position) async {
        guard await ensureAuthorized() else {
            status = .denied
            return
        }

        if status != .running { status = .configuring }
        self.position = position

        let configured = await configureIfNeeded(position: position)
        guard configured else { return }

        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.session.isRunning { self.session.startRunning() }
                continuation.resume()
            }
        }
        status = .running
        refreshTorchAvailability()
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
        if case .running = status { status = .idle }
    }

    // MARK: - Capture

    /// Captures a still and returns it upright, mirrored correctly for selfies.
    func capturePhoto() async throws -> UIImage {
        guard status == .running else {
            throw CameraError.notReady
        }
        let settings = makeSettings()
        let id = settings.uniqueID

        isCapturing = true
        // Cleanup lives here rather than in the delegate callback: hopping back
        // to the main actor from the callback would mean carrying a
        // `Result<UIImage, any Error>` across an isolation boundary, and
        // `any Error` is not Sendable. `defer` runs on the main actor already.
        defer {
            isCapturing = false
            delegates[id] = nil
        }

        // AVCapturePhotoSettings is not Sendable, and the capture has to be
        // issued from sessionQueue.
        let settingsBox = UncheckedBox(settings)

        return try await withCheckedThrowingContinuation { continuation in
            // Resuming a continuation is safe from any isolation, so the
            // delegate can call straight through without a hop.
            let delegate = PhotoCaptureDelegate { result in
                continuation.resume(with: result)
            }
            delegates[id] = delegate

            sessionQueue.async {
                self.photoOutput.capturePhoto(with: settingsBox.value, delegate: delegate)
            }
        }
    }

    private func makeSettings() -> AVCapturePhotoSettings {
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.flashMode = isTorchOn ? .on : .off
        settings.photoQualityPrioritization = .balanced
        return settings
    }

    // MARK: - Controls

    func flipCamera() async {
        let next: AVCaptureDevice.Position = position == .back ? .front : .back
        isConfigured = false
        await configureIfNeeded(position: next)
        position = next
        refreshTorchAvailability()
    }

    func toggleTorch() {
        guard let device = videoInput?.device, device.hasTorch else { return }
        isTorchOn.toggle()
        let desired = isTorchOn
        let box = UncheckedBox(device)
        sessionQueue.async {
            do {
                try box.value.lockForConfiguration()
                box.value.torchMode = desired ? .on : .off
                box.value.unlockForConfiguration()
            } catch {
                // Non-fatal: the shot still fires without the torch.
            }
        }
    }

    /// Tap-to-focus at a point in normalized (0–1) device space.
    func focus(at point: CGPoint) {
        guard let device = videoInput?.device else { return }
        let box = UncheckedBox(device)
        sessionQueue.async {
            let device = box.value
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = point
                    device.focusMode = device.isFocusModeSupported(.autoFocus) ? .autoFocus : .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = point
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch {
                // Ignore: focus is best-effort.
            }
        }
    }

    // MARK: - Configuration

    private func ensureAuthorized() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    @discardableResult
    private func configureIfNeeded(position: AVCaptureDevice.Position) async -> Bool {
        guard !isConfigured else { return true }

        let existingInput = videoInput.map(UncheckedBox.init)

        let result: Result<UncheckedBox<AVCaptureDeviceInput>, CameraError> = await withCheckedContinuation { continuation in
            sessionQueue.async {
                let session = self.session
                let photoOutput = self.photoOutput
                session.beginConfiguration()
                defer { session.commitConfiguration() }

                session.sessionPreset = .photo

                if let existingInput { session.removeInput(existingInput.value) }

                guard
                    let device = Self.device(for: position),
                    let input = try? AVCaptureDeviceInput(device: device),
                    session.canAddInput(input)
                else {
                    continuation.resume(returning: .failure(.unavailable))
                    return
                }
                session.addInput(input)

                if session.canAddOutput(photoOutput) && !session.outputs.contains(photoOutput) {
                    session.addOutput(photoOutput)
                    photoOutput.maxPhotoQualityPrioritization = .quality
                }

                if let connection = photoOutput.connection(with: .video) {
                    connection.videoRotationAngle = 90 // portrait
                    connection.isVideoMirrored = position == .front && connection.isVideoMirroringSupported
                }

                continuation.resume(returning: .success(UncheckedBox(input)))
            }
        }

        switch result {
        case let .success(input):
            videoInput = input.value
            isConfigured = true
            return true
        case let .failure(error):
            status = .failed(error.localizedDescription)
            logger.error("Camera configuration failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// `nonisolated` because it is called from `sessionQueue`, not the main
    /// actor. It touches no instance state — it is a pure device lookup — so
    /// there is nothing for the isolation to protect.
    private nonisolated static func device(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInDualWideCamera, .builtInWideAngleCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: position
        ).devices.first
    }

    private func refreshTorchAvailability() {
        isTorchAvailable = videoInput?.device.hasTorch ?? false
        if !isTorchAvailable { isTorchOn = false }
    }
}

// MARK: - Errors

enum CameraError: LocalizedError {
    case unavailable
    case notReady
    case captureFailed(String)
    case noImageData

    var errorDescription: String? {
        switch self {
        case .unavailable: "No usable camera was found on this device."
        case .notReady: "The camera is still warming up."
        case let .captureFailed(message): message
        case .noImageData: "The photo could not be read."
        }
    }
}

// MARK: - Photo delegate

/// Bridges the AVFoundation delegate callback to an async continuation. One
/// instance per capture, retained by `CameraManager` until it fires.
private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (Result<UIImage, any Error>) -> Void

    init(completion: @escaping (Result<UIImage, any Error>) -> Void) {
        self.completion = completion
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        if let error {
            completion(.failure(CameraError.captureFailed(error.localizedDescription)))
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            completion(.failure(CameraError.noImageData))
            return
        }
        completion(.success(image))
    }
}


/// Ferries a non-`Sendable` AVFoundation object onto `sessionQueue`. Safe here
/// because every use is confined to that one serial queue.
private struct UncheckedBox<T>: @unchecked Sendable {
    let value: T

    init(_ value: T) { self.value = value }
}
