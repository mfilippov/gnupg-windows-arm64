#!/usr/bin/env bash
# Build GnuPG Windows ARM64 artifacts.
# Usage: build.sh <target>
#   target  gnupg               — core GnuPG suite → dist/gnupg.zip
#           pinentry-qt         — Qt pinentry add-on → dist/pinentry-qt.zip
#           bundle              — both of the above merged → dist/gnupg-with-pinentry-qt.zip

set -euxo pipefail

TARGET="${1:?Usage: $0 <target>  (gnupg | pinentry-qt | bundle)}"

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

if [[ "$TARGET" == "bundle" ]]; then
    # Always build fresh components so the bundle is never silently stale.
    "$REPO/build.sh" gnupg
    "$REPO/build.sh" pinentry-qt

    detect_sudo

    COMBINED="$REPO/build/bundle"
    rm -rf "$COMBINED"
    mkdir -p "$COMBINED"

    # Ensure the image is current (sub-builds already ran docker build, but
    # a concurrent prune could have removed it between the two calls).
    $SUDO docker build -t "$IMAGE" "$REPO"

    # Merge both archives inside the container so the host only needs Docker.
    # gnupg.zip intentionally omits pinentry.exe; pinentry-qt.zip adds it as the
    # Qt GUI build so gpg-agent auto-discovers the right binary in the bundle.
    rm -f "$DIST/gnupg-with-pinentry-qt.zip"
    $SUDO docker run --rm \
        -v "$DIST":/dist \
        -v "$COMBINED":/combined \
        --user "$(id -u):$(id -g)" "$IMAGE" \
        bash -c 'unzip -qo /dist/gnupg.zip -d /combined \
            && unzip -qn /dist/pinentry-qt.zip -d /combined \
            && cd /combined \
            && zip -r /dist/gnupg-with-pinentry-qt.zip gnupg/'
    rm -rf "$COMBINED"
    exit 0
fi

case "$TARGET" in
    gnupg|pinentry-qt) ;;
    *) echo "ERROR: unknown target '$TARGET'. Use 'gnupg', 'pinentry-qt', or 'bundle'." >&2; exit 1 ;;
esac

BUILD="$REPO/build/$TARGET"

rm -f  "$BUILD/$TARGET.zip"
rm -rf "$BUILD/install"
# Clear extracted source trees so sources.lock / patch changes take effect on re-run.
# Downloaded archives (files) are kept to avoid re-downloading.
# Qt build caches (qt6-host, qtbase-*-build) are preserved to avoid a full Qt rebuild.
if [[ -d "$BUILD" ]]; then
    find "$BUILD" -maxdepth 1 -mindepth 1 -type d \
        ! -name qt6-host ! -name qtbase-host-build ! -name qtbase-build \
        -exec rm -rf {} +
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
    bash /work/scripts/01-build-in-cross-env.sh "$TARGET"

# DONE — archive was created inside the container.
mv "$BUILD/$TARGET.zip" "$DIST/$TARGET.zip"
