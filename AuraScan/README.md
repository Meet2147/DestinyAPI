# AuraScan

A SwiftUI iOS app that performs multimodal astrological and energetic readings across four modalities:

| Modality | Tradition | What it reads |
|---|---|---|
| **Face** | Physiognomy + planetary correspondence | Forehead/Jupiter, brows/Mars, eyes/Sun–Moon, jaw/Saturn, symmetry |
| **Coffee cup** | Tasseography | Rim = immediate, walls = present, base = future/root, handle = self |
| **Palm** | Chiromancy | Major/minor lines, mounts, elemental hand shape |
| **Space** | Feng Shui + Vastu Shastra | Command position, brahmasthan, flow, lighting, five-phase balance |

A photo is captured (or picked), sent to a multimodal vision model with a modality-specific system prompt and a JSON Schema, and the strictly validated response is rendered as an interactive reading and saved to local history.

---

## Requirements

- Xcode 16+, iOS 17.0 deployment target, Swift 6 (strict concurrency: `complete`)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is generated, not committed

```bash
brew install xcodegen
cd AuraScan
xcodegen generate
open AuraScan.xcodeproj
```

Then run the app, open **Settings**, pick a provider, and paste an API key. The key is written to the iOS Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) and never leaves the device except in requests to that provider. For simulator convenience, a DEBUG build also reads `AURASCAN_API_KEY` from the scheme environment.

> **Production note:** shipping a provider API key inside an app binary is not safe, because a key on a user's device is a key you have given away. For a real release, point `AnthropicProvider(baseURL:)` (or its siblings) at a relay you control and keep the key server-side. `SecretStore` exists so a developer build can run standalone.

---

## Architecture

MVVM with a service layer. Views hold no networking, persistence, or AVFoundation code; `AppEnvironment` is the composition root and the only place concrete services are constructed.

```
Capture (UIImage)
   ↓  ImageProcessor        downscale → JPEG → base64
   ↓  AstrologyPrompts      modality system prompt + user turn
   ↓  AnalysisSchema        JSON Schema pinned to the modality's zone vocabulary
   ↓  AIProvider            Anthropic | OpenAI | Gemini  (HTTP only)
   ↓  VisionAnalysisService retry w/ backoff → extract JSON → decode → repair once
   ↓  ReadingRepository     SwiftData
   ↓  ReadingResultView
```

### File structure

```
AuraScan/
├── project.yml                          XcodeGen spec (source of truth)
├── AuraScan/
│   ├── App/
│   │   ├── AuraScanApp.swift             @main, container + environment wiring
│   │   ├── AppEnvironment.swift          composition root, provider selection, previews
│   │   └── RootView.swift                NavigationStack + Route enum
│   ├── Core/
│   │   ├── DesignSystem/
│   │   │   ├── Theme.swift               palette, type scale, GlassCard, AuraButtonStyle, Chip
│   │   │   ├── CosmicBackground.swift    gradient + seeded star field
│   │   │   └── ElementBalanceBar.swift   stacked elemental bar, EnergyGauge
│   │   ├── Extensions/                   Color+Hex, Comparable+Clamped, Date+Display
│   │   └── Utilities/SampleData.swift    canned readings for previews and tests
│   ├── Domain/Models/
│   │   ├── ModalityType.swift            modalities, theming, capture guides, zone vocabulary
│   │   ├── Element.swift                 Element, Planet, Polarity (tolerant decoding)
│   │   ├── AnalysisResponse.swift        the structured reading payload
│   │   ├── AnalysisSchema.swift          JSON Schema mirroring AnalysisResponse
│   │   └── ReadingModel.swift            SwiftData @Model
│   ├── Services/
│   │   ├── AI/
│   │   │   ├── AIProvider.swift          transport protocol, request/response, error taxonomy
│   │   │   ├── HTTPClient.swift          URLSession + status→error mapping
│   │   │   ├── AnthropicProvider.swift   Messages API, output_config.format, prompt caching
│   │   │   ├── OpenAIProvider.swift      Chat Completions, response_format json_schema
│   │   │   ├── GeminiProvider.swift      generateContent + schema sanitiser
│   │   │   ├── VisionAnalysisService.swift  orchestration, retry, JSON extraction, repair
│   │   │   ├── ImageProcessor.swift      resize/encode/thumbnail
│   │   │   └── SecretStore.swift         Keychain-backed API keys
│   │   ├── Camera/
│   │   │   ├── CameraManager.swift       AVCaptureSession, async photo capture
│   │   │   └── CameraPreviewView.swift   AVCaptureVideoPreviewLayer + tap-to-focus
│   │   ├── Persistence/
│   │   │   ├── ReadingRepository.swift   SwiftData CRUD
│   │   │   └── ModelContainer+AuraScan.swift
│   │   └── Prompts/AstrologyPrompts.swift  the four system prompts
│   ├── Features/
│   │   ├── Dashboard/  HomeDashboardView + ViewModel
│   │   ├── Capture/    CaptureView, CaptureViewModel, CaptureGuideOverlay
│   │   ├── Analysis/   AnalyzingView, CosmicLoader
│   │   ├── Result/     ReadingResultView, ShareCardView
│   │   ├── History/    HistoryView
│   │   └── Settings/   SettingsView
│   └── Resources/Info.plist
└── AuraScanTests/                        Swift Testing suites
```

## Design notes

**Prompts and schema share one vocabulary.** `ModalityType.zoneVocabulary` is the single source of truth for zone keys. `AnalysisSchema` pins the `zone` field to that enum, and every system prompt quotes it. `SchemaAndPromptTests` fails the build if the three ever drift apart — the failure mode that would otherwise be silent.

**Observation is separated from interpretation.** Every marker carries both an `observation` (what is literally visible) and an `interpretation` (what the tradition makes of it). The prompts call this the most important instruction they contain; it is what keeps the model from inventing markers that suit a satisfying reading.

**Decoding is strict but forgiving in the right places.** The schema is enforced server-side where the provider supports it. On top of that, the decoder tolerates casing and whitespace drift in enums, normalises the four element scores to sum to 100, clamps out-of-range numbers, and synthesises marker ids — while still rejecting an element it does not recognise. A schema miss triggers exactly one repair round trip; an image the model called unreadable does not.

**Adding a fifth modality** means extending `ModalityType` (title, icon, gradient, guide shape, tips, zone vocabulary) and adding a briefing to `AstrologyPrompts`. Nothing else has a per-modality branch.

## Tests

`AuraScanTests` uses Swift Testing and covers the parts most likely to break silently:

- decoding well-formed, messy, and hostile model output
- element-balance normalisation and score clamping
- JSON extraction from fenced, prose-wrapped, and brace-in-string responses
- schema ↔ prompt ↔ model vocabulary agreement, per modality
- provider response parsing (thinking blocks, refusals, truncation) and retry classification

```bash
xcodebuild test -scheme AuraScan -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Disclaimer

AuraScan offers reflective interpretation from traditional practices. It is not medical, psychological, legal or financial advice. The prompts explicitly forbid the model from inferring identity characteristics or predicting health, lifespan, legal or financial outcomes.
