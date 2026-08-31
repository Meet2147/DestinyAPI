//
//  AuraScanApp.swift
//  AuraScan
//

import SwiftData
import SwiftUI

@main
struct AuraScanApp: App {
    @State private var environment: AppEnvironment

    init() {
        let container = ModelContainer.aurascan()
        _environment = State(initialValue: AppEnvironment(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .modelContainer(environment.container)
                .preferredColorScheme(.dark)
                .tint(Theme.Palette.aura)
        }
    }
}
