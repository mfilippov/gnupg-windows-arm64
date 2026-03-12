FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    automake \
    bash \
    build-essential \
    ca-certificates \
    cmake \
    curl \
    file \
    gettext \
    gnupg \
    qt6-tools-dev-tools \
    libgl-dev \
    libtool \
    make \
    ninja-build \
    patch \
    pkg-config \
    python3 \
    texinfo \
    wget \
    unzip \
    xz-utils \
    zip \
    && rm -rf /var/lib/apt/lists/*

ENV CROSS_TRIPLE=aarch64-w64-mingw32
ENV CROSS_ROOT=/usr/xcc/${CROSS_TRIPLE}-cross
ARG LLVM_MINGW_VERSION=20260311

COPY toolchain.lock /tmp/toolchain.lock
RUN set -e; \
    case "$(uname -m)" in \
      x86_64)  LLVM_ARCH=x86_64  ;; \
      aarch64) LLVM_ARCH=aarch64 ;; \
      *) echo "Unsupported host arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    ARCHIVE="llvm-mingw-${LLVM_MINGW_VERSION}-ucrt-ubuntu-22.04-${LLVM_ARCH}.tar.xz"; \
    SHA256=$(awk -F'|' -v a="$ARCHIVE" 'NF>=3 && $1==a {print $3}' /tmp/toolchain.lock); \
    URL=$(awk -F'|' -v a="$ARCHIVE" 'NF>=2 && $1==a {print $2}' /tmp/toolchain.lock); \
    if [ -z "$SHA256" ] || [ -z "$URL" ]; then \
        echo "ERROR: no entry for $ARCHIVE in toolchain.lock" >&2; exit 1; \
    fi; \
    mkdir -p ${CROSS_ROOT}; \
    wget -qO "/tmp/${ARCHIVE}" "$URL"; \
    echo "${SHA256}  /tmp/${ARCHIVE}" | sha256sum -c -; \
    tar xJf "/tmp/${ARCHIVE}" --strip 1 -C ${CROSS_ROOT}/; \
    rm "/tmp/${ARCHIVE}"

ENV CC=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-gcc \
    CXX=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-g++ \
    AR=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-ar \
    AS=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-as \
    LD=${CROSS_ROOT}/bin/${CROSS_TRIPLE}-ld

ENV PATH=${PATH}:${CROSS_ROOT}/bin:/usr/lib/qt6/bin

WORKDIR /work
