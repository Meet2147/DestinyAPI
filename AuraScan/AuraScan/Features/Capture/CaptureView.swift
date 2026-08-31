//
//  CaptureView.swift
//  AuraScan
//
//  Camera capture with a modality-specific guide, a review step, and the
//  analysis handoff.
//

import AVFoundation
import PhotosUI
import SwiftUI

struct CaptureView: View {
    let modality: ModalityType
    @Binding var path: NavigationPath

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CaptureViewModel?
    @State private var showsTips = true
    @State private var isShutterPressed = false

    var body: some View {
        ZStack {
            Theme.Palette.void.ignoresSafeArea()

            if let viewModel {
                content(viewModel)
                    .transition(.opacity)
            } else {
                ProgressView().tint(Theme.Palette.aura)
            }
        }
        .navigationTitle(modality.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = CaptureViewModel(
                    modality: modality,
                    analyzer: environment.analyzer,
                    repository: environment.repository
                )
            }
            await viewModel?.startCamera()
        }
        .onDisappear { viewModel?.tearDown() }
        .onChange(of: viewModel?.result) { _, payload in
            guard let payload else { return }
            path.append(Route.result(payload))
        }
    }

    // MARK: - Phases

    @ViewBuilder
    private func content(_ viewModel: CaptureViewModel) -> some View {
        switch viewModel.phase {
        case .framing:
            framingView(viewModel, bindable: Bindable(viewModel))
        case .reviewing:
            reviewView(viewModel, bindable: Bindable(viewModel))
        case .analyzing:
            AnalyzingView(modality: modality) { viewModel.cancelAnalysis() }
        case let .failed(message, recovery):
            failureView(message: message, recovery: recovery, viewModel: viewModel)
        }
    }

    private func framingView(_ viewModel: CaptureViewModel, bindable: Bindable<CaptureViewModel>) -> some View {
        ZStack {
            switch viewModel.camera.status {
            case .running, .configuring:
                CameraPreviewView(session: viewModel.camera.session) { point in
                    viewModel.camera.focus(at: point)
                }
                .ignoresSafeArea()
            case .denied:
                permissionDenied
            case let .failed(message):
                unavailable(message)
            case .idle:
                Color.black.ignoresSafeArea()
            }

            CaptureGuideOverlay(modality: modality)
                .ignoresSafeArea()

            VStack {
                if showsTips { tipsCard }
                Spacer()
                shutterBar(viewModel, bindable: bindable)
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.bottom, Theme.Spacing.md)
        }
    }

    private var tipsCard: some View {
        GlassCard(tint: modality.accent, cornerRadius: Theme.Radius.medium) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                HStack {
                    Text(modality.captureHeadline)
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.starlight)
                    Spacer()
                    Button {
                        withAnimation(.spring(duration: 0.3)) { showsTips = false }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.Palette.dusk)
                    }
                    .accessibilityLabel("Hide framing tips")
                }
                ForEach(modality.captureTips, id: \.self) { tip in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(modality.accent)
                            .frame(width: 4, height: 4)
                            .padding(.top, 6)
                        Text(tip)
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.moonlight)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func shutterBar(_ viewModel: CaptureViewModel, bindable: Bindable<CaptureViewModel>) -> some View {
        HStack(spacing: Theme.Spacing.lg) {
            PhotosPicker(selection: bindable.photosSelection, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Palette.starlight)
                    .frame(width: 52, height: 52)
                    .softRaised(Circle(), depth: .medium)
            }
            .accessibilityLabel("Choose from library")

            // The shutter is the one control that must feel mechanical: an
            // extruded button seated in a recessed collar, sinking on press.
            Button {
                Task { await viewModel.capture() }
            } label: {
                ZStack {
                    Circle()
                        .fill(.clear)
                        .frame(width: 82, height: 82)
                        .softRecessed(Circle(), depth: .medium)

                    Circle()
                        .fill(
                            LinearGradient(colors: modality.gradient, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 62, height: 62)
                        .shadow(color: SoftDepth.highlight, radius: 6, x: -3, y: -3)
                        .shadow(color: SoftDepth.shade, radius: 8, x: 3, y: 4)
                        .shadow(color: modality.accent.opacity(0.5), radius: 16)
                        .scaleEffect(isShutterPressed ? 0.92 : 1)
                        .animation(.spring(duration: 0.2), value: isShutterPressed)

                    if viewModel.camera.isCapturing {
                        ProgressView().tint(Theme.Palette.void)
                    }
                }
            }
            .disabled(viewModel.camera.status != .running || viewModel.camera.isCapturing)
            .onLongPressGesture(minimumDuration: 0, pressing: { isShutterPressed = $0 }, perform: {})
            .accessibilityLabel("Take photo")

            Button {
                Task { await viewModel.camera.flipCamera() }
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.Palette.starlight)
                    .frame(width: 52, height: 52)
                    .softRaised(Circle(), depth: .medium)
            }
            .accessibilityLabel("Switch camera")
        }
    }

    // MARK: - Review

    private func reviewView(_ viewModel: CaptureViewModel, bindable: Bindable<CaptureViewModel>) -> some View {
        ZStack {
            CosmicBackground(accent: modality.accent)

            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    if let image = viewModel.image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
                            .padding(6)
                            .softRecessed(
                                RoundedRectangle(cornerRadius: Theme.Radius.large + 6, style: .continuous),
                                depth: .medium
                            )
                    }

                    GlassCard(tint: modality.accent) {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text("Anything on your mind?")
                                .font(Theme.Font.headline)
                                .foregroundStyle(Theme.Palette.starlight)
                            Text("Optional. A focus sharpens the guidance without changing what's read in the image.")
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Palette.dusk)

                            TextField("e.g. a decision about work", text: bindable.focusQuestion, axis: .vertical)
                                .textFieldStyle(.plain)
                                .font(Theme.Font.body)
                                .foregroundStyle(Theme.Palette.starlight)
                                .lineLimit(1...3)
                                .padding(Theme.Spacing.sm)
                                .softRecessedField()

                            modalityExtras(bindable: bindable)
                        }
                    }

                    Button("Read this \(modality == .space ? "space" : "image")") {
                        viewModel.analyze()
                    }
                    .buttonStyle(AuraButtonStyle(colors: modality.gradient))
                    .disabled(!environment.hasCredentials)

                    if !environment.hasCredentials {
                        Text("Add an API key in Settings first.")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Palette.gold)
                    }

                    Button("Retake") { viewModel.retake() }
                        .buttonStyle(AuraButtonStyle(isProminent: false))
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func modalityExtras(bindable: Bindable<CaptureViewModel>) -> some View {
        switch modality {
        case .palm:
            Picker("Hand", selection: bindable.handedness) {
                Text("Dominant hand").tag(ReadingContext.Handedness.dominant)
                Text("Other hand").tag(ReadingContext.Handedness.nonDominant)
            }
            .pickerStyle(.segmented)
        case .space:
            TextField("What is this space? e.g. home office", text: bindable.roomKind)
                .textFieldStyle(.plain)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.starlight)
                .padding(Theme.Spacing.sm)
                .softRecessedField()
        case .face, .coffee:
            EmptyView()
        }
    }

    // MARK: - Failure states

    private func failureView(message: String, recovery: String?, viewModel: CaptureViewModel) -> some View {
        ZStack {
            CosmicBackground(accent: .orange)
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Theme.Palette.gold)
                Text("The reading didn't come through")
                    .font(Theme.Font.title)
                    .foregroundStyle(Theme.Palette.starlight)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Palette.moonlight)
                    .multilineTextAlignment(.center)
                if let recovery {
                    Text(recovery)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: Theme.Spacing.sm) {
                    if viewModel.image != nil {
                        Button("Try again") { viewModel.analyze() }
                            .buttonStyle(AuraButtonStyle(colors: modality.gradient))
                    }
                    Button("Retake photo") { viewModel.retake() }
                        .buttonStyle(AuraButtonStyle(isProminent: false))
                }
                .padding(.top, Theme.Spacing.sm)
            }
            .padding(Theme.Spacing.lg)
        }
    }

    private var permissionDenied: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "camera.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.Palette.dusk)
            Text("Camera access is off")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Palette.starlight)
            Text("AuraScan needs the camera to take a reading. You can still choose an existing photo from your library.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.moonlight)
                .multilineTextAlignment(.center)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(AuraButtonStyle(colors: modality.gradient))
        }
        .padding(Theme.Spacing.lg)
    }

    private func unavailable(_ message: String) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 30))
                .foregroundStyle(Theme.Palette.dusk)
            Text(message)
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.moonlight)
                .multilineTextAlignment(.center)
            Text("Choose a photo from your library instead.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.dusk)
        }
        .padding(Theme.Spacing.lg)
    }
}

#Preview {
    NavigationStack {
        CaptureView(modality: .coffee, path: .constant(NavigationPath()))
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
