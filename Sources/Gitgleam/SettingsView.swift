import SwiftUI

/// Window for editing the live, persisted defaults (see `Settings`).
///
/// Every field applies immediately — there's no Save button. Threshold and
/// preview-width fields use `Stepper` with a dynamic range (e.g. the warn
/// threshold can't exceed the critical one) so the values stay sane without
/// needing cross-field validation logic.
struct SettingsView: View {
    @ObservedObject var settings: Settings

    var body: some View {
        Form {
            Section(L10n.settingsStatusIcon) {
                Stepper(
                    "\(L10n.warnThreshold): \(settings.warnThreshold)",
                    value: $settings.warnThreshold, in: 1...settings.criticalThreshold
                )
                Stepper(
                    "\(L10n.criticalThreshold): \(settings.criticalThreshold)",
                    value: $settings.criticalThreshold, in: settings.warnThreshold...9999
                )
            }

            Section(L10n.settingsRefresh) {
                Stepper(
                    "\(L10n.refreshInterval): \(Int(settings.refreshInterval))s",
                    value: $settings.refreshInterval,
                    in: AppConfig.minInterval...AppConfig.maxInterval, step: 5
                )
                Stepper(
                    "\(L10n.maxEntries): \(settings.maxEntries)",
                    value: $settings.maxEntries, in: 1...200
                )
                Stepper(
                    "\(L10n.commitsShown): \(settings.commits)",
                    value: $settings.commits, in: 1...100
                )
            }

            Section(L10n.settingsMarkdownPreview) {
                TextField(L10n.viewmdPath, text: $settings.viewmdPath)
                Picker(L10n.defaultViewLabel, selection: $settings.defaultView) {
                    Text(L10n.diffView).tag(ViewMode.diff)
                    Text(L10n.preview).tag(ViewMode.preview)
                }
                Stepper(
                    "\(L10n.previewWidth): \(settings.previewWidth)",
                    value: $settings.previewWidth, in: 20...400, step: 10
                )
            }

            Section(L10n.settingsDebug) {
                Toggle(L10n.debugKeepPreviewFiles, isOn: $settings.debugKeepPreviewFiles)
            }
        }
        .padding(20)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}
