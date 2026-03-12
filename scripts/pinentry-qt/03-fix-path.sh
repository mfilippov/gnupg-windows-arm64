#!/usr/bin/env bash

set -euxo pipefail

# Collect only what's needed to run pinentry-qt on Windows:
# - pinentry-qt.exe
# - Qt6 DLLs (Core, Gui, Widgets)
# - Qt6 platform plugin (qwindows.dll)
# - libgpg-error DLL
# - libassuan DLL
# - llvm-mingw C++ runtime DLLs (libc++.dll, libunwind.dll)
#   pinentry-qt.exe and all Qt DLLs import these; they are not part of
#   the Windows system and must ship with the application.

# Place everything under bin/ so the archive mirrors the gnupg.zip layout
# (gnupg/bin/…) and can be overlaid directly onto the GnuPG install tree.
# gpg-agent probes bin\pinentry.exe relative to its own location, so
# pinentry.exe must live in the same bin\ directory as gpg-agent.exe.
DIST="$(dirname "$PREFIX")/pinentry-qt-dist"
mkdir -p "$DIST/bin/platforms"

# pinentry-qt binary.
# Ship as both pinentry.exe (auto-discovered by gpg-agent on Windows) and
# pinentry-qt.exe (used when pinentry-program is set explicitly in gpg-agent.conf).
cp "$PREFIX/bin/pinentry-qt.exe" "$DIST/bin/pinentry.exe"
cp "$PREFIX/bin/pinentry-qt.exe" "$DIST/bin/pinentry-qt.exe"

# Qt6 runtime DLLs
for dll in Qt6Core Qt6Gui Qt6Widgets; do
  cp "$PREFIX/bin/${dll}.dll" "$DIST/bin/"
done

# Qt6 Windows platform plugin
cp "$PREFIX/plugins/platforms/qwindows.dll" "$DIST/bin/platforms/"

# Qt6 Windows style plugin (modern Windows 11 look)
mkdir -p "$DIST/bin/styles"
cp "$PREFIX/plugins/styles/qmodernwindowsstyle.dll" "$DIST/bin/styles/"

# gpg-error and assuan DLLs
cp "$PREFIX/bin/libgpg-error-0.dll" "$DIST/bin/"
cp "$PREFIX"/bin/libassuan-*.dll    "$DIST/bin/"

# llvm-mingw C++ runtime DLLs (required on any clean Windows machine)
# CROSS_TRIPLE and CROSS_ROOT are exported by the Dockerfile as ENV variables.
cp "${CROSS_ROOT}/${CROSS_TRIPLE}/bin/libc++.dll"    "$DIST/bin/"
cp "${CROSS_ROOT}/${CROSS_TRIPLE}/bin/libunwind.dll" "$DIST/bin/"

# Qt6 translations (Qt looks for *.qm in translations/ next to the executable)
if ls "$PREFIX/translations"/qt*.qm &>/dev/null 2>&1; then
  mkdir -p "$DIST/bin/translations"
  cp "$PREFIX/translations"/qt*.qm "$DIST/bin/translations/"
fi

# Overwrite PREFIX/install dir with the dist layout
rm -rf "$PREFIX"
mv "$DIST" "$PREFIX"
