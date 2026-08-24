import SwiftUI

/// Segmented Diff / Preview / Web control shown on Markdown file panes.
/// Preview (viewmd) is omitted when no viewmd path is configured; Web is
/// always offered for Markdown.
struct MarkdownViewPicker: View {
    @Binding var mode: ViewMode
    var hasViewmd: Bool

    var body: some View {
        Picker("", selection: $mode) {
            Text(L10n.diffView).tag(ViewMode.diff)
            if hasViewmd {
                Text(L10n.preview).tag(ViewMode.preview)
            }
            Text(L10n.webPreview).tag(ViewMode.web)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}
