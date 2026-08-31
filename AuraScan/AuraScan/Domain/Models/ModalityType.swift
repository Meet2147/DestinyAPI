//
//  ModalityType.swift
//  AuraScan
//
//  The four reading modalities the app supports. This enum is the single
//  source of truth for routing, theming, prompt selection and capture
//  guidance — adding a fifth modality means extending this file plus
//  `AstrologyPrompts`, and nothing else.
//

import SwiftUI

enum ModalityType: String, Codable, CaseIterable, Identifiable, Sendable {
    case face
    case coffee
    case palm
    case space

    var id: String { rawValue }

    // MARK: - Presentation

    var title: String {
        switch self {
        case .face: "Face Reading"
        case .coffee: "Coffee Cup"
        case .palm: "Palm Reading"
        case .space: "Space & Energy"
        }
    }

    var subtitle: String {
        switch self {
        case .face: "Physiognomy & planetary rulers"
        case .coffee: "Tasseography & symbol flow"
        case .palm: "Chiromancy & elemental hands"
        case .space: "Feng Shui & Vastu balance"
        }
    }

    var systemImage: String {
        switch self {
        case .face: "face.smiling"
        case .coffee: "cup.and.saucer.fill"
        case .palm: "hand.raised.fill"
        case .space: "square.split.bottomrightquarter.fill"
        }
    }

    /// Two-stop gradient used for cards, headers and share cards.
    var gradient: [Color] {
        switch self {
        case .face: [Color(hex: 0xF9A8D4), Color(hex: 0x8B5CF6)]
        case .coffee: [Color(hex: 0xF6C177), Color(hex: 0x9A3412)]
        case .palm: [Color(hex: 0x6EE7B7), Color(hex: 0x0E7490)]
        case .space: [Color(hex: 0x93C5FD), Color(hex: 0x4338CA)]
        }
    }

    var accent: Color { gradient[0] }

    // MARK: - Capture

    /// Shape of the on-camera alignment guide.
    var guideShape: CaptureGuideShape {
        switch self {
        case .face: .oval(widthRatio: 0.68, heightRatio: 0.52)
        case .coffee: .circle(diameterRatio: 0.78)
        case .palm: .roundedRect(widthRatio: 0.72, heightRatio: 0.62, cornerRadius: 72)
        case .space: .wideFrame(widthRatio: 0.92, aspect: 16.0 / 9.0)
        }
    }

    var captureHeadline: String {
        switch self {
        case .face: "Center your face in the oval"
        case .coffee: "Shoot straight down into the cup"
        case .palm: "Open your dominant palm fully"
        case .space: "Frame the whole room or desk"
        }
    }

    /// Short, actionable framing tips shown under the viewfinder.
    var captureTips: [String] {
        switch self {
        case .face:
            ["Use soft, even front lighting", "Remove glasses and pull hair back", "Neutral expression, eyes to camera"]
        case .coffee:
            ["Drink down to the grounds, then invert and rest the cup", "Hold the camera directly above the rim", "Keep the handle at the bottom of the frame"]
        case .palm:
            ["Use your dominant hand", "Spread fingers slightly, palm flat", "Avoid harsh shadows across the lines"]
        case .space:
            ["Stand at the doorway or back wall", "Include the floor, main furniture and any windows", "Shoot in landscape for the widest field"]
        }
    }

    /// Rough number of seconds analysis usually takes — drives the loader copy.
    var estimatedAnalysisSeconds: Int {
        switch self {
        case .face, .palm: 18
        case .coffee: 20
        case .space: 24
        }
    }

    /// Labels for the modality's spatial zones. Mirrored in the system prompts
    /// so the model and the UI speak the same vocabulary.
    var zoneVocabulary: [String] {
        switch self {
        case .face: ["forehead", "brows", "eyes", "nose", "cheeks", "mouth", "jaw", "chin", "ears"]
        case .coffee: ["rim", "upper-wall", "lower-wall", "base", "handle", "saucer"]
        case .palm: ["life-line", "head-line", "heart-line", "fate-line", "sun-line", "mount-of-venus", "mount-of-moon", "mount-of-jupiter", "mount-of-saturn", "mount-of-mercury", "fingers", "palm-shape"]
        case .space: ["entrance", "center", "north-east", "south-east", "south-west", "north-west", "lighting", "clutter", "workstation", "seating", "greenery", "airflow"]
        }
    }
}

/// Geometry of the modality-specific alignment overlay drawn on the viewfinder.
enum CaptureGuideShape: Equatable, Sendable {
    case oval(widthRatio: CGFloat, heightRatio: CGFloat)
    case circle(diameterRatio: CGFloat)
    case roundedRect(widthRatio: CGFloat, heightRatio: CGFloat, cornerRadius: CGFloat)
    case wideFrame(widthRatio: CGFloat, aspect: CGFloat)

    /// Resolves the guide into a concrete rect inside the given container.
    func rect(in size: CGSize) -> CGRect {
        let box: CGSize
        switch self {
        case let .oval(w, h):
            box = CGSize(width: size.width * w, height: size.height * h)
        case let .circle(d):
            let side = min(size.width, size.height) * d
            box = CGSize(width: side, height: side)
        case let .roundedRect(w, h, _):
            box = CGSize(width: size.width * w, height: size.height * h)
        case let .wideFrame(w, aspect):
            let width = size.width * w
            box = CGSize(width: width, height: width / aspect)
        }
        return CGRect(
            x: (size.width - box.width) / 2,
            y: (size.height - box.height) / 2,
            width: box.width,
            height: box.height
        )
    }

    func path(in size: CGSize) -> Path {
        let frame = rect(in: size)
        switch self {
        case .oval, .circle:
            return Path(ellipseIn: frame)
        case let .roundedRect(_, _, radius):
            return Path(roundedRect: frame, cornerRadius: radius)
        case .wideFrame:
            return Path(roundedRect: frame, cornerRadius: 18)
        }
    }
}
