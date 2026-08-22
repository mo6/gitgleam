import SwiftUI
import AppKit

/// Converts ANSI (SGR) escape sequences into a colored `AttributedString` for
/// display in a monospaced `Text`.
///
/// Handles the SGR subset `viewmd` emits: reset, bold, dim, italic, underline,
/// strikethrough, the 16 basic foreground/background colors, 256-color
/// (`38;5;n`/`48;5;n`) and truecolor (`38;2;r;g;b`/`48;2;r;g;b`), plus their
/// off-switches. Other CSI sequences are parsed enough to be skipped cleanly
/// rather than rendered as stray text. OSC sequences (notably OSC 8
/// hyperlinks, `ESC]8;…`, which viewmd emits for the table of contents and
/// wikilinks) are also stripped — the link *label* between the two OSC
/// markers survives as ordinary (already-colored) text, so only the escape
/// machinery is removed.
enum ANSIText {
    /// Builds a colored `AttributedString` from ANSI text.
    ///
    /// `colorScheme` only affects 256-color/truecolor *backgrounds*
    /// (`48;5;n` / `48;2;r;g;b`) — viewmd's fixed palette (including the
    /// `viewmd:mark` highlight) is tuned for a dark terminal and, as of this
    /// writing, renders identically regardless of the `--theme` flag Gitgleam
    /// passes it (see `Viewmd.render`). Left as-is, those backgrounds read as
    /// a muddy dark box on a light-mode window, so in `.light` they're
    /// blended toward white here. The 16 basic ANSI colors (`40`-`47`,
    /// `100`-`107`) already map to semantic, theme-aware colors (`.primary`,
    /// `.secondary`, …) and are untouched.
    static func attributed(from ansi: String, colorScheme: ColorScheme = .dark) -> AttributedString {
        var result = AttributedString()
        var style = Style()
        let scalars = Array(ansi.unicodeScalars)
        var i = 0
        var runStart = 0

        func flushRun(upTo end: Int) {
            guard end > runStart else { return }
            let text = String(String.UnicodeScalarView(scalars[runStart..<end]))
            var run = AttributedString(text)
            style.apply(to: &run, colorScheme: colorScheme)
            result.append(run)
        }

        while i < scalars.count {
            guard scalars[i].value == 0x1B else { i += 1; continue } // ESC
            flushRun(upTo: i)

            // CSI: ESC '[' params finalByte. SGR ends in 'm'; other final bytes
            // (cursor moves, etc.) are consumed and ignored.
            if i + 1 < scalars.count, scalars[i + 1] == "[" {
                // CSI: ESC '[' params finalByte (0x40–0x7E). SGR ends in 'm';
                // other final bytes (cursor moves, etc.) are consumed and ignored.
                var j = i + 2
                while j < scalars.count, !(scalars[j].value >= 0x40 && scalars[j].value <= 0x7E) {
                    j += 1
                }
                if j < scalars.count {
                    if scalars[j] == "m" {
                        let params = String(String.UnicodeScalarView(scalars[(i + 2)..<j]))
                        style.applySGR(params)
                    }
                    i = j + 1
                } else {
                    i = j // unterminated sequence: drop the rest
                }
            } else if i + 1 < scalars.count, scalars[i + 1] == "]" {
                // OSC (e.g. OSC 8 hyperlinks): consume through BEL or ST (ESC \).
                // The label text between the two OSC markers is left intact.
                var j = i + 2
                osc: while j < scalars.count {
                    switch scalars[j].value {
                    case 0x07: // BEL terminator
                        j += 1
                        break osc
                    case 0x1B: // ESC — start of ST (ESC \), or a stray ESC; end either way
                        j += (j + 1 < scalars.count && scalars[j + 1] == "\\") ? 2 : 1
                        break osc
                    default:
                        j += 1
                    }
                }
                i = j
            } else {
                i += 1 // lone ESC (or ESC + other): drop it
            }
            runStart = i
        }
        flushRun(upTo: scalars.count)
        return result
    }

    // MARK: - SGR state

    /// The currently-active text attributes, updated by each SGR sequence.
    private struct Style {
        var color: Color?
        var backgroundColor: Color?
        /// True when `backgroundColor` came from `48;5;n`/`48;2;r;g;b` (a
        /// fixed, non-theme-aware RGB), as opposed to the semantic `40`-`47`/
        /// `100`-`107` codes. Only an extended background gets lightened for
        /// `.light` — see `attributed(from:colorScheme:)`.
        var backgroundIsExtended = false
        var bold = false
        var dim = false
        var italic = false
        var underline = false
        var strikethrough = false

        mutating func applySGR(_ params: String) {
            // An empty parameter list (`ESC[m`) means reset, same as `0`.
            let codes = params.split(separator: ";", omittingEmptySubsequences: false)
                .map { Int($0) ?? 0 }
            if codes.isEmpty { self = Style(); return }

            var k = 0
            while k < codes.count {
                switch codes[k] {
                case 0: self = Style()
                case 1: bold = true
                case 2: dim = true
                case 3: italic = true
                case 4: underline = true
                case 9: strikethrough = true
                case 22: bold = false; dim = false
                case 23: italic = false
                case 24: underline = false
                case 29: strikethrough = false
                case 30...37: color = Self.basic[codes[k] - 30]
                case 90...97: color = Self.bright[codes[k] - 90]
                case 39: color = nil
                case 40...47: backgroundColor = Self.basic[codes[k] - 40]; backgroundIsExtended = false
                case 100...107: backgroundColor = Self.bright[codes[k] - 100]; backgroundIsExtended = false
                case 49: backgroundColor = nil; backgroundIsExtended = false
                case 38: // extended foreground: 38;5;n or 38;2;r;g;b
                    let ext = Self.parseExtendedColor(codes, from: k)
                    if let c = ext.color { color = c }
                    k += ext.advance
                case 48: // extended background: 48;5;n or 48;2;r;g;b
                    let ext = Self.parseExtendedColor(codes, from: k)
                    if let c = ext.color { backgroundColor = c; backgroundIsExtended = true }
                    k += ext.advance
                default: break // other codes ignored
                }
                k += 1
            }
        }

        func apply(to run: inout AttributedString, colorScheme: ColorScheme) {
            if let color {
                run.foregroundColor = dim ? color.opacity(0.6) : color
            } else if dim {
                run.foregroundColor = Color.primary.opacity(0.6)
            }
            if let backgroundColor {
                let bg = (backgroundIsExtended && colorScheme == .light)
                    ? Self.lightened(backgroundColor) : backgroundColor
                run.backgroundColor = dim ? bg.opacity(0.6) : bg
            }
            if bold || italic {
                var font = Font.system(.body, design: .monospaced)
                if bold { font = font.bold() }
                if italic { font = font.italic() }
                run.font = font
            }
            if underline { run.underlineStyle = .single }
            if strikethrough { run.strikethroughStyle = .single }
        }

        /// Blends `color` toward white by `fraction`, for an extended
        /// background rendered in `.light`. Falls back to the original color
        /// if it can't be converted to device RGB (shouldn't happen for the
        /// sRGB colors this file constructs).
        static func lightened(_ color: Color, by fraction: Double = 0.55) -> Color {
            guard let rgb = NSColor(color).usingColorSpace(.deviceRGB) else { return color }
            func mix(_ c: CGFloat) -> Double { Double(c) * (1 - fraction) + fraction }
            return Color(
                .sRGB, red: mix(rgb.redComponent), green: mix(rgb.greenComponent), blue: mix(rgb.blueComponent),
                opacity: 1
            )
        }

        /// Parses a `5;n` (256-color) or `2;r;g;b` (truecolor) operand that
        /// follows a `38`/`48` at `from`. Returns the color (if any) and how
        /// many extra indices to advance past.
        static func parseExtendedColor(_ codes: [Int], from: Int) -> (advance: Int, color: Color?) {
            guard from + 1 < codes.count else { return (0, nil) }
            if codes[from + 1] == 5, from + 2 < codes.count {
                return (2, color256(codes[from + 2]))
            }
            if codes[from + 1] == 2, from + 4 < codes.count {
                return (4, Color(.sRGB,
                                 red: Double(codes[from + 2]) / 255,
                                 green: Double(codes[from + 3]) / 255,
                                 blue: Double(codes[from + 4]) / 255,
                                 opacity: 1))
            }
            return (0, nil)
        }

        // The 16 terminal colors. Black/white map to `.primary` so default text
        // stays legible (and theme-aware) instead of forcing pure black/white.
        static let basic: [Color] = [
            .primary, .red, .green, .yellow, .blue, .purple, .cyan, .primary,
        ]
        static let bright: [Color] = [
            .secondary, .red, .green, .yellow, .blue, .purple, .cyan, .primary,
        ]

        /// xterm 256-color index → `Color` (16 base, 6×6×6 cube, grayscale ramp).
        static func color256(_ n: Int) -> Color {
            switch n {
            case 0...7: return basic[n]
            case 8...15: return bright[n - 8]
            case 16...231:
                let c = n - 16
                let level = { (v: Int) -> Double in v == 0 ? 0 : Double(55 + v * 40) / 255 }
                return Color(.sRGB,
                             red: level((c / 36) % 6),
                             green: level((c / 6) % 6),
                             blue: level(c % 6),
                             opacity: 1)
            default: // 232...255 grayscale
                let v = Double(8 + max(0, n - 232) * 10) / 255
                return Color(.sRGB, red: v, green: v, blue: v, opacity: 1)
            }
        }
    }
}
