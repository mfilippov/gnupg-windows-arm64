#!/usr/bin/env bash

set -euxo pipefail

CROSS_TRIPLE=aarch64-w64-mingw32

function libgpg-error() {
  pushd libgpg-error
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --disable-static \
    --enable-install-gpg-error-config
  # ^ since 1.47 gpg-error-config is no longer installed by default (replaced by gpgrt-config);
  #   libassuan's configure still calls gpg-error-config

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

function qtbase() {
  # Step 1: Build Qt6 natively for the host (required as QT_HOST_PATH for cross-compilation;
  # Debian packages do not ship Qt6HostInfo cmake infrastructure).
  # Skip if already built from the same qtbase tarball (SHA256 stored as sentinel).
  _qtbase_sha=$(awk -F'|' '/^qtbase-everywhere-src/{print $3}' /work/sources.lock)
  if [ "$(cat /work/qt6-host/.qtbase-sha256 2>/dev/null)" != "$_qtbase_sha" ]; then
    rm -rf /work/qt6-host /work/qtbase-host-build
    mkdir -p qtbase-host-build
    pushd qtbase-host-build
    cmake ../qtbase \
      -GNinja \
      -DCMAKE_INSTALL_PREFIX=/work/qt6-host \
      -DCMAKE_C_COMPILER=gcc \
      -DCMAKE_CXX_COMPILER=g++ \
      -DQT_BUILD_EXAMPLES=OFF \
      -DQT_BUILD_TESTS=OFF \
      -DFEATURE_dbus=OFF \
      -DFEATURE_opengl=OFF \
      -DFEATURE_sql=OFF \
      -DFEATURE_network=OFF \
      -DFEATURE_xml=OFF \
      -DFEATURE_testlib=OFF \
      -DFEATURE_printsupport=OFF \
      -DFEATURE_concurrent=OFF \
      -DFEATURE_accessibility=OFF \
      -DFEATURE_timezone=OFF \
      -DFEATURE_xcb=OFF \
      -DFEATURE_xlib=OFF
    ninja -j"$(nproc)" install
    echo "$_qtbase_sha" > /work/qt6-host/.qtbase-sha256
    popd
  fi

  # Step 2: Cross-compile Qt6 for Windows ARM64
  mkdir -p qtbase-build
  pushd qtbase-build

  # Use absolute path for toolchain file (Qt cmake looks in source dir otherwise)
  TOOLCHAIN_FILE=$(pwd)/toolchain.cmake
  cat > "$TOOLCHAIN_FILE" << 'EOF'
set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

set(CROSS_TRIPLE aarch64-w64-mingw32)
set(CROSS_ROOT /usr/xcc/${CROSS_TRIPLE}-cross)

set(CMAKE_C_COMPILER   ${CROSS_ROOT}/bin/${CROSS_TRIPLE}-gcc)
set(CMAKE_CXX_COMPILER ${CROSS_ROOT}/bin/${CROSS_TRIPLE}-g++)
set(CMAKE_RC_COMPILER  ${CROSS_ROOT}/bin/${CROSS_TRIPLE}-windres)

set(CMAKE_FIND_ROOT_PATH ${CROSS_ROOT}/${CROSS_TRIPLE})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
EOF

  cmake ../qtbase \
    -GNinja \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DQT_HOST_PATH=/work/qt6-host \
    -DQT_BUILD_EXAMPLES=OFF \
    -DQT_BUILD_TESTS=OFF \
    -DFEATURE_dbus=OFF \
    -DFEATURE_sql=OFF \
    -DFEATURE_network=OFF \
    -DFEATURE_xml=OFF \
    -DFEATURE_testlib=OFF \
    -DFEATURE_printsupport=OFF \
    -DFEATURE_concurrent=OFF \
    -DFEATURE_timezone=OFF

  ninja -j"$(nproc)" install
  popd
}

function qttranslations() {
  # .qm files are platform-independent; compile .ts → .qm with the system lrelease
  # (qt6-tools-dev-tools package, installed in the Docker image) and install to $PREFIX/translations/.
  mkdir -p "$PREFIX/translations"
  for ts in /work/qttranslations/translations/qt*.ts; do
    name=$(basename "${ts%.ts}")
    lrelease "$ts" -qm "$PREFIX/translations/${name}.qm"
  done

  # Qt does not ship English .qm files (English is built into the libraries), but Qt's
  # translation loader tries to open qt_en.qm / qtbase_en.qm on English-locale systems.
  # Create empty stub catalogs (as windeployqt does) so Qt finds them without warnings.
  local _empty_ts
  _empty_ts=$(mktemp --suffix=.ts)
  cat > "$_empty_ts" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="en_US">
</TS>
EOF
  for prefix in qt qtbase; do
    lrelease "$_empty_ts" -qm "$PREFIX/translations/${prefix}_en.qm"
  done
  rm -f "$_empty_ts"
}

function pinentry() {
  pushd pinentry
  # Apply local patches (patches/pinentry/ is component-specific)
  for p in "$HOME"/patches/pinentry/*.patch; do
    [[ -f "$p" ]] || continue
    patch -p1 < "$p" || patch -R -p1 --dry-run < "$p"
  done
  # pinentry's configure uses MOC6/RCC6/UIC6 variable names (not MOC/RCC/UIC)
  # and searches $qt6libexecdir, not $PATH. Absolute paths bypass the search.
  export MOC6=/work/qt6-host/libexec/moc
  export RCC6=/work/qt6-host/libexec/rcc
  export UIC6=/work/qt6-host/libexec/uic
  ./configure \
    --build="$(gcc -dumpmachine)" \
    --host=$CROSS_TRIPLE \
    --prefix="$PREFIX" \
    --with-libgpg-error-prefix="$PREFIX" \
    --with-libassuan-prefix="$PREFIX" \
    --enable-pinentry-qt \
    --disable-pinentry-tty \
    --disable-pinentry-curses \
    --disable-fallback-curses \
    --disable-pinentry-emacs \
    --disable-pinentry-gtk2 \
    --disable-pinentry-gnome3 \
    Qt6_DIR="$PREFIX/lib/cmake/Qt6" \
    LDFLAGS=-mwindows \
    LIBS=-lws2_32

  # The pinentry source dir contains a plain-text 'version' file (just "1.3.2").
  # The cross-compiler (llvm-mingw/clang) finds it via -I. when Qt's qtconfiginclude.h
  # does __has_include(<version>) and then #include <version>, causing a parse error.
  # Temporarily rename it so the C++ standard <version> header is not shadowed.
  mv version version.bak 2>/dev/null || true
  make -j"$(nproc)" install
  mv version.bak version 2>/dev/null || true
  popd
}

libgpg-error
libassuan
qtbase
qttranslations
pinentry
