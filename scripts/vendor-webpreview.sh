#!/usr/bin/env bash
# Re-download vendored marked/mermaid to match scripts/webpreview/package.json.
# Run after Dependabot (or a manual bump) changes that pin.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pkg="$root/scripts/webpreview/package.json"
dest="$root/Sources/Gitgleam/WebPreview"
marked_ver="$(node -p "require('$pkg').dependencies.marked")"
mermaid_ver="$(node -p "require('$pkg').dependencies.mermaid")"

curl -fsSL -A "gitgleam-vendor" -o "$dest/marked.min.js" \
  "https://cdn.jsdelivr.net/npm/marked@${marked_ver}/marked.min.js"
curl -fsSL -A "gitgleam-vendor" -o "$dest/mermaid.min.js" \
  "https://cdn.jsdelivr.net/npm/mermaid@${mermaid_ver}/dist/mermaid.min.js"
curl -fsSL -A "gitgleam-vendor" -o "$dest/LICENSE.marked" \
  "https://cdn.jsdelivr.net/npm/marked@${marked_ver}/LICENSE.md"
curl -fsSL -A "gitgleam-vendor" -o "$dest/LICENSE.mermaid" \
  "https://cdn.jsdelivr.net/npm/mermaid@${mermaid_ver}/LICENSE" \
  || curl -fsSL -A "gitgleam-vendor" -o "$dest/LICENSE.mermaid" \
  "https://cdn.jsdelivr.net/npm/mermaid@${mermaid_ver}/LICENSE.md"

cat > "$dest/NOTICE.txt" <<EOF
Vendored JavaScript for the Markdown Web preview. Loaded from the app
bundle at runtime — no CDN, no network.

- marked ${marked_ver} (MIT) — https://github.com/markedjs/marked
  See LICENSE.marked
- mermaid ${mermaid_ver} (MIT) — https://github.com/mermaid-js/mermaid
  See LICENSE.mermaid
EOF

{
  cat <<EOF
# Third-party notices

Gitgleam itself is MIT; see [LICENSE](LICENSE).

The Markdown **Web** preview vendors two JavaScript libraries (loaded from
the app bundle over \`file://\`, no CDN). The copies that ship are under
[\`Sources/Gitgleam/WebPreview/\`](Sources/Gitgleam/WebPreview/). \`NOTICE.txt\`
in that folder travels with the binary; this file is the repo-root index.

Versions are pinned in \`scripts/webpreview/package.json\` (see
[SECURITY.md](SECURITY.md)). After a bump, \`scripts/vendor-webpreview.sh\`
refreshes the vendored files and this document.

## marked ${marked_ver}

[marked](https://github.com/markedjs/marked) — vendored as \`marked.min.js\`.
Upstream license text is also in \`Sources/Gitgleam/WebPreview/LICENSE.marked\`.

\`\`\`
EOF
  cat "$dest/LICENSE.marked"
  cat <<EOF
\`\`\`

## mermaid ${mermaid_ver}

[mermaid](https://github.com/mermaid-js/mermaid) — vendored as \`mermaid.min.js\`.
Upstream license text is also in \`Sources/Gitgleam/WebPreview/LICENSE.mermaid\`.

\`\`\`
EOF
  cat "$dest/LICENSE.mermaid"
  printf '\n\`\`\`\n'
} > "$root/THIRD_PARTY_NOTICES.md"

echo "Vendored marked ${marked_ver} and mermaid ${mermaid_ver} into $dest"
