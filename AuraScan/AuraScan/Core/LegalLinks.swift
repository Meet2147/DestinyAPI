//
//  LegalLinks.swift
//  AuraScan
//
//  The URLs App Review requires to be reachable from the purchase screen.
//
//  Guideline 3.1.2 wants functional links to Terms of Use (EULA) and a Privacy
//  Policy on the paywall itself — not buried in Settings, not only in the App
//  Store listing. A missing or dead link here is one of the most common IAP
//  rejections, so the debug assertion below fails loudly rather than letting a
//  placeholder reach a reviewer.
//

import Foundation

enum LegalLinks {
    /// Apple's standard EULA. Valid to use when you have no custom terms, and
    /// it must then also be selected as the EULA in App Store Connect.
    /// Replace with your own URL if you write bespoke terms.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    /// TODO(launch): host `docs/privacy-policy.md` and put its public URL here.
    /// The same URL goes in App Store Connect under App Privacy.
    static let privacyPolicy = URL(string: "https://aurascan.example.com/privacy")!

    /// Where "Support" in the listing should point. Also required by ASC.
    static let support = URL(string: "https://aurascan.example.com/support")!

    /// True once the placeholders above have been replaced.
    static var areConfigured: Bool {
        ![privacyPolicy, support].contains { $0.host?.contains("example.com") == true }
    }

    #if DEBUG
    /// Called at launch so an unconfigured build is caught here rather than by
    /// a reviewer. Deliberately not a crash — it must not block local work.
    static func warnIfUnconfigured() {
        guard !areConfigured else { return }
        print("""
        ⚠️  LegalLinks still points at example.com.
            App Review requires working Terms and Privacy Policy links on the
            paywall. Fix LegalLinks before archiving for submission.
        """)
    }
    #endif
}
