#!/usr/bin/env bash
# Render the GitHub release body from the pinned component versions.
# Reads sources.lock and toolchain.lock; writes markdown to stdout.
#
# Usage:
#   ./tools/release-notes.sh              # print the notes
#   ./tools/release-notes.sh > notes.md   # capture for action-gh-release

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

# Archive basenames that are not how the project spells its own name.
display_name() {
    case "$1" in
        gnupg)           echo "GnuPG" ;;
        gpgme)           echo "GPGME" ;;
        sqlite-autoconf) echo "SQLite" ;;
        *)               echo "$1" ;;
    esac
}

# SQLite ships 3.53.4 as "3530400" (1 digit major, then 2 each for minor,
# patch and a build field that upstream leaves at 00); everything else
# already carries a dotted version.
display_version() {
    local name="$1" version="$2"
    if [[ "$name" == "sqlite-autoconf" ]]; then
        printf '%s.%s.%s\n' \
            "$((10#${version:0:1}))" "$((10#${version:1:2}))" "$((10#${version:3:2}))"
    else
        echo "$version"
    fi
}

# Strip the archive suffix and split "<project>-<version>" at the last dash.
strip_suffix() {
    local base="$1"
    base="${base%.tar.bz2}"
    base="${base%.tar.gz}"
    base="${base%.tar.xz}"
    echo "$base"
}

gnupg_version=
components=

while IFS='|' read -r archive _rest; do
    if [[ "$archive" =~ ^[[:space:]]*# ]] || [[ -z "${archive//[[:space:]]/}" ]]; then
        continue
    fi
    base=$(strip_suffix "${archive// /}")
    name="${base%-*}"
    version=$(display_version "$name" "${base##*-}")
    [[ "$name" == "gnupg" ]] && gnupg_version="$version"
    components+="| $(display_name "$name") | ${version} |"$'\n'
done < "$REPO_DIR/sources.lock"

if [[ -z "$gnupg_version" ]]; then
    echo "ERROR: no gnupg entry found in sources.lock" >&2
    exit 1
fi

# toolchain.lock entries look like llvm-mingw-20260616-ucrt-ubuntu-22.04-x86_64.tar.xz
llvm_version=$(awk -F'|' '/^llvm-mingw-/ {print $1; exit}' "$REPO_DIR/toolchain.lock" \
               | sed 's/^llvm-mingw-//; s/-ucrt.*//')

if [[ -z "$llvm_version" ]]; then
    echo "ERROR: no llvm-mingw entry found in toolchain.lock" >&2
    exit 1
fi

cat <<EOF
GnuPG ${gnupg_version} cross-compiled for Windows from upstream release
tarballs, each verified against its SHA256 and its gnupg.org signature
(see \`sources.lock\`).

## Downloads

| Archive | Target |
|---|---|
| \`gnupg-${gnupg_version}_windows_arm64.zip\` | Windows on ARM (aarch64) |
| \`gnupg-${gnupg_version}_windows_x64.zip\` | Windows x64 |

Extract anywhere; both archives unpack to a self-contained \`gnupg/\` directory.
Verify a download against the attached checksum file with
\`sha256sum --ignore-missing -c SHA256SUMS\`.

## Component versions

| Component | Version |
|---|---|
${components}
Cross-compiled with [llvm-mingw](https://github.com/mstorsjo/llvm-mingw)
${llvm_version}.
EOF
