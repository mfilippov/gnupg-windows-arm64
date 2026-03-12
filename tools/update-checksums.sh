#!/usr/bin/env bash
# Recompute SHA256 checksums for all entries in sources.lock.
# Run this after bumping any version or URL in sources.lock.
#
# Usage:
#   ./tools/update-checksums.sh           # show diff only
#   ./tools/update-checksums.sh --apply   # write changes to sources.lock

set -euo pipefail

_s="${BASH_SOURCE[0]}"
while [[ -L "$_s" ]]; do
  _d="$(cd "$(dirname "$_s")" && pwd)"
  _s="$(readlink "$_s")"
  [[ "$_s" == /* ]] || _s="$_d/$_s"
done
SCRIPT_DIR="$(cd "$(dirname "$_s")" && pwd -P)"
unset _s _d
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOCK="$REPO_DIR/sources.lock"
APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

TMPDIR_WORK=$(mktemp -d)
# NEW_LOCK sits next to sources.lock so it persists after the temp dir is removed.
NEW_LOCK="$LOCK.new"

# Temporary isolated keyring for verifying gnupg.org release signatures.
GNUPG_HOME=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK" "$GNUPG_HOME"' EXIT
gpg --homedir "$GNUPG_HOME" --no-default-keyring \
    --import "$REPO_DIR/keys/gnupg-release.asc" 2>/dev/null

echo "==> Downloading and hashing all sources..." >&2

while IFS= read -r line; do
    # Preserve comments and blank lines unchanged
    if [[ "$line" =~ ^[[:space:]]*# ]] || [[ -z "${line//[[:space:]]/}" ]]; then
        printf '%s\n' "$line"
        continue
    fi

    IFS='|' read -r archive url _old_sha256 builds dir <<< "$line"
    archive="${archive// /}"
    url="${url// /}"
    builds="${builds// /}"
    dir="${dir// /}"

    echo "  Downloading $archive..." >&2
    curl -fL --retry 3 -o "$TMPDIR_WORK/$archive" "$url"

    if [[ "$url" == *"gnupg.org"* ]]; then
        echo "  Verifying GPG signature for $archive..." >&2
        curl -fL --retry 3 -o "$TMPDIR_WORK/${archive}.sig" "${url}.sig"
        gpg --homedir "$GNUPG_HOME" --no-default-keyring \
            --verify "$TMPDIR_WORK/${archive}.sig" "$TMPDIR_WORK/$archive"
    fi

    if command -v sha256sum &>/dev/null; then
        new_sha256=$(sha256sum "$TMPDIR_WORK/$archive" | cut -d' ' -f1)
    else
        new_sha256=$(shasum -a 256 "$TMPDIR_WORK/$archive" | cut -d' ' -f1)
    fi
    printf '%s|%s|%s|%s|%s\n' "$archive" "$url" "$new_sha256" "$builds" "$dir"
done < "$LOCK" > "$NEW_LOCK"

echo "" >&2
echo "==> Diff (--- old  +++ new):" >&2
diff -u "$LOCK" "$NEW_LOCK" || true

if $APPLY; then
    mv "$NEW_LOCK" "$LOCK"
    echo "" >&2
    echo "==> sources.lock updated." >&2
else
    echo "" >&2
    echo "==> Rerun with --apply to write changes, or:" >&2
    echo "    cp '$NEW_LOCK' '$LOCK'" >&2
    echo "    (file is preserved at $NEW_LOCK)" >&2
fi
