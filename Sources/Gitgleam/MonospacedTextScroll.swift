import SwiftUI

/// A scrollable, monospaced rendering of a prebuilt `AttributedString`.
///
/// Extracted from `ColoredDiffView` so the colored diff and the `viewmd`
/// preview scroll identically. The content is a single `.fixedSize()` `Text`:
/// it sizes itself to the content in *both* axes, so long lines (wide Mermaid
/// art, code blocks) scroll horizontally. A `LazyVStack` of per-line `Text`s
/// would instead size its cross axis to the viewport and clip them. The content
/// is forced to at least the viewport size and aligned top-leading so short
/// content sits flush at the top-left rather than being centered.
struct MonospacedTextScroll: View {
    let attributed: AttributedString

    var body: some View {
        GeometryReader { geo in
            ScrollView([.horizontal, .vertical]) {
                Text(attributed)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .fixedSize()
                    .padding(8)
                    .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .topLeading)
            }
        }
    }
}
