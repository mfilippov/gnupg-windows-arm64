#!/usr/bin/env bash
# Verify the pinentry-qt install tree before it is zipped.
# Must be called with $PREFIX pointing at the staged install root (gnupg/).
# Exits non-zero and prints a summary if any check fails.

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=../common.sh
source "$(dirname "$SCRIPT_DIR")/common.sh"

PASS=0
FAIL=0

BIN="$PREFIX/bin"

echo "=== Verify pinentry-qt artifacts ==="

echo "--- pinentry binaries ---"
check_file "pinentry.exe"    "$BIN/pinentry.exe"
check_file "pinentry-qt.exe" "$BIN/pinentry-qt.exe"

echo "--- Qt6 runtime DLLs ---"
for dll in Qt6Core.dll Qt6Gui.dll Qt6Widgets.dll; do
    check_file "$dll" "$BIN/$dll"
done

echo "--- Qt6 platform plugin ---"
check_file "platforms/qwindows.dll" "$BIN/platforms/qwindows.dll"

echo "--- Qt6 style plugin ---"
check_file "styles/qmodernwindowsstyle.dll" "$BIN/styles/qmodernwindowsstyle.dll"

echo "--- GnuPG runtime DLLs ---"
check_file "libgpg-error-0.dll" "$BIN/libgpg-error-0.dll"
if ls "$BIN"/libassuan-*.dll &>/dev/null 2>&1; then
    _pass "libassuan-*.dll"
else
    _fail "libassuan-*.dll — no match in $BIN"
fi

echo "--- llvm-mingw C++ runtime DLLs ---"
check_file "libc++.dll"    "$BIN/libc++.dll"
check_file "libunwind.dll" "$BIN/libunwind.dll"

echo "--- PE/ARM64 architecture ---"
for exe in pinentry.exe pinentry-qt.exe Qt6Core.dll; do
    check_pe_arm64 "$BIN/$exe"
done

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
