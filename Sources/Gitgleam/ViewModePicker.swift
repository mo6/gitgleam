import SwiftUI

/// Segmented view-mode control shown on every file pane: Diff / Diff (full)
/// always, plus Preview / Web for Markdown files. Preview (viewmd) is omitted
/// when no viewmd path is configured; Web is always offered for Markdown.
struct ViewModePicker: View {
    @Binding var mode: ViewMode
    var isMarkdown: Bool
    var hasViewmd: Bool

    var body: some View {
        Picker("", selection: $mode) {
            Text(L10n.diffView).tag(ViewMode.diff)
            Text(L10n.diffFullView).tag(ViewMode.diffFull)
            if isMarkdown {
                if hasViewmd {
                    Text(L10n.preview).tag(ViewMode.preview)
                }
                Text(L10n.webPreview).tag(ViewMode.web)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}
