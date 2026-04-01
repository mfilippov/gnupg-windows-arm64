#!/usr/bin/env bash
# Verify the main GnuPG install tree before it is zipped.
# Must be called with $PREFIX pointing at the staged install root (gnupg/).
# Exits non-zero and prints a summary if any check fails.

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

PASS=0
FAIL=0

BIN="$PREFIX/bin"

echo "=== Verify main GnuPG artifacts ==="

echo "--- Core executables ---"
for exe in gpg.exe gpgv.exe gpg-agent.exe gpgsm.exe gpgconf.exe gpgtar.exe \
           gpg-connect-agent.exe dirmngr.exe; do
    check_file "$exe" "$BIN/$exe"
done

echo "--- libexec helpers (must be in bin/ on Windows) ---"
for exe in scdaemon.exe keyboxd.exe dirmngr_ldap.exe gpg-check-pattern.exe; do
    check_file "$exe" "$BIN/$exe"
done

echo "--- pinentry ---"
check_file   "pinentry.exe"              "$BIN/pinentry.exe"
check_absent "pinentry-w32.exe removed"  "$BIN/pinentry-w32.exe"
check_absent "libexec/ moved away"       "$PREFIX/libexec"

echo "--- Required DLLs ---"
for dll in libgpg-error-0.dll libgcrypt-20.dll libksba-8.dll \
           libnpth-0.dll libntbtls-0.dll libsqlite3-0.dll zlib1.dll; do
    check_file "$dll" "$BIN/$dll"
done
if ls "$BIN"/libassuan-*.dll &>/dev/null 2>&1; then
    _pass "libassuan-*.dll"
else
    _fail "libassuan-*.dll — no match in $BIN"
fi

echo "--- PE/ARM64 architecture ---"
for exe in gpg.exe gpg-agent.exe pinentry.exe dirmngr.exe; do
    check_pe_arm64 "$BIN/$exe"
done

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
