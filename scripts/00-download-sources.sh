#!/usr/bin/env bash
# Download, verify, and extract source archives for the requested build tag.
# Usage: 00-download-sources.sh <tag>
#   tag  one of: main
# Only archives whose 'builds' column contains <tag> are processed.

set -euxo pipefail

BUILD_TAG="${1:?Usage: $0 <tag>  (main or qt)}"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOCK="$(dirname "$SCRIPT_DIR")/sources.lock"

# shellcheck source=scripts/common.sh
source "$SCRIPT_DIR/common.sh"

# Set up a temporary GPG keyring with the pinned release keys.
GNUPG_HOME=$(mktemp -d)
trap 'rm -rf "$GNUPG_HOME"' EXIT
gpg --homedir "$GNUPG_HOME" --no-default-keyring --import "$(dirname "$SCRIPT_DIR")/keys/gnupg-release.asc"

while IFS='|' read -r archive url sha256 builds dir; do
    # skip comments and blank lines
    [[ "$archive" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${archive//[[:space:]]/}" ]] && continue
    # only process entries tagged for this build
    [[ ",$builds," == *",$BUILD_TAG,"* ]] || continue

    if [[ -d "$dir" ]]; then
        echo "==> Skipping $archive (already extracted to $dir/)"
        continue
    fi
    download_verify "$archive" "$url" "$sha256" "$GNUPG_HOME"
    tar_extract "$archive"
    mv "$(extracted_dir "$archive")/" "$dir/"
done < "$LOCK"
