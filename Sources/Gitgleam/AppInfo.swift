import Foundation

/// Static metadata about the app itself, shown in the Settings window's Info
/// section.
///
/// `version` has no runtime source — this is a plain SPM binary, not a
/// versioned `.app` bundle with an Info.plist `CFBundleShortVersionString` —
/// so it's a plain literal. Bump it by hand alongside the CHANGELOG entry and
/// git tag at release time (see AGENTS.md's release process).
enum AppInfo {
    static let version = "1.0.3"
    static let githubURL = URL(string: "https://github.com/mo6/gitgleam")!
}
