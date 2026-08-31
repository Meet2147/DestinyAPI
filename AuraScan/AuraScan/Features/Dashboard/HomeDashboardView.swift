//
//  HomeDashboardView.swift
//  AuraScan
//
//  Entry screen: the four modalities, plus recent readings.
//

import SwiftUI

struct HomeDashboardView: View {
    @Binding var path: NavigationPath

    @Environment(AppEnvironment.self) private var environment
    @State private var viewModel: HomeDashboardViewModel?
    @State private var appeared = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
        GridItem(.flexible(), spacing: Theme.Spacing.sm),
    ]

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    modalityGrid
                    recentSection
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.bottom, Theme.Spacing.xl)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    path.append(Route.settings)
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .accessibilityLabel("Settings")
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .task {
            if viewModel == nil {
                viewModel = HomeDashboardViewModel(repository: environment.repository)
            }
            viewModel?.refresh()
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .onAppear { viewModel?.refresh() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("AuraScan")
                .font(Theme.Font.caption)
                .tracking(3)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Palette.gold)

            Text(viewModel?.greeting ?? "Welcome")
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Palette.starlight)

            Text(viewModel?.subtitle ?? "")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Palette.moonlight)

            if !environment.hasCredentials {
                credentialsNotice
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(.top, Theme.Spacing.sm)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var credentialsNotice: some View {
        Button {
            path.append(Route.settings)
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "key.radiowaves.forward.fill")
                    .foregroundStyle(Theme.Palette.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add an API key to start reading")
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.starlight)
                    Text("\(environment.providerID.title) — stored in your Keychain")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Palette.dusk)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.dusk)
            }
            .padding(Theme.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .fill(Theme.Palette.gold.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                    .strokeBorder(Theme.Palette.gold.opacity(0.32), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var modalityGrid: some View {
        LazyVGrid(columns: columns, spacing: Theme.Spacing.sm) {
            ForEach(Array(ModalityType.allCases.enumerated()), id: \.element) { index, modality in
                ModalityCard(modality: modality) {
                    path.append(Route.capture(modality))
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(duration: 0.5).delay(Double(index) * 0.06), value: appeared)
            }
        }
    }

    @ViewBuilder
    private var recentSection: some View {
        let readings = viewModel?.recent ?? []

        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            SectionHeader(title: "Recent readings", subtitle: readings.isEmpty ? nil : "\(readings.count) saved") {
                if !readings.isEmpty {
                    Button("See all") { path.append(Route.history) }
                        .font(Theme.Font.callout)
                        .foregroundStyle(Theme.Palette.aura)
                }
            }

            if let error = viewModel?.loadError {
                Text(error)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.orange)
            } else if readings.isEmpty {
                emptyState
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(readings) { reading in
                        Button {
                            open(reading)
                        } label: {
                            ReadingRow(reading: reading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        GlassCard(tint: Theme.Palette.moonlight) {
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(Theme.Palette.gold)
                Text("Nothing read yet")
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Palette.starlight)
                Text("Your readings are stored on this device only. Nothing is uploaded except the single image you choose to analyse.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.dusk)
            }
        }
    }

    private func open(_ reading: Reading) {
        guard let analysis = reading.analysis else { return }
        path.append(
            Route.result(
                ReadingPayload(
                    id: reading.id,
                    modality: reading.modality,
                    analysis: analysis,
                    imageData: reading.imageData,
                    isFreshlySaved: false
                )
            )
        )
    }
}

// MARK: - Cards

struct ModalityCard: View {
    let modality: ModalityType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: modality.gradient.map { $0.opacity(0.9) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 44, height: 44)
                    Image(systemName: modality.systemImage)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(Theme.Palette.void)
                }

                Spacer(minLength: Theme.Spacing.sm)

                Text(modality.title)
                    .font(Theme.Font.headline)
                    .foregroundStyle(Theme.Palette.starlight)
                    .multilineTextAlignment(.leading)

                Text(modality.subtitle)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Palette.dusk)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 168, alignment: .leading)
            .padding(Theme.Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .fill(Theme.Palette.surface.opacity(0.8))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.large, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [modality.accent.opacity(0.5), .white.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(modality.title)
        .accessibilityHint(modality.subtitle)
    }
}

struct ReadingRow: View {
    let reading: Reading

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(reading.headline)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Palette.starlight)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: Theme.Spacing.xs) {
                    Text(reading.modality.title)
                    Text("·")
                    Text(reading.createdAt.relativeDescription)
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.dusk)
            }

            Spacer(minLength: Theme.Spacing.xs)

            VStack(spacing: 4) {
                Image(systemName: reading.dominantElement.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(reading.dominantElement.color)
                Text("\(reading.energyScore)")
                    .font(Theme.Font.mono)
                    .foregroundStyle(Theme.Palette.moonlight)
            }
        }
        .padding(Theme.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .fill(Theme.Palette.surface.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.medium, style: .continuous)
                .strokeBorder(.white.opacity(0.06), lineWidth: 1)
        )
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let data = reading.thumbnailData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: reading.modality.gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: reading.modality.systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.Palette.void.opacity(0.8))
                }
            }
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        HomeDashboardView(path: .constant(NavigationPath()))
    }
    .environment(AppEnvironment.preview())
    .preferredColorScheme(.dark)
}
