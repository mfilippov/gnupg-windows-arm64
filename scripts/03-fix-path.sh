#!/usr/bin/env bash

set -euxo pipefail

pushd "$PREFIX/bin"

# pinentry.exe is a symbolic link to pinentry-w32.exe, which Windows does not support.
# Replace the symlink with the real binary so gpg-agent auto-discovers it.
rm pinentry.exe
mv pinentry-w32.exe pinentry.exe

# Move libexec helpers into bin/. On Windows, gnupg_libexecdir() is hardwired
# to return bindir (HAVE_W32_SYSTEM), so scdaemon, keyboxd, dirmngr_ldap, and
# gpg-check-pattern must live alongside the other executables; the upstream
# NSIS installer does the same copy.
mv "$PREFIX"/libexec/*.exe "$PREFIX"/bin/
rm -rf "$PREFIX"/libexec

# Remove developer/debug tools not present in the official installer
rm -f \
    dirmngr-client.exe \
    dumpsexp.exe \
    gpg-authcode-sign.sh \
    gpg-error.exe \
    gpg-error-config \
    gpg-pair-tool.exe \
    gpg-protect-tool.exe \
    gpgrt-config \
    gpgscm.exe \
    hmac256.exe \
    kbxutil.exe \
    ksba-config \
    libassuan-config \
    libgcrypt-config \
    mpicalc.exe \
    ntbtls-config \
    yat2m.exe

popd

# include/: keep only headers present in the official installer
pushd "$PREFIX/include"
rm -f gpgrt.h ntbtls.h sqlite3.h sqlite3ext.h zconf.h zlib.h
popd

# lib/: rename .dll.a → .imp to match official installer, remove internal-only libs
pushd "$PREFIX/lib"
# Rename public import libs to .imp (official installer convention)
for lib in libassuan libgcrypt libgpg-error libksba libnpth; do
    mv "${lib}.dll.a" "${lib}.imp"
done
# Remove internal-only and build-only files
rm -f \
    libntbtls.dll.a libntbtls.def \
    libsqlite3.dll.a \
    libz.dll.a libz.def libz.a \
    libassuan.def \
    libgcrypt.def \
    libgpg-error.def \
    libksba.def \
    libnpth.def \
    npth.def \
    ./*.la
rm -rf pkgconfig
popd

# share/: remove directories not present in the official installer
pushd "$PREFIX/share"
rm -rf aclocal common-lisp info libgpg-error man sbin
popd

# share/gnupg/: keep distsigkey.gpg and all help.*.txt files.
# common/helpfile.c probes help.<lang>.txt before falling back to help.txt,
# so these are live runtime data used by display_online_help() and pinentry
# tooltips under non-English locales.

# share/doc/gnupg/: keep only pwpattern.list
pushd "$PREFIX/share/doc/gnupg"
find . ! -path "./examples/pwpattern.list" ! -path "./examples" ! -path "." -delete
popd

# Remove sbin (never populated on Windows cross-builds)
rm -rf "$PREFIX/sbin"
