#!/usr/bin/env bash
# Container entrypoint for x64 build. Called by build-x64.sh as:
#   bash /work/scripts/x64/01-build-in-cross-env.sh

set -euxo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SCRIPTS="$(dirname "$SCRIPT_DIR")"
# HOME = /work (bind-mount root)
HOME="$(dirname "$SCRIPTS")"
export HOME
export PREFIX="$HOME/install/gnupg"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

mkdir -p "$PREFIX"

# Download and verify sources inside the container so the host only needs Docker.
"$SCRIPTS/00-download-sources.sh" main

"$SCRIPT_DIR/02-build-each.sh"
"$SCRIPT_DIR/03-fix-path.sh"

# Create the distribution archive before verifying so we validate what is actually shipped.
pushd "$HOME/install"
zip -r "$HOME/gnupg-x64.zip" gnupg/
popd

# Verify by extracting the archive to a temp directory.
VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$VERIFY_DIR"' EXIT
unzip -q "$HOME/gnupg-x64.zip" -d "$VERIFY_DIR"
PREFIX="$VERIFY_DIR/gnupg" "$SCRIPT_DIR/04-verify-artifacts.sh"
