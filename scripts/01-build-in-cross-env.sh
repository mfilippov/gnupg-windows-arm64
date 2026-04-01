#!/usr/bin/env bash
# Container entrypoint. Called by build.sh as:
#   bash /work/scripts/01-build-in-cross-env.sh

set -euxo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# HOME = /work (bind-mount root); pipeline scripts use it for patches/,
# host-tools/, and install/. It is the parent of scripts/.
HOME="$(dirname "$SCRIPT_DIR")"
export HOME
export PREFIX="$HOME/install/gnupg"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"

mkdir -p "$PREFIX"

# Download and verify sources inside the container so the host only needs Docker.
"$SCRIPT_DIR/00-download-sources.sh" main

"$SCRIPT_DIR/02-build-each.sh"
"$SCRIPT_DIR/03-fix-path.sh"

# Create the distribution archive before verifying so we validate what is actually shipped.
pushd "$HOME/install"
zip -r "$HOME/gnupg.zip" gnupg/
popd

# Verify by extracting the archive to a temp directory, not the staging tree, so
# any file that was dropped by the zip step is caught here.
VERIFY_DIR=$(mktemp -d)
trap 'rm -rf "$VERIFY_DIR"' EXIT
unzip -q "$HOME/gnupg.zip" -d "$VERIFY_DIR"
PREFIX="$VERIFY_DIR/gnupg" "$SCRIPT_DIR/04-verify-artifacts.sh"
