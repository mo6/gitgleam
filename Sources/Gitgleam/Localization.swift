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
    static var settings: String { s("Settings…") }
    static var noRepositoriesConfigured: String { s("No repositories configured") }

    // Overflow / full-list window
    static var allChanges: String { s("All changes") }
    static var repositoryRemoved: String { s("Repository removed") }
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

    // Settings window: sidebar sections
    static var settingsInfo: String { s("Info") }
    static var settingsRepositories: String { s("Repositories") }
    static var settingsGeneral: String { s("General") }
    static var settingsStatusIcon: String { s("Status icon") }
    static var settingsRefresh: String { s("Refresh") }
    static var settingsMarkdownPreview: String { s("Markdown preview") }
    static var settingsDebug: String { s("Debug") }

    // Settings window: Info section
    static var appDescription: String {
        s("A small native macOS menu bar app that watches a git repository and shows the number of uncommitted changes, colored by severity, with a colored per-file diff.")
    }
    static var version: String { s("Version") }
    static var githubRepository: String { s("GitHub repository") }

    // Settings window: Repositories section
    static var repositoryLabel: String { s("Label") }
    static var repositoryPath: String { s("Path") }
    static var addRepository: String { s("Add Repository…") }
    static var removeRepository: String { s("Remove repository") }
    static var noRepositoriesConfiguredDescription: String {
        s("Add a repository to start watching its uncommitted changes.")
    }
    static var notAGitRepositoryWarning: String { s("This folder doesn't look like a git repository.") }
    static var notAGitRepositoryAddPrompt: String {
        s("Initialize a git repository in this folder, add it anyway, or cancel.")
    }
    static var initializeGitRepository: String { s("Initialize Git Repository") }
    static var addAnyway: String { s("Add Anyway") }
    static var cancel: String { s("Cancel") }
    static var duplicateRepositoryWarning: String { s("This folder is already in the list.") }
    static var duplicateRepositoryPrompt: String {
        s("Watching the same path twice runs two watchers on one tree. Add it anyway, or cancel.")
    }
    static var dragToReorder: String { s("Drag to reorder") }
    static var pauseRepository: String { s("Watch this repository") }
    static var paused: String { s("paused") }
    static var useAppDefaults: String { s("App defaults") }
    static var customThresholds: String { s("Custom") }
    static var thresholds: String { s("Thresholds") }
    static var exportSettings: String { s("Export…") }
    static var importSettings: String { s("Import…") }
    static var importSettingsConfirm: String { s("Replace all settings?") }
    static var importSettingsConfirmDescription: String {
        s("Importing a settings file replaces the repository list and every other setting. This cannot be undone except by importing a previous export.")
    }
    static var importSettingsFailed: String { s("Couldn't import settings") }
    static var exportSettingsFailed: String { s("Couldn't export settings") }
    static func repositoryLimitReached(_ cap: Int) -> String {
        String(format: s("Can't add more than %d repositories."), cap)
    }
    static func repositoryCountWarning(_ count: Int) -> String {
        String(format: s("%d repositories — each adds a watcher and a git poll. Pause ones you don't need."), count)
    }

    // Settings window: rows (label + explanatory description each)
    static var language: String { s("Language") }
    static var languageDescription: String { s("The language Gitgleam's menu and windows are displayed in.") }
    static var languageAuto: String { s("Automatic (System Language)") }
    static var choose: String { s("Choose…") }
    static var warnThreshold: String { s("Warn threshold") }
    static var warnThresholdDescription: String {
        s("Number of changes at or above which the menu-bar icon turns yellow.")
    }
    static var criticalThreshold: String { s("Critical threshold") }
    static var criticalThresholdDescription: String {
        s("Number of changes at or above which the icon turns red.")
    }
    static var refreshInterval: String { s("Poll interval") }
    static var refreshIntervalDescription: String {
        s("How often Gitgleam re-checks the repository as a safety net. A filesystem watcher already refreshes instantly on any change.")
    }
    static var maxEntries: String { s("Max menu entries") }
    static var maxEntriesDescription: String {
        s("Largest number of file rows shown in the dropdown before an overflow window is offered instead.")
    }
    static var commitsShown: String { s("Recent commits shown") }
    static var commitsShownDescription: String { s("Number of recent commits listed in the submenu.") }
    static var viewmdPath: String { s("viewmd path") }
    static var viewmdPathDescription: String {
        s("Location of the viewmd.sh launcher used to render Markdown previews. Leave empty to disable previews.")
    }
    static var defaultViewLabel: String { s("Default view") }
    static var defaultViewDescription: String { s("Which view a Markdown window opens in by default.") }
    static var previewWidth: String { s("Preview width") }
    static var previewWidthDescription: String { s("Render width, in columns, passed to viewmd.") }
    static var debugKeepPreviewFiles: String { s("Keep preview files") }
    static var debugKeepPreviewFilesDescription: String {
        s("Markdown files sent to viewmd for preview are kept in /tmp instead of being deleted, so the exact input — including viewmd:mark highlighting — can be inspected.")
    }
    static var seconds: String { s("seconds") }
    static var columns: String { s("columns") }
    static var viewmdPathPlaceholder: String { s("Path to viewmd.sh (optional)") }
    /// Accessibility label for a slider row's reset-to-default button.
    static var resetToDefault: String { s("Reset to default") }

    /// Explicit language code (e.g. `"nl"`) the Settings window's Language
    /// picker has selected, or `nil` for "Automatic" (system-language
    /// detection). Set by `Settings.language`; changing it takes effect on
    /// the next string lookup, so already-open secondary windows (diff,
    /// commit) pick it up next time they're opened rather than live — only
    /// the menu-bar dropdown, which re-renders on every `Settings` change,
    /// updates immediately.
    ///
    /// `nonisolated(unsafe)`: `L10n` is called from `Git`'s `nonisolated`
    /// background functions (for `gitFailed`, etc.) as well as from the
    /// `@MainActor` UI, so this can't be `@MainActor`-isolated. In practice
    /// it's written only from the Settings window (main actor) and read far
    /// more often than written, so a benign race on the rare
    /// read-during-write is an acceptable trade for not restructuring `Git`'s
    /// concurrency model over a display string.
    nonisolated(unsafe) static var languageOverride: String? {
        didSet { bundleCache = nil }
    }

    /// Language codes with a `.lproj` in this bundle, in a fixed display
    /// order (English first, then alphabetically) for the Language picker.
    static var availableLanguages: [String] {
        Bundle.module.localizations.filter { $0 != "Base" }.sorted { a, b in
            if a == "en" { return true }
            if b == "en" { return false }
            return a < b
        }
    }

    /// A language code's name, in that language (e.g. `"nl"` → "Nederlands"),
    /// for the Language picker.
    static func displayName(forLanguageCode code: String) -> String {
        switch code {
        case "en": return "English"
        case "nl": return "Nederlands"
        default: return Locale(identifier: code).localizedString(forLanguageCode: code) ?? code
        }
    }

    /// See `languageOverride`'s doc comment for why this is `unsafe`.
    nonisolated(unsafe) private static var bundleCache: Bundle?

    /// The bundle for the current language: `languageOverride` if set,
    /// otherwise the user's preferred system language.
    ///
    /// A raw SPM executable has no localization info in `Bundle.main`, so the
    /// system language resolution that `String(localized:)` relies on defaults
    /// to English — ignoring both the system language and an `-AppleLanguages`
    /// override. We therefore match the preferred languages against the
    /// module's own localizations and load that `.lproj` directly. Both the
    /// system language and `-AppleLanguages "(nl)"` feed `preferredLanguages`,
    /// so "Automatic" honors either. Falls back to the module bundle (English).
    private static var localizedBundle: Bundle {
        if let bundleCache { return bundleCache }
        let bundle = resolvedBundle()
        bundleCache = bundle
        return bundle
    }

    private static func resolvedBundle() -> Bundle {
        if let languageOverride,
           let path = Bundle.module.path(forResource: languageOverride, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
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
    }

    /// Looks up a key in the preferred-language string table. A missing key
    /// falls back to the key itself, which is the English source string.
    private static func s(_ key: String) -> String {
        localizedBundle.localizedString(forKey: key, value: nil, table: nil)
    }
}
