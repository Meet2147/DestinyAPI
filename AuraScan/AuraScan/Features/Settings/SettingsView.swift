//
//  SettingsView.swift
//  AuraScan
//
//  Provider selection and API key entry. Keys go straight to the Keychain and
//  are never rendered back — only a "set / not set" state is shown.
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment

    @State private var draftKey = ""
    @State private var draftModel = ""
    @State private var status: Status?
    @State private var isEditingKey = false

    private enum Status: Equatable {
        case saved
        case cleared
        case failed(String)
    }

    var body: some View {
        @Bindable var environment = environment

        ZStack {
            CosmicBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    providerSection(environment: environment)
                    keySection
                    modelSection(environment: environment)
                    aboutSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear { draftModel = environment.modelIdentifier }
        .onChange(of: environment.providerID) { _, _ in
            draftModel = environment.modelIdentifier
            draftKey = ""
            isEditingKey = false
            status = nil
        }
    }

    // MARK: - Sections

    private func providerSection(environment: AppEnvironment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Vision provider", subtitle: "Which service analyses your images")

            GlassCard {
                VStack(spacing: 0) {
                    ForEach(AIProviderID.allCases) { provider in
                        Button {
                            environment.providerID = provider
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.title)
                                        .font(Theme.Font.callout)
                                        .foregroundStyle(Theme.Palette.starlight)
                                    Text(provider.defaultModel)
                                        .font(Theme.Font.mono)
                                        .foregroundStyle(Theme.Palette.dusk)
                                }
                                Spacer()
                                if environment.secretStore.hasAPIKey(for: provider) {
                                    Image(systemName: "key.fill")
                                        .font(.caption)
                                        .foregroundStyle(Theme.Palette.gold)
                                }
                                Image(systemName: environment.providerID == provider ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(environment.providerID == provider ? Theme.Palette.aura : Theme.Palette.dusk)
                            }
                            .padding(.vertical, Theme.Spacing.xs)
                        }
                        .buttonStyle(.plain)

                        if provider != AIProviderID.allCases.last {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "API key", subtitle: "Stored in the iOS Keychain on this device")

            GlassCard(tint: Theme.Palette.gold) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: environment.hasCredentials ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(environment.hasCredentials ? Theme.Palette.glow : Theme.Palette.gold)
                        Text(environment.hasCredentials ? "A key is set for \(environment.providerID.title)" : "No key set")
                            .font(Theme.Font.callout)
                            .foregroundStyle(Theme.Palette.starlight)
                    }

                    if isEditingKey || !environment.hasCredentials {
                        SecureField("Paste your API key", text: $draftKey)
                            .textFieldStyle(.plain)
                            .font(Theme.Font.mono)
                            .foregroundStyle(Theme.Palette.starlight)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(Theme.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                    .fill(Theme.Palette.void.opacity(0.6))
                            )

                        Button("Save key") { saveKey() }
                            .buttonStyle(AuraButtonStyle())
                            .disabled(draftKey.trimmingCharacters(in: .whitespaces).isEmpty)
                    } else {
                        HStack(spacing: Theme.Spacing.sm) {
                            Button("Replace") { isEditingKey = true }
                                .buttonStyle(AuraButtonStyle(isProminent: false))
                            Button("Remove", role: .destructive) { clearKey() }
                                .buttonStyle(AuraButtonStyle(isProminent: false))
                        }
                    }

                    if let status {
                        statusLabel(status)
                    }

                    Text("Your key never leaves this device except in requests to \(environment.providerID.title). Images are sent to that provider for analysis and are not stored by AuraScan anywhere but locally.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func modelSection(environment: AppEnvironment) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Model", subtitle: "Must support image input")

            GlassCard {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    TextField("Model identifier", text: $draftModel)
                        .textFieldStyle(.plain)
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.Palette.starlight)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(Theme.Spacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                .fill(Theme.Palette.void.opacity(0.6))
                        )
                        .onSubmit { commitModel(environment: environment) }

                    HStack(spacing: Theme.Spacing.sm) {
                        Button("Apply") { commitModel(environment: environment) }
                            .buttonStyle(AuraButtonStyle(isProminent: false))
                            .disabled(draftModel.trimmingCharacters(in: .whitespaces).isEmpty)
                        Button("Reset to default") {
                            draftModel = environment.providerID.defaultModel
                            commitModel(environment: environment)
                        }
                        .buttonStyle(AuraButtonStyle(isProminent: false))
                    }
                }
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "About")

            GlassCard(tint: Theme.Palette.moonlight) {
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("AuraScan reads images through the lens of physiognomy, tasseography, chiromancy, Feng Shui and Vastu Shastra. These are interpretive traditions, offered here for reflection.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.moonlight)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Readings are not medical, psychological, legal or financial advice, and are never a substitute for a qualified professional.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    @ViewBuilder
    private func statusLabel(_ status: Status) -> some View {
        switch status {
        case .saved:
            Label("Key saved to Keychain", systemImage: "checkmark.circle.fill")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.glow)
        case .cleared:
            Label("Key removed", systemImage: "trash.circle.fill")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.dusk)
        case let .failed(message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(Theme.Font.caption)
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Actions

    private func saveKey() {
        do {
            try environment.secretStore.setAPIKey(draftKey, for: environment.providerID)
            draftKey = ""
            isEditingKey = false
            status = .saved
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func clearKey() {
        do {
            try environment.secretStore.setAPIKey(nil, for: environment.providerID)
            status = .cleared
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    private func commitModel(environment: AppEnvironment) {
        let trimmed = draftModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        environment.modelIdentifier = trimmed
        draftModel = trimmed
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
