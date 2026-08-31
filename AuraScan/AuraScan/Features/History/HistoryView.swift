//
//  HistoryView.swift
//  AuraScan
//
//  Full reading history with modality filtering and swipe-to-delete.
//

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Binding var path: NavigationPath

    @Environment(AppEnvironment.self) private var environment
    @Query(sort: \Reading.createdAt, order: .reverse) private var readings: [Reading]
    @State private var filter: ModalityType?
    @State private var showsFavoritesOnly = false

    private var filtered: [Reading] {
        readings.filter { reading in
            (filter == nil || reading.modality == filter)
                && (!showsFavoritesOnly || reading.isFavorite)
        }
    }

    var body: some View {
        ZStack {
            CosmicBackground(accent: filter?.accent ?? Theme.Palette.aura)

            if filtered.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(filtered) { reading in
                            Button { open(reading) } label: {
                                ReadingRow(reading: reading)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    try? environment.repository.toggleFavorite(reading)
                                } label: {
                                    Label(
                                        reading.isFavorite ? "Remove from favourites" : "Add to favourites",
                                        systemImage: reading.isFavorite ? "star.slash" : "star"
                                    )
                                }
                                Button(role: .destructive) {
                                    try? environment.repository.delete(reading)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.bottom, Theme.Spacing.xl)
                }
                .scrollIndicators(.hidden)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .top) { filterBar }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation { showsFavoritesOnly.toggle() }
                } label: {
                    Image(systemName: showsFavoritesOnly ? "star.fill" : "star")
                }
                .accessibilityLabel(showsFavoritesOnly ? "Show all readings" : "Show favourites only")
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.xs) {
                FilterPill(title: "All", isSelected: filter == nil, tint: Theme.Palette.aura) {
                    withAnimation(.spring(duration: 0.3)) { filter = nil }
                }
                ForEach(ModalityType.allCases) { modality in
                    FilterPill(title: modality.title, isSelected: filter == modality, tint: modality.accent) {
                        withAnimation(.spring(duration: 0.3)) {
                            filter = filter == modality ? nil : modality
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: showsFavoritesOnly ? "star" : "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundStyle(Theme.Palette.dusk)
            Text(showsFavoritesOnly ? "No favourites yet" : "No readings here yet")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Palette.starlight)
            Text(showsFavoritesOnly
                ? "Long-press a reading to add it to your favourites."
                : "Readings you take will appear here, stored on this device.")
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Palette.dusk)
                .multilineTextAlignment(.center)
        }
        .padding(Theme.Spacing.lg)
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

struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Selected filters are pressed *in*; unselected ones stand proud.
            Text(title)
                .font(Theme.Font.callout)
                .foregroundStyle(isSelected ? tint : Theme.Palette.moonlight)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .softRaised(Capsule(), depth: .subtle, tint: isSelected ? tint : nil, isPressed: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    NavigationStack {
        HistoryView(path: .constant(NavigationPath()))
    }
    .environment(AppEnvironment.preview())
    .modelContainer(ModelContainer.inMemory())
    .preferredColorScheme(.dark)
}
