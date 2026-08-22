import Foundation

/// Runs the external `viewmd` tool to render Markdown to ANSI-colored text.
///
/// Like `Git`, the blocking `Process` work lives here as a `nonisolated async`
/// function so it never blocks the main actor. The rendered ANSI is turned into
/// a colored `AttributedString` by `ANSIText` for display.
enum Viewmd {
    /// Result of a render: the ANSI-colored text, or an error message.
    enum RenderResult {
        case success(String)
        case failure(String)
    }

    /// viewmd's `--theme` values Gitgleam can request. Mirrors the window's
    /// `colorScheme` — see `render(theme:)`.
    enum Theme: String {
        case dark, light
    }

    /// Renders `markdown` through the `viewmd` launcher at `viewmdPath`.
    ///
    /// The content is written to a temporary `.md` file and passed as viewmd's
    /// positional argument (rather than piped on stdin): this keeps the call a
    /// simple one-directional read of stdout — no double-ended-pipe deadlock to
    /// manage — and lets viewmd see a real filename. `--color=always` forces
    /// ANSI even though our pipe is not a TTY; `--no-toc` suppresses viewmd's
    /// generated heading table of contents (the file's own content is what we
    /// want to preview, not a navigation aid); `VIEWMD_NO_CONFIG` makes the
    /// render independent of any per-user viewmd config file so width/color/toc
    /// are exactly what we ask for. `--theme` selects viewmd's dark- or
    /// light-tuned palette (its own default is `dark`, and `auto`-detection
    /// relies on a terminal OSC 11 query that a `Process` pipe can't answer,
    /// so the caller must pass the window's actual `colorScheme` explicitly —
    /// otherwise viewmd's dark palette, including its `viewmd:mark` highlight
    /// background, renders muddy against a light-mode window).
    ///
    /// When `keepDebugFile` is set (the Settings window's debug toggle), the
    /// input file is written to `/tmp/` instead of the private, auto-cleaned
    /// temporary directory, and is left there instead of being removed — so
    /// the exact Markdown (including `viewmd:mark` sentinels) fed to viewmd
    /// can be inspected afterwards.
    static func render(
        markdown: String, width: Int, viewmdPath: String, theme: Theme, keepDebugFile: Bool = false
    ) async -> RenderResult {
        let directory = keepDebugFile
            ? URL(fileURLWithPath: "/tmp")
            : FileManager.default.temporaryDirectory
        let tmp = directory.appendingPathComponent("gitgleam-preview-\(UUID().uuidString).md")
        do {
            try Data(markdown.utf8).write(to: tmp)
        } catch {
            return .failure(error.localizedDescription)
        }
        defer { if !keepDebugFile { try? FileManager.default.removeItem(at: tmp) } }

        let process = Process()
        // Launch via /bin/bash so viewmd.sh's shebang/PATH assumptions don't
        // matter in a GUI app that doesn't inherit the shell environment.
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            viewmdPath, "--no-pager", "--color=always", "--no-toc",
            "--width", "\(width)", "--theme", theme.rawValue, tmp.path,
        ]
        var env = ProcessInfo.processInfo.environment
        env["VIEWMD_NO_CONFIG"] = "1"
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .failure(error.localizedDescription)
        }

        // Drain stdout before waiting, for the same reason `Git.run` does: a
        // large render can exceed the OS pipe buffer and deadlock otherwise.
        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let message = err.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(message.isEmpty ? "\(L10n.viewmdFailed) (\(process.terminationStatus))" : message)
        }
        return .success(out)
    }
}
