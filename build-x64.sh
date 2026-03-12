#!/usr/bin/env bash
# Build GnuPG + GPGME Windows x64 artifacts.
# Usage: build-x64.sh

set -euxo pipefail

# Resolve REPO to the real script directory, following symlinks portably
_s="${BASH_SOURCE[0]}"
while [[ -L "$_s" ]]; do
  _d="$(cd "$(dirname "$_s")" && pwd)"
  _s="$(readlink "$_s")"
  [[ "$_s" == /* ]] || _s="$_d/$_s"
done
REPO="$(cd "$(dirname "$_s")" && pwd -P)"
unset _s _d
DIST="$REPO/dist"
IMAGE="gnupg-x64-builder"

# shellcheck source=scripts/common.sh
source "$REPO/scripts/common.sh"

BUILD="$REPO/build/x64"

rm -f  "$BUILD/gnupg-x64.zip"
rm -rf "$BUILD/install"
# Clear extracted source trees so sources.lock / patch changes take effect on re-run.
# Downloaded archives (files) are kept to avoid re-downloading.
if [[ -d "$BUILD" ]]; then
    find "$BUILD" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} +
fi
mkdir -p "$BUILD" "$DIST"

detect_container_runtime

# Always build the image so Dockerfile changes are never silently skipped.
$SUDO $CONTAINER_RT build -t "$IMAGE" -f "$REPO/Dockerfile.x64" "$REPO"

# Copy scripts, patches, and source manifests into the build volume.
cp -r "$REPO/scripts"      "$BUILD/"
cp -r "$REPO/patches"      "$BUILD/"
cp -r "$REPO/keys"         "$BUILD/"
cp    "$REPO/sources.lock" "$BUILD/"

# Run as the calling user so build artifacts are not written back as root.
# Docker needs --user to avoid root-owned files; Podman is already rootless.
# MSYS_NO_PATHCONV prevents Git-for-Windows / MSYS2 from mangling /work into
# a Windows path (e.g. "C:\Program Files\Git\work").
_user_flag=()
if [[ "$CONTAINER_RT" == "docker" ]]; then
    _user_flag=(--user "$(id -u):$(id -g)")
fi
MSYS_NO_PATHCONV=1 $SUDO $CONTAINER_RT run --rm -v "$BUILD":/work "${_user_flag[@]}" "$IMAGE" \
    bash /work/scripts/x64/01-build-in-cross-env.sh

# DONE — archive was created inside the container.
mv "$BUILD/gnupg-x64.zip" "$DIST/gnupg-x64.zip"
