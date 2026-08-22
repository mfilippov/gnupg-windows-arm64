# GnuPG for Windows ARM64

Cross-compiles GnuPG and pinentry for Windows ARM64 (`aarch64-w64-mingw32`)
using the [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) toolchain inside
a self-contained Docker image. Produces a drop-in zip archive that extracts to a
`gnupg/` directory layout ready for use.

Inspired by [imkiva/gnupg-windows-arm](https://github.com/imkiva/gnupg-windows-arm).

## Artifacts

| Archive | Contents |
|---|---|
| `gnupg.zip` | Full GnuPG suite + `pinentry.exe` (modernized W32 pinentry with visual styles and DPI awareness) |

## Component versions

| Component | Version |
|---|---|
| GnuPG | 2.5.21 |
| libgpg-error | 1.61 |
| libgcrypt | 1.12.2 |
| libassuan | 3.0.2 |
| libksba | 1.8.0 |
| npth | 1.8 |
| pinentry | 1.3.3 |
| ntbtls | 0.3.2 |
| SQLite | 3.53.4 |
| zlib | 1.3.2 |
| GPGME | 2.1.2 |

## Usage

Requires Docker or Podman. On Linux, `sudo` is used automatically only when the
current user cannot reach the Docker socket directly (so CI runners and
devcontainers with rootless Docker work without sudo). Where SELinux is
enforcing, the build volume is mounted with `:z` so the container can read it.

```bash
./build.sh
# produces dist/gnupg.zip
```

## Patches

[`patches/pinentry/0001-secmem-Add-VirtualLock-support-for-Windows.patch`](patches/pinentry/0001-secmem-Add-VirtualLock-support-for-Windows.patch)
([upstream D622](https://dev.gnupg.org/D622)) — replaces the no-op `mlock()`
stub on Windows with `VirtualAlloc` + `VirtualLock` so the secure memory pool
is actually locked out of swap, matching the behaviour on Unix.

[`patches/pinentry/0003-w32-Improve-foreground-window-activation.patch`](patches/pinentry/0003-w32-Improve-foreground-window-activation.patch)
— uses a minimize/restore trick followed by `SetForegroundWindow` and
`BringWindowToTop` to reliably bring the pinentry dialog to the foreground.

[`patches/pinentry/0004-w32-Fix-pointer-truncation-in-WM_CTLCOLORSTATIC-hand.patch`](patches/pinentry/0004-w32-Fix-pointer-truncation-in-WM_CTLCOLORSTATIC-hand.patch)
— returns the brush handle through `INT_PTR` instead of a truncating `int`,
which is required on 64-bit Windows (including ARM64).

Patches retired upstream (no longer carried here):

| Patch | Landed in |
|---|---|
| gnupg `scd:openpgp` CHV1 retry counter byte index | GnuPG 2.5.21 |
| pinentry w32 dialog modernization (visual styles, DPI, DIALOGEX) | pinentry 1.3.3 |
| pinentry `w32/logo-*.bmp` with `LR_LOADTRANSPARENT`-safe palettes | pinentry 1.3.3 |
| GPGME assuan-support / w32spawn function pointer types | GPGME 2.1.x |

## Script overview

| Path | Role |
|---|---|
| `build.sh` | Top-level entry point |
| `Dockerfile` | Single cross-compilation image |
| `scripts/common.sh` | Shared helpers: sudo detection, download/verify, archive utils |
| `scripts/00-download-sources.sh` | Download, verify (SHA256 + GPG sig), and unpack sources |
| `scripts/01-build-in-cross-env.sh` | Container entrypoint: calls 02/03/04 and creates the zip |
| `scripts/02-build-each.sh` | Build GnuPG components in dependency order |
| `scripts/03-fix-path.sh` | Strip debug/dev files; move libexec helpers to bin/ |
| `scripts/04-verify-artifacts.sh` | Verify expected PE/ARM64 binaries are present |
| `sources.lock` | Pinned source URLs and SHA256 checksums |
| `keys/gnupg-release.asc` | GnuPG release signing keys (used to verify gnupg.org downloads) |
| `tools/update-checksums.sh` | Recompute and update SHA256 entries in `sources.lock` |

## See Also

- https://github.com/imkiva/gnupg-windows-arm — original inspiration
- https://github.com/mstorsjo/llvm-mingw
- https://github.com/msys2/MINGW-packages/pull/13540/files
- https://dev.gnupg.org/D622 (secmem VirtualLock patch)
