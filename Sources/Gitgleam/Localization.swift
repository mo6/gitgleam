import Foundation

/// Central place for user-facing strings.
///
/// Each value is looked up from the localized `Localizable.strings` files in
/// `Bundle.module` (see `Resources/<lang>.lproj/`). To add a language, drop a
/// new `<lang>.lproj/Localizable.strings` into `Resources/` and translate the
/// values — no code changes needed. English is the default localization; a
/// missing key simply falls back to English.
enum L10n {
    // Menu
    static var noChanges: String { s("No changes") }
    static var refresh: String { s("Refresh") }
    static var quit: String { s("Quit") }
    static var recentCommits: String { s("Recent commits") }

    // Overflow / full-list window
    static var allChanges: String { s("All changes") }
    /// Button that opens the full-list window, with the total change count.
    static func showAll(_ count: Int) -> String { String(format: s("Show all %d changes…"), count) }
    /// Menu indicator for files hidden by the entry cap.
    static func moreNotShown(_ count: Int) -> String { String(format: s("%d more not shown"), count) }

    // Section headers
    static var changed: String { s("Changed") }
    static var new: String { s("New") }
    static var deleted: String { s("Deleted") }

    // File status descriptions
    static var modified: String { s("Modified") }
    static var added: String { s("Added") }
    static var renamed: String { s("Renamed") }
    static var copied: String { s("Copied") }
    static var conflict: String { s("Conflict") }
    static var newUntracked: String { s("New (untracked)") }

    // Diff view
    static var noTextualDiff: String { s("No textual differences (possibly binary or mode-only changes).") }
    static var gitFailed: String { s("git failed") }

    // Preview (viewmd)
    static var diffView: String { s("Diff") }
    static var preview: String { s("Preview") }
    static var viewmdFailed: String { s("viewmd failed") }

    /// The bundle for the user's preferred language.
    ///
    /// A raw SPM executable has no localization info in `Bundle.main`, so the
    /// system language resolution that `String(localized:)` relies on defaults
    /// to English — ignoring both the system language and an `-AppleLanguages`
    /// override. We therefore match the preferred languages against the
    /// module's own localizations and load that `.lproj` directly. Both the
    /// system language and `-AppleLanguages "(nl)"` feed `preferredLanguages`,
    /// so this honors either. Falls back to the module bundle (English).
    private static let localizedBundle: Bundle = {
        let preferred = Bundle.preferredLocalizations(
            from: Bundle.module.localizations,
            forPreferences: Locale.preferredLanguages
        )
        if let lang = preferred.first,
           let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .module
    }()

    /// Looks up a key in the preferred-language string table. A missing key
    /// falls back to the key itself, which is the English source string.
    private static func s(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
