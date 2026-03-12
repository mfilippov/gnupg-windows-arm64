#!/usr/bin/env bash

set -euxo pipefail

pushd "$PREFIX/bin"

# pinentry.exe is a symbolic link to pinentry-w32.exe, which Windows does not support.
rm pinentry.exe
mv pinentry-w32.exe pinentry.exe

# Move libexec helpers into bin/.
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
    gpgme-config \
    gpgme-tool.exe \
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

# include/: keep only headers present in the official installer + gpgme
pushd "$PREFIX/include"
rm -f gpgrt.h ntbtls.h sqlite3.h sqlite3ext.h zconf.h zlib.h
popd

# lib/: rename .dll.a -> .imp to match official installer, remove internal-only libs
pushd "$PREFIX/lib"
for lib in libassuan libgcrypt libgpg-error libgpgme libksba libnpth; do
    if [[ -f "${lib}.dll.a" ]]; then
        mv "${lib}.dll.a" "${lib}.imp"
    fi
done
# Remove internal-only and build-only files
rm -f \
    libntbtls.dll.a libntbtls.def \
    libsqlite3.dll.a \
    libz.dll.a libz.def libz.a \
    libassuan.def \
    gpgme.def \
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

# share/doc/gnupg/: keep only pwpattern.list
pushd "$PREFIX/share/doc/gnupg"
find . ! -path "./examples/pwpattern.list" ! -path "./examples" ! -path "." -delete
popd

# Remove sbin (never populated on Windows cross-builds)
rm -rf "$PREFIX/sbin"
