#!/usr/bin/env bash
# Verify the x64 GnuPG + GPGME install tree before it is zipped.
# Must be called with $PREFIX pointing at the staged install root (gnupg/).
# Exits non-zero and prints a summary if any check fails.

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
SCRIPTS="$(dirname "$SCRIPT_DIR")"
# shellcheck source=../common.sh
source "$SCRIPTS/common.sh"

PASS=0
FAIL=0

BIN="$PREFIX/bin"

echo "=== Verify x64 GnuPG + GPGME artifacts ==="

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

echo "--- GPGME ---"
if ls "$BIN"/libgpgme-*.dll &>/dev/null 2>&1; then
    _pass "libgpgme-*.dll"
else
    _fail "libgpgme-*.dll — no match in $BIN"
fi
check_file "gpgme-w32spawn.exe" "$BIN/gpgme-w32spawn.exe"
check_file "gpgme-json.exe"     "$BIN/gpgme-json.exe"

echo "--- PE/x86-64 architecture ---"
for exe in gpg.exe gpg-agent.exe pinentry.exe dirmngr.exe; do
    check_pe_x64 "$BIN/$exe"
done

echo ""
echo "=== Result: $PASS passed, $FAIL failed ==="
[[ $FAIL -eq 0 ]]
