#!/usr/bin/env bash
# Shared helpers for GnuPG Windows ARM64 build scripts.
# Source this file; do not execute it directly.

# ---------------------------------------------------------------------------
# Container runtime detection (Docker / Podman)
# ---------------------------------------------------------------------------

# Sets CONTAINER_RT to the container runtime command ("docker" or "podman")
# and SUDO to "sudo" when required (Linux + Docker without rootless access).
CONTAINER_RT=
SUDO=
detect_container_runtime() {
    # shellcheck disable=SC2034
    SUDO=
    if command -v docker &>/dev/null; then
        # shellcheck disable=SC2034
        CONTAINER_RT=docker
        if [[ "$(uname)" == "Linux" ]] && ! docker info &>/dev/null; then
            # shellcheck disable=SC2034
            SUDO=sudo
        fi
    elif command -v podman &>/dev/null; then
        # shellcheck disable=SC2034
        CONTAINER_RT=podman
    else
        echo "ERROR: neither docker nor podman found in PATH" >&2
        return 1
    fi
}

# Legacy alias — existing callers use detect_sudo + $SUDO docker …
detect_sudo() { detect_container_runtime; }

# ---------------------------------------------------------------------------
# Source verification helpers (used by download scripts on the host)
# ---------------------------------------------------------------------------

# Download a URL to a file with 5 attempts and exponential backoff (1 2 4 8 16 s).
# Usage: _curl_retry <output_file> <url>
_curl_retry() {
    local out="$1" url="$2"
    local attempt delay=1
    for attempt in 1 2 3 4 5; do
        if curl -fL --connect-timeout 30 --max-time 300 -o "$out" "$url"; then
            return 0
        fi
        if (( attempt < 5 )); then
            echo "==> Download failed (attempt $attempt/5), retrying in ${delay}s…" >&2
            sleep "$delay"
            (( delay *= 2 ))
        fi
    done
    echo "ERROR: failed to download $url after 5 attempts" >&2
    return 1
}

# Download ARCHIVE from URL, verify SHA256, and — for gnupg.org packages —
# also verify the detached GPG signature.
# Usage: download_verify <archive> <url> <sha256> [gnupg_home]
#   gnupg_home  path to a GPG homedir with the release keys; required for gnupg.org URLs.
download_verify() {
    local archive="$1" url="$2" expected_sha256="$3" gnupg_home="${4:-}"

    if [[ -f "$archive" ]] && echo "$expected_sha256  $archive" | sha256sum -c - >/dev/null 2>&1; then
        echo "==> Using cached $archive"
    else
        echo "==> Downloading $archive"
        _curl_retry "$archive" "$url"
        echo "==> Verifying SHA256 for $archive"
        echo "$expected_sha256  $archive" | sha256sum -c -
    fi

    if [[ "$url" == *"gnupg.org"* ]]; then
        if [[ -z "$gnupg_home" ]]; then
            echo "ERROR: gnupg_home not provided; pass a GPG homedir with the release keys as the 4th argument" >&2
            return 1
        fi
        echo "==> Verifying GPG signature for $archive"
        _curl_retry "${archive}.sig" "${url}.sig"
        gpg --homedir "$gnupg_home" --no-default-keyring --verify "${archive}.sig" "$archive"
        rm "${archive}.sig"
    fi
}

# Extract an archive, choosing the right tar flags from the file extension.
tar_extract() {
    local archive="$1"
    case "$archive" in
        *.tar.bz2) tar jxf "$archive" ;;
        *.tar.gz)  tar zxf "$archive" ;;
        *.tar.xz)  tar Jxf "$archive" ;;
        *) echo "ERROR: unknown archive format: $archive" >&2; return 1 ;;
    esac
}

# Return the top-level directory name that an archive extracts to
# (i.e. strip .tar.bz2 / .tar.gz / .tar.xz).
extracted_dir() {
    local archive="$1"
    local base="${archive%.tar.bz2}"
    base="${base%.tar.gz}"
    base="${base%.tar.xz}"
    echo "$base"
}

# ---------------------------------------------------------------------------
# Artifact layout checks (used by verify scripts inside the container)
# ---------------------------------------------------------------------------
# Callers must declare: PASS=0 FAIL=0

_pass() { echo "  PASS: $1"; (( PASS += 1 )); }
_fail() { echo "  FAIL: $1"; (( FAIL += 1 )); }

check_file() {
    local label="$1" path="$2"
    if [[ -f "$path" ]]; then _pass "$label"; else _fail "$label — missing: $path"; fi
}

check_absent() {
    local label="$1" path="$2"
    if [[ ! -e "$path" ]]; then _pass "$label"; else _fail "$label — unexpectedly present: $path"; fi
}

check_pe_arm64() {
    local path="$1"
    local name; name="$(basename "$path")"
    if [[ ! -f "$path" ]]; then _fail "PE/ARM64 $name — file not found"; return; fi
    local info; info="$(file "$path")"
    if echo "$info" | grep -qi "Aarch64"; then
        _pass "PE/ARM64 $name"
    else
        _fail "PE/ARM64 $name — got: $info"
    fi
}

check_pe_x64() {
    local path="$1"
    local name; name="$(basename "$path")"
    if [[ ! -f "$path" ]]; then _fail "PE/x86-64 $name — file not found"; return; fi
    local info; info="$(file "$path")"
    if echo "$info" | grep -qi "x86-64"; then
        _pass "PE/x86-64 $name"
    else
        _fail "PE/x86-64 $name — got: $info"
    fi
}
