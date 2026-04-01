#!/usr/bin/env bash
# Build GnuPG Windows ARM64 artifacts.
# Usage: build.sh

set -euxo pipefail

# Resolve REPO to the real script directory, following symlinks portably
# (plain `readlink` with no flags works on both macOS and Linux).
_s="${BASH_SOURCE[0]}"
while [[ -L "$_s" ]]; do
  _d="$(cd "$(dirname "$_s")" && pwd)"
  _s="$(readlink "$_s")"
  [[ "$_s" == /* ]] || _s="$_d/$_s"
done
REPO="$(cd "$(dirname "$_s")" && pwd -P)"
unset _s _d
DIST="$REPO/dist"
IMAGE="gnupg-cross-builder"

# shellcheck source=scripts/common.sh
source "$REPO/scripts/common.sh"

BUILD="$REPO/build/gnupg"

rm -f  "$BUILD/gnupg.zip"
rm -rf "$BUILD/install"
# Clear extracted source trees so sources.lock / patch changes take effect on re-run.
# Downloaded archives (files) are kept to avoid re-downloading.
if [[ -d "$BUILD" ]]; then
    find "$BUILD" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} +
fi
mkdir -p "$BUILD" "$DIST"

detect_sudo

# Always build the image so Dockerfile and toolchain changes are never silently
# skipped. Docker's layer cache makes this a no-op when nothing has changed.
$SUDO docker build -t "$IMAGE" "$REPO"

# Copy scripts, patches, and source manifests into the build volume.
# Download and verification run inside the container (see 01-build-in-cross-env.sh).
cp -r "$REPO/scripts"      "$BUILD/"
cp -r "$REPO/patches"      "$BUILD/"
cp -r "$REPO/keys"         "$BUILD/"
cp    "$REPO/sources.lock" "$BUILD/"

# Run as the calling user so build artifacts are not written back as root.
$SUDO docker run --rm -v "$BUILD":/work --user "$(id -u):$(id -g)" "$IMAGE" \
    bash /work/scripts/01-build-in-cross-env.sh

# DONE — archive was created inside the container.
mv "$BUILD/gnupg.zip" "$DIST/gnupg.zip"
