import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// The Repositories tab: an editable list of `RepoConfig` — drag to reorder;
/// per-repo pause/path/thresholds/remove live behind each row's ⋯ button —
/// plus Add / Export / Import below the list.
struct RepositoriesSettingsView: View {
    @ObservedObject var settings: Settings

    private var listShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if settings.repos.count >= AppConfig.repoCountCap {
                warning(L10n.repositoryLimitReached(AppConfig.repoCountCap))
            } else if settings.repos.count >= AppConfig.repoCountWarning {
                warning(L10n.repositoryCountWarning(settings.repos.count))
            }

            Group {
                if settings.repos.isEmpty {
                    VStack(spacing: 4) {
                        Text(L10n.noRepositoriesConfigured)
                        Text(L10n.noRepositoriesConfiguredDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } else {
                    VStack(spacing: 0) {
                        ForEach($settings.repos) { $repo in
                            RepositoryRow(
                                repo: $repo,
                                globalWarn: settings.warnThreshold,
                                globalCritical: settings.criticalThreshold,
                                isDuplicate: RepoConfig.isDuplicate(
                                    repo.path, among: settings.repos, excluding: repo.id
                                ),
                                onDelete: { settings.repos.removeAll { $0.id == repo.id } },
                                onMoveFrom: { fromID in move(fromID, onto: repo.id) },
                                onChoosePath: { choosePath(for: repo.id, current: repo.path) }
                            )
                            if repo.id != settings.repos.last?.id {
                                Divider()
                                    .padding(.horizontal, 14)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(listShape.fill(Color.primary.opacity(0.05)))
            .clipShape(listShape)

            HStack {
                Button(L10n.exportSettings) { exportSettings() }
                Button(L10n.importSettings) { importSettings() }
                Spacer()
                Button(L10n.addRepository) { addRepository() }
                    .disabled(settings.repos.count >= AppConfig.repoCountCap)
            }
        }
    }

    private func warning(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.orange)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Moves the dragged repo (`fromID`) to the position of the drop target.
    private func move(_ fromID: String, onto ontoID: UUID) -> Bool {
        guard let from = settings.repos.firstIndex(where: { $0.id.uuidString == fromID }),
              let to = settings.repos.firstIndex(where: { $0.id == ontoID }),
              from != to
        else { return false }
        settings.repos.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        return true
    }

    private func addRepository() {
        guard settings.repos.count < AppConfig.repoCountCap else { return }
        guard let url = pickFolder(startingAt: nil) else { return }
        confirmPath(url.path) {
            settings.repos.append(RepoConfig(path: url.path, label: url.lastPathComponent))
        }
    }

    private func choosePath(for id: UUID, current: String) {
        guard let url = pickFolder(startingAt: current) else { return }
        confirmPath(url.path, replacing: id) {
            if let i = settings.repos.firstIndex(where: { $0.id == id }) {
                settings.repos[i].path = url.path
            }
        }
    }

    private func pickFolder(startingAt path: String?) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.choose
        if let path {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// Duplicate warning, then not-a-git-repo (Initialize / Add anyway / Cancel).
    /// `accept` runs only if the user confirms.
    private func confirmPath(_ path: String, replacing id: UUID? = nil, accept: @escaping () -> Void) {
        if RepoConfig.isDuplicate(path, among: settings.repos, excluding: id) {
            let alert = NSAlert()
            alert.messageText = L10n.duplicateRepositoryWarning
            alert.informativeText = L10n.duplicateRepositoryPrompt
            alert.addButton(withTitle: L10n.addAnyway)
            alert.addButton(withTitle: L10n.cancel)
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        if RepoConfig.looksLikeGitRepository(at: path) {
            accept()
            return
        }
        let alert = NSAlert()
        alert.messageText = L10n.notAGitRepositoryWarning
        alert.informativeText = L10n.notAGitRepositoryAddPrompt
        alert.addButton(withTitle: L10n.initializeGitRepository)
        alert.addButton(withTitle: L10n.addAnyway)
        alert.addButton(withTitle: L10n.cancel)
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task {
                if let message = await Git.initializeRepository(at: path) {
                    await MainActor.run {
                        presentError(title: L10n.notAGitRepositoryWarning, message: message)
                    }
                } else {
                    await MainActor.run { accept() }
                }
            }
        case .alertSecondButtonReturn:
            accept()
        default:
            break
        }
    }

    private func exportSettings() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "gitgleam-settings.json"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try settings.exportedJSON().write(to: url)
        } catch {
            presentError(title: L10n.exportSettingsFailed, message: error.localizedDescription)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.importSettings
        guard panel.runModal() == .OK, let url = panel.url else { return }

        let confirm = NSAlert()
        confirm.messageText = L10n.importSettingsConfirm
        confirm.informativeText = L10n.importSettingsConfirmDescription
        confirm.addButton(withTitle: L10n.importSettings)
        confirm.addButton(withTitle: L10n.cancel)
        guard confirm.runModal() == .alertFirstButtonReturn else { return }

        do {
            try settings.importJSON(Data(contentsOf: url))
        } catch {
            presentError(title: L10n.importSettingsFailed, message: error.localizedDescription)
        }
    }

    private func presentError(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: L10n.cancel)
        alert.runModal()
    }
}

/// One repository row: name and path on the left, warning icons and a
/// System Settings-style ⋯ button on the right that opens per-repo options.
private struct RepositoryRow: View {
    @Binding var repo: RepoConfig
    let globalWarn: Int
    let globalCritical: Int
    let isDuplicate: Bool
    let onDelete: () -> Void
    let onMoveFrom: (String) -> Bool
    let onChoosePath: () -> Void
    @State private var showingSettings = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .help(L10n.dragToReorder)
                .draggable(repo.id.uuidString)

            VStack(alignment: .leading, spacing: 4) {
                TextField(L10n.repositoryLabel, text: $repo.label)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .medium))
                Text(repo.path)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .opacity(repo.isEnabled ? 1 : 0.55)

            Spacer(minLength: 12)

            if isDuplicate {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(L10n.duplicateRepositoryWarning)
            }
            if !RepoConfig.looksLikeGitRepository(at: repo.path) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .help(L10n.notAGitRepositoryWarning)
            }

            Button {
                showingSettings.toggle()
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L10n.repositorySettings)
            .popover(isPresented: $showingSettings, arrowEdge: .trailing) {
                RepositorySettingsPopover(
                    repo: $repo,
                    globalWarn: globalWarn,
                    globalCritical: globalCritical,
                    onChoosePath: onChoosePath,
                    onDelete: {
                        showingSettings = false
                        onDelete()
                    }
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first else { return false }
            return onMoveFrom(id)
        }
    }
}

/// Per-repo options shown from the row's ⋯ button: watch/pause, folder,
/// threshold overrides, and remove.
private struct RepositorySettingsPopover: View {
    @Binding var repo: RepoConfig
    let globalWarn: Int
    let globalCritical: Int
    let onChoosePath: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(L10n.pauseRepository, isOn: $repo.isEnabled)

            Divider()

            Button(L10n.changeRepositoryFolder, action: onChoosePath)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.thresholds)
                Picker("", selection: customThresholds) {
                    Text(L10n.useAppDefaults).tag(false)
                    Text(L10n.customThresholds).tag(true)
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                if usesCustomThresholds {
                    stepper(label: L10n.warnThreshold, value: warnBinding, range: 1...criticalBinding.wrappedValue)
                    stepper(label: L10n.criticalThreshold, value: criticalBinding, range: warnBinding.wrappedValue...200)
                }
            }

            Divider()

            Button(L10n.removeRepository, role: .destructive, action: onDelete)
        }
        .padding(14)
        .frame(width: 280, alignment: .leading)
    }

    private func stepper(label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Stepper(value: value, in: range) {
                Text("\(value.wrappedValue)")
                    .monospacedDigit()
                    .frame(minWidth: 24, alignment: .trailing)
            }
        }
        .font(.system(size: 12))
    }

    private var usesCustomThresholds: Bool {
        repo.warnThreshold != nil || repo.criticalThreshold != nil
    }

    private var customThresholds: Binding<Bool> {
        Binding(
            get: { usesCustomThresholds },
            set: { on in
                if on {
                    repo.warnThreshold = repo.warnThreshold ?? globalWarn
                    repo.criticalThreshold = repo.criticalThreshold ?? globalCritical
                } else {
                    repo.warnThreshold = nil
                    repo.criticalThreshold = nil
                }
            }
        )
    }

    private var warnBinding: Binding<Int> {
        Binding(
            get: { repo.warnThreshold ?? globalWarn },
            set: { repo.warnThreshold = max(1, min($0, repo.criticalThreshold ?? globalCritical)) }
        )
    }

    private var criticalBinding: Binding<Int> {
        Binding(
            get: { repo.criticalThreshold ?? globalCritical },
            set: { repo.criticalThreshold = max(repo.warnThreshold ?? globalWarn, $0) }
        )
    }
}
