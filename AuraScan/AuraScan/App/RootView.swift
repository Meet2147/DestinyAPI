//
//  RootView.swift
//  AuraScan
//
//  Owns navigation. A reading is a linear flow — pick a modality, capture,
//  analyse, read the result — so the whole thing is one NavigationStack path.
//

import SwiftUI

/// Destinations pushed onto the root stack.
enum Route: Hashable {
    case capture(ModalityType)
    case analyzing(ModalityType)
    case result(ReadingPayload)
    case history
    case settings
}

/// Wraps a finished analysis so it can travel through `NavigationPath`.
struct ReadingPayload: Hashable {
    let id: UUID
    let modality: ModalityType
    let analysis: AnalysisResponse
    let imageData: Data?
    /// Nil for readings replayed from history (already persisted).
    let isFreshlySaved: Bool

    static func == (lhs: ReadingPayload, rhs: ReadingPayload) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeDashboardView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .capture(modality):
                        CaptureView(modality: modality, path: $path)
                    case let .analyzing(modality):
                        // Analysis is presented from CaptureView with its image in
                        // hand; this case exists so deep links stay total.
                        CaptureView(modality: modality, path: $path)
                    case let .result(payload):
                        ReadingResultView(payload: payload, path: $path)
                    case .history:
                        HistoryView(path: $path)
                    case .settings:
                        SettingsView()
                    }
                }
        }
        .tint(Theme.Palette.aura)
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment.preview())
}
