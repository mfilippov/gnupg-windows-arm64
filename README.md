# GnuPG for Windows ARM64

Cross-compiles GnuPG and pinentry for Windows ARM64 (`aarch64-w64-mingw32`)
using the [llvm-mingw](https://github.com/mstorsjo/llvm-mingw) toolchain inside
a self-contained Docker image. Produces three drop-in zip archives that share the
same `gnupg/` directory layout and can be extracted side-by-side.

Inspired by [imkiva/gnupg-windows-arm](https://github.com/imkiva/gnupg-windows-arm).

## Artifacts

| Archive | Contents |
|---|---|
| `gnupg.zip` | Full GnuPG suite + `pinentry-basic.exe` (W32 text-mode pinentry) |
| `pinentry-qt.zip` | `pinentry.exe` / `pinentry-qt.exe` (Qt6 GUI), Qt6 runtime DLLs, platform plugin |
| `gnupg-with-pinentry-qt.zip` | Combined: GnuPG suite + Qt pinentry in a single archive |

All archives extract to a `gnupg/bin/` tree. `gnupg-with-pinentry-qt.zip` is the
recommended all-in-one download — extract it and `gpg-agent` auto-discovers
`bin\pinentry.exe` (the Qt GUI) without any additional configuration.

`gnupg.zip` and `pinentry-qt.zip` are also kept as separate artifacts for
users who want to manage the Qt overlay independently.

## Component versions

| Component | Version |
|---|---|
| GnuPG | 2.5.18 |
| libgpg-error | 1.59 |
| libgcrypt | 1.12.1 |
| libassuan | 3.0.2 |
| libksba | 1.6.8 |
| npth | 1.8 |
| pinentry | 1.3.2 |
| ntbtls | 0.3.2 |
| SQLite | 3.52.0 |
| zlib | 1.3.2 |
| Qt | 6.8.3 (pinentry-qt only) |

## Usage

Requires Docker. On Linux, `sudo` is used automatically only when the current
user cannot reach the Docker socket directly (so CI runners and devcontainers
with rootless Docker work without sudo).

**Combined build** (recommended — GnuPG + Qt pinentry in one archive):
```bash
./build.sh bundle
# produces dist/gnupg.zip, dist/pinentry-qt.zip, and dist/gnupg-with-pinentry-qt.zip
```

**GnuPG only** (suite + pinentry-basic):
```bash
./build.sh gnupg
# produces dist/gnupg.zip
```

**Qt pinentry only** (overlay archive):
```bash
./build.sh pinentry-qt
# produces dist/pinentry-qt.zip
```

## Patches

[`patches/0001-secmem-Add-VirtualLock-support-for-Windows.patch`](patches/0001-secmem-Add-VirtualLock-support-for-Windows.patch)
([upstream D622](https://dev.gnupg.org/D622)) — applied to pinentry in both
build paths. Replaces the no-op `mlock()` stub on Windows with `VirtualAlloc` +
`VirtualLock` so the secure memory pool is actually locked out of swap, matching
the behaviour on Unix.

## Script overview

| Path | Role |
|---|---|
| `build.sh` | Top-level entry point: `gnupg`, `pinentry-qt`, or `bundle` target |
| `Dockerfile` | Single cross-compilation image used for both targets |
| `scripts/common.sh` | Shared helpers: sudo detection, download/verify, archive utils |
| `scripts/00-download-sources.sh` | Download, verify (SHA256 + GPG sig), and unpack sources |
| `scripts/01-build-in-cross-env.sh` | Container entrypoint: calls 02/03/04 for the given target |
| `scripts/gnupg/02-build-each.sh` | Build GnuPG components in dependency order |
| `scripts/gnupg/03-fix-path.sh` | Strip debug/dev files; move libexec helpers to bin/ |
| `scripts/gnupg/04-verify-artifacts.sh` | Verify expected PE/ARM64 binaries are present |
| `scripts/pinentry-qt/02-build-each.sh` | Build Qt6 + pinentry-qt in dependency order |
| `scripts/pinentry-qt/03-fix-path.sh` | Collect pinentry-qt runtime files into the overlay layout |
| `scripts/pinentry-qt/04-verify-artifacts.sh` | Verify expected Qt binaries and DLLs are present |
| `sources.lock` | Pinned source URLs and SHA256 checksums |
| `keys/gnupg-release.asc` | GnuPG release signing keys (used to verify gnupg.org downloads) |
| `tools/update-checksums.sh` | Recompute and update SHA256 entries in `sources.lock` |

## See Also

- https://github.com/imkiva/gnupg-windows-arm — original inspiration
- https://github.com/mstorsjo/llvm-mingw
- https://github.com/msys2/MINGW-packages/pull/13540/files
- https://dev.gnupg.org/D622 (secmem VirtualLock patch)
