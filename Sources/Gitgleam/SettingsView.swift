import SwiftUI

/// Window for editing the live, persisted defaults (see `Settings`).
///
/// Every field applies immediately — there's no Save button. Threshold and
/// preview-width fields use `Stepper` with a dynamic range (e.g. the warn
/// threshold can't exceed the critical one) so the values stay sane without
/// needing cross-field validation logic.
///
/// Laid out like a native macOS preferences pane (e.g. TextEdit's): bold
/// left-aligned section headings above a `Grid` of label/control rows, rather
/// than SwiftUI's boxed `Form`/`Section` style, which reads as cramped and
/// "grouped-list-y" for a handful of settings like these.
struct SettingsView: View {
    @ObservedObject var settings: Settings

    private let sectionSpacing: CGFloat = 28
    private let rowSpacing: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: sectionSpacing) {
            statusIconSection
            refreshSection
            previewSection
            debugSection
        }
        .padding(28)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Sections

    private var statusIconSection: some View {
        section(L10n.settingsStatusIcon) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: rowSpacing) {
                GridRow {
                    Text(L10n.warnThreshold)
                    Stepper(value: $settings.warnThreshold, in: 1...settings.criticalThreshold) {
                        Text("\(settings.warnThreshold)").monospacedDigit()
                    }
                }
                GridRow {
                    Text(L10n.criticalThreshold)
                    Stepper(value: $settings.criticalThreshold, in: settings.warnThreshold...9999) {
                        Text("\(settings.criticalThreshold)").monospacedDigit()
                    }
                }
            }
        }
    }

    private var refreshSection: some View {
        section(L10n.settingsRefresh) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: rowSpacing) {
                GridRow {
                    Text(L10n.refreshInterval)
                    HStack(spacing: 6) {
                        Stepper(
                            value: $settings.refreshInterval,
                            in: AppConfig.minInterval...AppConfig.maxInterval, step: 5
                        ) {
                            Text("\(Int(settings.refreshInterval))").monospacedDigit()
                        }
                        Text(L10n.seconds).foregroundStyle(.secondary)
                    }
                }
                GridRow {
                    Text(L10n.maxEntries)
                    Stepper(value: $settings.maxEntries, in: 1...200) {
                        Text("\(settings.maxEntries)").monospacedDigit()
                    }
                }
                GridRow {
                    Text(L10n.commitsShown)
                    Stepper(value: $settings.commits, in: 1...100) {
                        Text("\(settings.commits)").monospacedDigit()
                    }
                }
            }
        }
    }

    private var previewSection: some View {
        section(L10n.settingsMarkdownPreview) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: rowSpacing) {
                GridRow {
                    Text(L10n.viewmdPath)
                    TextField("", text: $settings.viewmdPath, prompt: Text(L10n.viewmdPathPlaceholder))
                        .textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text(L10n.defaultViewLabel)
                    Picker("", selection: $settings.defaultView) {
                        Text(L10n.diffView).tag(ViewMode.diff)
                        Text(L10n.preview).tag(ViewMode.preview)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                GridRow {
                    Text(L10n.previewWidth)
                    HStack(spacing: 6) {
                        Stepper(value: $settings.previewWidth, in: 20...400, step: 10) {
                            Text("\(settings.previewWidth)").monospacedDigit()
                        }
                        Text(L10n.columns).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var debugSection: some View {
        section(L10n.settingsDebug) {
            Toggle(L10n.debugKeepPreviewFiles, isOn: $settings.debugKeepPreviewFiles)
        }
    }

    // MARK: - Helpers

    /// A bold, left-aligned heading above its content — the section styling
    /// throughout this view.
    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
            content()
        }
    }
}
