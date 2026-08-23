import SwiftUI
import AppKit

/// Window for editing the live, persisted defaults (see `Settings`).
///
/// Every field applies immediately — there's no Save button. Styled like a
/// native macOS/Obsidian-style preferences pane: a sidebar of icon-labeled
/// sections on the left, and on the right a scrollable list of rounded
/// "card" rows — each a label, a one-line explanation, and a flush-right
/// control — grouped per section.
struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State private var section: SettingsSection = .info

    var body: some View {
        NavigationSplitView {
            List(SettingsSection.allCases, selection: $section) { item in
                Label(item.title, systemImage: item.icon).tag(item)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(section.title)
                        .font(.system(size: 20, weight: .bold))
                    card(for: section)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .font(.system(size: 12))
        .frame(width: 640, height: 440)
    }

    // MARK: - Sections

    @ViewBuilder
    private func card(for section: SettingsSection) -> some View {
        switch section {
        case .info:
            SettingsCard {
                Text(L10n.appDescription)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                Divider()
                Row(label: L10n.version) {
                    Text(AppInfo.version).foregroundStyle(.secondary)
                }
                Divider()
                Row(label: L10n.githubRepository) {
                    Link(L10n.viewOnGithub, destination: AppInfo.githubURL)
                }
            }
        case .general:
            SettingsCard {
                Row(label: L10n.language, description: L10n.languageDescription) {
                    Picker("", selection: $settings.language) {
                        Text(L10n.languageAuto).tag("auto")
                        ForEach(L10n.availableLanguages, id: \.self) { code in
                            Text(L10n.displayName(forLanguageCode: code)).tag(code)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 220)
                }
            }
        case .statusIcon:
            SettingsCard {
                SliderRow(
                    label: L10n.warnThreshold, description: L10n.warnThresholdDescription,
                    value: intBinding($settings.warnThreshold), range: 1...Double(settings.criticalThreshold),
                    step: 1, defaultValue: Double(AppConfig.defaultWarnThreshold), valueText: { "\(Int($0))" }
                )
                Divider()
                SliderRow(
                    label: L10n.criticalThreshold, description: L10n.criticalThresholdDescription,
                    value: intBinding($settings.criticalThreshold), range: Double(settings.warnThreshold)...200,
                    step: 1, defaultValue: Double(AppConfig.defaultCriticalThreshold), valueText: { "\(Int($0))" }
                )
            }
        case .refresh:
            SettingsCard {
                SliderRow(
                    label: L10n.refreshInterval, description: L10n.refreshIntervalDescription,
                    value: $settings.refreshInterval, range: AppConfig.minInterval...AppConfig.maxInterval,
                    step: 5, defaultValue: AppConfig.defaultInterval, valueText: { "\(Int($0))\(L10n.seconds.prefix(1))" }
                )
                Divider()
                SliderRow(
                    label: L10n.maxEntries, description: L10n.maxEntriesDescription,
                    value: intBinding($settings.maxEntries), range: 1...200,
                    step: 1, defaultValue: Double(AppConfig.defaultMaxEntries), valueText: { "\(Int($0))" }
                )
                Divider()
                SliderRow(
                    label: L10n.commitsShown, description: L10n.commitsShownDescription,
                    value: intBinding($settings.commits), range: 1...100,
                    step: 1, defaultValue: Double(AppConfig.defaultCommits), valueText: { "\(Int($0))" }
                )
            }
        case .preview:
            SettingsCard {
                StackedRow(label: L10n.viewmdPath, description: L10n.viewmdPathDescription) {
                    HStack(spacing: 8) {
                        TextField("", text: $settings.viewmdPath, prompt: Text(L10n.viewmdPathPlaceholder))
                            .textFieldStyle(.roundedBorder)
                        Button(L10n.choose) { chooseViewmdPath() }
                    }
                }
                Divider()
                Row(label: L10n.defaultViewLabel, description: L10n.defaultViewDescription) {
                    Picker("", selection: $settings.defaultView) {
                        Text(L10n.diffView).tag(ViewMode.diff)
                        Text(L10n.preview).tag(ViewMode.preview)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 140)
                }
                Divider()
                SliderRow(
                    label: L10n.previewWidth, description: L10n.previewWidthDescription,
                    value: intBinding($settings.previewWidth), range: 20...400,
                    step: 10, defaultValue: Double(AppConfig.defaultPreviewWidth), valueText: { "\(Int($0))" }
                )
            }
        case .debug:
            SettingsCard {
                Row(label: L10n.debugKeepPreviewFiles, description: L10n.debugKeepPreviewFilesDescription) {
                    Toggle("", isOn: $settings.debugKeepPreviewFiles).labelsHidden()
                }
            }
        }
    }

    /// Adapts an `Int`-backed setting to the `Double` binding `SliderRow` needs.
    private func intBinding(_ base: Binding<Int>) -> Binding<Double> {
        Binding(get: { Double(base.wrappedValue) }, set: { base.wrappedValue = Int($0) })
    }

    /// Presents a file picker (an executable, not a directory) for the
    /// viewmd.sh launcher.
    private func chooseViewmdPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.choose
        let current = settings.viewmdPath.trimmingCharacters(in: .whitespaces)
        if !current.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: current).deletingLastPathComponent()
        }
        if panel.runModal() == .OK, let url = panel.url {
            settings.viewmdPath = url.path
        }
    }
}

/// A sidebar destination: a settings group, its icon, and localized title.
private enum SettingsSection: CaseIterable, Identifiable {
    case info, general, statusIcon, refresh, preview, debug

    var id: Self { self }

    var title: String {
        switch self {
        case .info: return L10n.settingsInfo
        case .general: return L10n.settingsGeneral
        case .statusIcon: return L10n.settingsStatusIcon
        case .refresh: return L10n.settingsRefresh
        case .preview: return L10n.settingsMarkdownPreview
        case .debug: return L10n.settingsDebug
        }
    }

    var icon: String {
        switch self {
        case .info: return "info.circle"
        case .general: return "gearshape"
        case .statusIcon: return "gauge.with.dots.needle.50percent"
        case .refresh: return "arrow.triangle.2.circlepath"
        case .preview: return "doc.text.magnifyingglass"
        case .debug: return "ladybug"
        }
    }
}

/// The flat, rounded "card" a section's rows sit in — System Settings' inset
/// grouped-list look: a subtle background fill, no border.
private struct SettingsCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0, content: { content })
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }
}

/// One row: a label (with an optional description below it) on the left, a
/// flush-right control. `description` is nil for a purely informational row
/// (e.g. Info's Version/GitHub rows) that doesn't need an explanation.
private struct Row<Control: View>: View {
    let label: String
    var description: String? = nil
    @ViewBuilder var control: Control

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                if let description {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            control
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// A row whose control needs the full row width rather than being flushed
/// right next to the label — the label/description sit above a full-width
/// control below, both left-aligned.
private struct StackedRow<Control: View>: View {
    let label: String
    let description: String
    @ViewBuilder var control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                Text(description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// A numeric row: label/description on the left, a reset button + current
/// value + slider on the right.
private struct SliderRow: View {
    let label: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let defaultValue: Double
    let valueText: (Double) -> String

    var body: some View {
        Row(label: label, description: description) {
            HStack(spacing: 8) {
                Button {
                    value = defaultValue
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .opacity(value == defaultValue ? 0.35 : 1)
                .disabled(value == defaultValue)
                .help(L10n.resetToDefault)

                Text(valueText(value))
                    .monospacedDigit()
                    .frame(minWidth: 32, alignment: .trailing)

                Slider(value: $value, in: range, step: step)
                    .frame(width: 120)
            }
        }
    }
}
