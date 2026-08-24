#!/usr/bin/env bash
# Verify vendored WebPreview JS matches the pinned npm versions, then audit
# those pins for known vulnerabilities. Used by CI and by local `swift test`
# (the Swift tests cover the version sync; this script adds `npm audit`).
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
notice="$root/Sources/Gitgleam/WebPreview/NOTICE.txt"
marked_js="$root/Sources/Gitgleam/WebPreview/marked.min.js"
mermaid_js="$root/Sources/Gitgleam/WebPreview/mermaid.min.js"
pkg_dir="$root/scripts/webpreview"
pkg="$pkg_dir/package.json"

if ! command -v node >/dev/null || ! command -v npm >/dev/null; then
  echo "check-webpreview-deps: node and npm are required (e.g. via nvm)." >&2
  exit 1
fi

notice_marked="$(sed -nE 's/^- marked ([^ ]+).*/\1/p' "$notice")"
notice_mermaid="$(sed -nE 's/^- mermaid ([^ ]+).*/\1/p' "$notice")"
pkg_marked="$(node -p "require('$pkg').dependencies.marked")"
pkg_mermaid="$(node -p "require('$pkg').dependencies.mermaid")"

fail=0
if [[ "$notice_marked" != "$pkg_marked" ]]; then
  echo "marked version mismatch: NOTICE.txt has $notice_marked, package.json has $pkg_marked" >&2
  fail=1
fi
if [[ "$notice_mermaid" != "$pkg_mermaid" ]]; then
  echo "mermaid version mismatch: NOTICE.txt has $notice_mermaid, package.json has $pkg_mermaid" >&2
  fail=1
fi
if ! grep -q "marked v${pkg_marked}" "$marked_js"; then
  echo "marked.min.js does not contain 'marked v${pkg_marked}' (re-vendor after bumping package.json)" >&2
  fail=1
fi
if ! grep -q "version:\"${pkg_mermaid}\"" "$mermaid_js"; then
  echo "mermaid.min.js does not contain version:\"${pkg_mermaid}\" (re-vendor after bumping package.json)" >&2
  fail=1
fi
if [[ "$fail" -ne 0 ]]; then
  echo "Update Sources/Gitgleam/WebPreview/ to match scripts/webpreview/package.json (see scripts/vendor-webpreview.sh)." >&2
  exit 1
fi

cd "$pkg_dir"
# Lockfile-only: we never install these packages into the app; we only ask
# npm whether the pinned versions have known advisories.
npm audit --package-lock-only --audit-level=moderate
