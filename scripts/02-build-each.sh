#!/usr/bin/env bash

set -euxo pipefail

CROSS_TRIPLE=aarch64-w64-mingw32

function libgpg-error() {
  pushd libgpg-error
  # Apply local patches (patches/libgpg-error/ is component-specific)
  for p in "$HOME"/patches/libgpg-error/*.patch; do
    [[ -f "$p" ]] || continue
    patch -p1 < "$p" || patch -R -p1 --dry-run < "$p"
  done
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --enable-install-gpg-error-config
  # ^ since 1.47 gpg-error-config is no longer installed by default (replaced by gpgrt-config);
  #   downstream packages (libgcrypt, libksba, ntbtls…) still call gpg-error-config in configure

  make -j"$(nproc)" install
  # Install native yat2m (built for host) so gnupg can generate man pages.
  # Write to $HOME/host-tools (bind-mounted /work) — /usr/local/bin is
  # root-owned and inaccessible when the container runs as the caller UID.
  mkdir -p "$HOME/host-tools"
  cp doc/yat2m-for-build "$HOME/host-tools/yat2m"
  export PATH="$HOME/host-tools:$PATH"
  popd
}

function zlib() {
  pushd zlib
  # Use win32/Makefile.gcc for proper Windows DLL (zlib1.dll) cross-compilation
  make -j"$(nproc)" -f win32/Makefile.gcc \
    CC=${CROSS_TRIPLE}-gcc \
    AR=${CROSS_TRIPLE}-ar \
    RC=${CROSS_TRIPLE}-windres \
    STRIP=${CROSS_TRIPLE}-strip \
    SHAREDLIB=zlib1.dll \
    SHAREDLIBV=zlib1.dll \
    SHAREDLIBM=zlib1.dll \
    BINARY_PATH="$PREFIX/bin" \
    INCLUDE_PATH="$PREFIX/include" \
    LIBRARY_PATH="$PREFIX/lib" \
    SHARED_MODE=1
  make -f win32/Makefile.gcc install \
    SHARED_MODE=1 \
    SHAREDLIB=zlib1.dll \
    SHAREDLIBV=zlib1.dll \
    SHAREDLIBM=zlib1.dll \
    BINARY_PATH="$PREFIX/bin" \
    INCLUDE_PATH="$PREFIX/include" \
    LIBRARY_PATH="$PREFIX/lib"
  # Install pkg-config file
  ZLIB_VERSION=$(grep '#define ZLIB_VERSION' zlib.h | cut -d'"' -f2)
  sed "s|@prefix@|$PREFIX|g;s|@exec_prefix@|\${prefix}|g;s|@libdir@|\${exec_prefix}/lib|g;s|@sharedlibdir@|\${exec_prefix}/bin|g;s|@includedir@|\${prefix}/include|g;s|@VERSION@|${ZLIB_VERSION}|g" zlib.pc.in > "$PREFIX/lib/pkgconfig/zlib.pc"
  popd
}

function libgcrypt() {
  pushd libgcrypt
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX"

  make -j"$(nproc)" install
  popd
}

function libassuan() {
  pushd libassuan
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX"

  make -j"$(nproc)" install
  popd
}

function libksba() {
  pushd libksba
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX"

  make -j"$(nproc)" install
  popd
}

function npth() {
  pushd npth
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static

  make -j"$(nproc)" install
  popd
}

function sqlite() {
  pushd sqlite
  # Build DLL directly from amalgamation - sqlite 3.52+ autoconf Makefile
  # renames the DLL via --dll-basename which breaks standard make targets
  ${CROSS_TRIPLE}-gcc -shared -O2 \
    -DSQLITE_ENABLE_FTS3 \
    -DSQLITE_ENABLE_FTS5 \
    -DSQLITE_ENABLE_JSON1 \
    -DSQLITE_ENABLE_MATH_FUNCTIONS \
    -DSQLITE_ENABLE_PERCENTILE \
    -DSQLITE_ENABLE_RTREE \
    -DSQLITE_THREADSAFE=1 \
    '-DSQLITE_API=__declspec(dllexport)' \
    -Wl,--out-implib,"$PREFIX/lib/libsqlite3.dll.a" \
    -o "$PREFIX/bin/libsqlite3-0.dll" \
    sqlite3.c
  install -m 644 sqlite3.h sqlite3ext.h "$PREFIX/include/"
  # Generate pkg-config file
  SQLITE_VERSION=$(grep '#define SQLITE_VERSION ' sqlite3.h | cut -d'"' -f2)
  mkdir -p "$PREFIX/lib/pkgconfig"
  cat > "$PREFIX/lib/pkgconfig/sqlite3.pc" << EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: SQLite
Description: SQL database engine
Version: $SQLITE_VERSION
Libs: -L\${libdir} -lsqlite3
Cflags: -I\${includedir}
EOF
  popd
}

function ntbtls() {
  pushd ntbtls
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX" \
    --with-libgcrypt-prefix="$PREFIX" \
    --with-ksba-prefix="$PREFIX"

  make -j"$(nproc)" install
  popd
}

function pinentry() {
  pushd pinentry
  # Apply local patches (patches/pinentry/ is component-specific)
  for p in "$HOME"/patches/pinentry/*.patch; do
    [[ -f "$p" ]] || continue
    patch -p1 < "$p" || patch -R -p1 --dry-run < "$p"
  done
  # Copy binary files that cannot be represented in unified diffs
  # (regenerated BMP logos with correct palettes for LR_LOADTRANSPARENT).
  cp "$HOME"/patches/pinentry/w32-files/*.bmp w32/
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX" \
    --with-libassuan-prefix="$PREFIX" \
    --disable-pinentry-qt \
    --disable-pinentry-tty \
    --disable-pinentry-curses \
    --disable-fallback-curses \
    --disable-pinentry-emacs \
    --disable-pinentry-gtk2 \
    --disable-pinentry-gnome3 \
    LIBS=-lws2_32

  make -j"$(nproc)" install
  popd
}

function gnupg() {
  pushd gnupg
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX" \
    --with-libassuan-prefix="$PREFIX" \
    --with-libgcrypt-prefix="$PREFIX" \
    --with-libksba-prefix="$PREFIX" \
    --with-npth-prefix="$PREFIX" \
    --with-ntbtls-prefix="$PREFIX" \
    --with-zlib="$PREFIX"
  make -j"$(nproc)" install
  popd
}

function gpgme() {
  pushd gpgme
  # Apply local patches (patches/gpgme/ is component-specific)
  for p in "$HOME"/patches/gpgme/*.patch; do
    [[ -f "$p" ]] || continue
    patch -p1 < "$p" || patch -R -p1 --dry-run < "$p"
  done
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --with-libgpg-error-prefix="$PREFIX" \
    --with-libassuan-prefix="$PREFIX" \
    --enable-languages=
  # Build and install only the library and docs; the tests/ subdirectory
  # tries to import GPG test keys via gpg-agent, which cannot start
  # inside the cross-compilation container.
  make -j"$(nproc)" -C src
  make -C src install
  make -C doc install
  popd
}

libgpg-error
zlib
libgcrypt
libassuan
libksba
npth
sqlite
ntbtls
pinentry
gnupg
gpgme
