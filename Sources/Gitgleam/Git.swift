import Foundation

/// Central place for running git against a repository.
///
/// All blocking `Process` calls live here as `nonisolated` `async` functions so
/// they never block the main actor (and thus the UI).
enum Git {
    /// Result of a single git command.
    struct Output {
        let status: Int32
        let stdout: String
        let stderr: String
    }

    /// Result of a status check: the changed files or an error message.
    enum StatusResult {
        case success([FileChange])
        case failure(String)
    }

    /// Runs `git` with the given arguments inside `path`.
    ///
    /// A GUI app does not inherit the shell PATH, so we use the absolute path to
    /// git (`/usr/bin/git`).
    static func run(_ arguments: [String], at path: String) async -> Output {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-C", path] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            // Read stdout to EOF *before* waiting. Waiting first deadlocks on any
            // output larger than the OS pipe buffer (~64 KB): git blocks writing
            // into the full pipe while we block waiting for it to exit. A big
            // commit diff exceeds that and the diff window spins forever. Draining
            // stdout as git writes it avoids the stall; git's stderr for these
            // commands is small, so reading it next is safe.
            let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            process.waitUntilExit()
            return Output(status: process.terminationStatus, stdout: out, stderr: err)
        } catch {
            return Output(status: -1, stdout: "", stderr: error.localizedDescription)
        }
    }

    /// `git init` in `path`. Used when Settings offers to initialize a folder
    /// that isn't a repository yet. The directory must already exist.
    /// Returns `nil` on success, or git's error message.
    static func initializeRepository(at path: String) async -> String? {
        let output = await run(["init"], at: path)
        guard output.status == 0 else {
            let message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "\(L10n.gitFailed) (\(output.status))" : message
        }
        return nil
    }

    /// `git status --porcelain` → list of changed files, or an error.
    static func status(at path: String) async -> StatusResult {
        let output = await run(["status", "--porcelain"], at: path)

        // git can fail without throwing (e.g. not a repo): exit code ≠ 0.
        guard output.status == 0 else {
            let message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return .failure(message.isEmpty ? "\(L10n.gitFailed) (\(output.status))" : message)
        }

        let changes = output.stdout
            .split(separator: "\n")
            .map(String.init)
            .compactMap(FileChange.init(porcelainLine:))
        return .success(changes)
    }

    /// Unified-diff context, in lines, for the concise "Diff" view — git's own
    /// default.
    static let shortDiffContext = 3
    /// Unified-diff context for the "Diff (full)" view: more lines than any
    /// file has, so git emits the whole file as context around the changes
    /// (capped at the file length) — a full-file view with the +/- lines
    /// colored in place rather than only the changed hunks.
    static let fullDiffContext = 1_000_000

    /// Fetches the diff for one file as plain text.
    ///
    /// For tracked files we compare the working tree against `HEAD` (staged and
    /// unstaged combined). Untracked files are not in git, so we compare against
    /// `/dev/null`, which shows the whole file as additions (for untracked files
    /// every line is already an addition, so `context` is a harmless no-op).
    ///
    /// `context` is `shortDiffContext` or `fullDiffContext` — see `ViewMode`'s
    /// `diff`/`diffFull` cases.
    static func diff(for change: FileChange, at path: String, context: Int = fullDiffContext) async -> String {
        let output: Output
        if change.isUntracked {
            output = await run(["diff", "--no-index", "-U\(context)", "--", "/dev/null", change.path], at: path)
        } else {
            output = await run(["diff", "HEAD", "-U\(context)", "--", change.path], at: path)
        }

        // `git diff --no-index` returns exit code 1 when there are differences —
        // that is normal here. Anything > 1 (or ≠ 0 for tracked files) is an error.
        let isError = change.isUntracked ? output.status > 1 : output.status != 0
        if isError {
            let message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "\(L10n.gitFailed) (\(output.status))" : message
        }

        if output.stdout.isEmpty {
            return L10n.noTextualDiff
        }
        return output.stdout
    }

    /// The full contents of a file at a given ref (`git show <ref>:<path>`), or
    /// `nil` on failure. Used to feed the Markdown preview the file exactly as
    /// it exists at that point (e.g. a commit's version of the file). For a
    /// commit `sha`, pass `sha` as the ref.
    static func fileContents(ref: String, file: String, at path: String) async -> String? {
        let output = await run(["show", "\(ref):\(file)"], at: path)
        guard output.status == 0 else { return nil }
        return output.stdout
    }

    /// `git log` → the most recent `limit` commits as `Commit` values.
    ///
    /// Fields are joined by `Commit.fieldSeparator` (the unit-separator control
    /// character), one commit per line. A non-zero exit (e.g. a repository with
    /// no commits yet) yields an empty list rather than an error.
    static func recentCommits(limit: Int, at path: String) async -> [Commit] {
        let fields = ["%H", "%h", "%s", "%an", "%ar", "%ad"].joined(separator: Commit.fieldSeparator)
        // `%ad` (author date) honors --date; format it as a compact timestamp.
        let output = await run(
            ["log", "-n", "\(limit)", "--date=format:%Y-%m-%d %H:%M", "--pretty=format:\(fields)"],
            at: path
        )

        guard output.status == 0 else { return [] }
        return output.stdout
            .split(separator: "\n")
            .map(String.init)
            .compactMap(Commit.init(logLine:))
    }

    /// `git show --name-status` → the files a commit changed.
    ///
    /// `--format=` drops the commit header, leaving one `STATUS<TAB>PATH` line
    /// per file. A non-zero exit yields an empty list.
    static func commitFiles(sha: String, at path: String) async -> [CommitFile] {
        let output = await run(["show", "--name-status", "--format=", sha], at: path)

        guard output.status == 0 else { return [] }
        return output.stdout
            .split(separator: "\n")
            .map(String.init)
            .compactMap(CommitFile.init(nameStatusLine:))
    }

    /// Fetches the diff a commit made to a single file, as plain text.
    ///
    /// `--format=` empties git's own commit header so it is not duplicated above
    /// the diff — the pane renders its own header. `context` is
    /// `shortDiffContext` or `fullDiffContext` — see `ViewMode`'s
    /// `diff`/`diffFull` cases. Empty output (e.g. a mode-only change) falls
    /// back to the "no textual differences" message.
    static func commitFileDiff(sha: String, file: String, at path: String, context: Int = fullDiffContext) async -> String {
        let output = await run(["show", "--patch", "--format=", "-U\(context)", sha, "--", file], at: path)

        guard output.status == 0 else {
            let message = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return message.isEmpty ? "\(L10n.gitFailed) (\(output.status))" : message
        }

        if output.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return L10n.noTextualDiff
        }
        return output.stdout
    }
}
