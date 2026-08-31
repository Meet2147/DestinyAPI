//
//  CaptureGuideOverlay.swift
//  AuraScan
//
//  Modality-specific alignment guide drawn over the viewfinder: a dimmed
//  surround with the guide shape punched out, plus a slow breathing pulse.
//

import SwiftUI

struct CaptureGuideOverlay: View {
    let modality: ModalityType
    var isArmed = true

    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let guidePath = modality.guideShape.path(in: size)

            ZStack {
                // Dim everything outside the guide.
                Path(CGRect(origin: .zero, size: size))
                    .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))
                    .overlay {
                        guidePath
                            .fill(Color.black)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()

                guidePath
                    .stroke(
                        LinearGradient(colors: modality.gradient, startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 2, dash: dashPattern)
                    )
                    .shadow(color: modality.accent.opacity(0.6), radius: pulse ? 14 : 4)
                    .opacity(isArmed ? 1 : 0.4)
                    .scaleEffect(pulse ? 1.012 : 1)

                cornerTicks(in: size)
            }
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulse)
        }
        .allowsHitTesting(false)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }

    private var dashPattern: [CGFloat] {
        switch modality {
        case .space: [10, 6]
        default: []
        }
    }

    /// Rule-of-thirds ticks — most useful for the wide room framing.
    @ViewBuilder
    private func cornerTicks(in size: CGSize) -> some View {
        if case .wideFrame = modality.guideShape {
            let frame = modality.guideShape.rect(in: size)
            Path { path in
                for fraction in [1.0 / 3.0, 2.0 / 3.0] {
                    let x = frame.minX + frame.width * fraction
                    path.move(to: CGPoint(x: x, y: frame.minY))
                    path.addLine(to: CGPoint(x: x, y: frame.maxY))

                    let y = frame.minY + frame.height * fraction
                    path.move(to: CGPoint(x: frame.minX, y: y))
                    path.addLine(to: CGPoint(x: frame.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.16), lineWidth: 0.5)
        }
    }
}

#Preview {
    ZStack {
        Color.gray
        CaptureGuideOverlay(modality: .coffee)
    }
    .ignoresSafeArea()
}
