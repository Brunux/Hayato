# Spec 024 — Hybrid Matrix Release Pipeline & Umbrella Integration

- **Status**: in progress (workflows, build flags, and umbrella checks ready; remote CI matrix verification pending)
- **Phase**: 8
- **Depends on**: spec 022, spec 023
- **Model**: `claude-sonnet-5-5` (high) — multi-stage GitHub Actions release matrix, artifact tarball permission preservation, umbrella cross-profile checks, and submodule integration; fallback `claude-opus-5-5` (specs/README.md §6).
- **Branch**: `spec/024-hybrid-release-matrix`
- **Plan**: [`arm64_mainline_plan.md`](https://github.com/Brunux/LazyOS) (Spec 024)
- **Old paths**: generalizes `.github/workflows/release.yml`, `.github/workflows/umbrella.yml`, `core/scripts/build.sh`, and `README.md` from single-device `google-asurada` releases to three-target Hybrid Matrix releases (`google-asurada`, `arm64-uefi`, `arm64-extlinux`).

## Problem

`.github/workflows/release.yml` only builds `DEVICE=google-asurada`, running desktop builds and release imaging in a single monolithic job, and `core/scripts/build.sh` cannot reuse pre-staged desktop or kernel artifacts across matrix targets. Meanwhile `.github/workflows/umbrella.yml` only validates `google-asurada` path resolution, leaving `arm64-uefi` and `arm64-extlinux` unverified at the umbrella level.

## Scope

**In:**

- `core/scripts/build.sh`: honor `SKIP_DESKTOP_BUILD=yes` and `SKIP_KERNEL_BUILD=yes` so staged `swayfx-stage`, `workstyle-stage`, `lazyos-stage`, and `kernel-stage-mediatek-mt81` artifacts can be built once and reused across release targets.
- `.github/workflows/release.yml`:
  - Stage 1 (`verify`): checks tag/version parity (`VERSION`, `core/VERSION`, `desktop/VERSION`, `docs/releases/$tag.md`) on `v*` pushes or runs `./build.sh validate` on `workflow_dispatch`.
  - Stage 2 (parallel `ubuntu-24.04-arm`): `build-desktop` once (`./build.sh desktop`, archived with `tar | zstd` preserving modes/symlinks) + `build-hayato-kernel` (`DEVICE=google-asurada ./build.sh kernel`) only when `google-asurada` is in target matrix.
  - Stage 3 (matrix `ubuntu-24.04-arm`): builds `google-asurada` (`6144 MiB`), `arm64-uefi` (`8192 MiB`), and `arm64-extlinux` (`8192 MiB`) in parallel (`SKIP_DESKTOP_BUILD=yes SKIP_KERNEL_BUILD=yes`).
  - Stage 4 (`publish`): merges per-target `SHA256SUMS`, verifies all assets, publishes unified GitHub Release on `v*` tags (or uploads workflow artifacts on `workflow_dispatch`).
- `.github/workflows/umbrella.yml`: verifies `core/scripts/lib.sh` resolution for `google-asurada` (`source`/`depthcharge`/`6144`), `arm64-uefi` (`debian-pkg`/`uefi`/`8192`), and `arm64-extlinux` (`debian-pkg`/`extlinux`/`8192`).
- Documentation updates across `README.md` (`sudo lazyos installer apply --clone --confirm`, preserved `install-emmc.sh` fallback, `arm64-uefi`/`arm64-extlinux` releases), `desktop/uis/sway/files/usr/share/doc/lazyos/05-system.md`, and `AGENTS.md`.
- Umbrella submodule pointer updates (`devices/`, `core/`, `desktop/`) and `specs/README.md` synchronization.

**Out:**

- Self-hosted runner provisioning or container caching mirror optimization (future infra work).

## Design

1. **Zero Redundant Compilation**: `build-desktop` runs once per release and produces a single `tar.zst` preserving `0755` ELF modes and symlinks; `build-hayato-kernel` runs exclusively for `google-asurada` (`mediatek-mt81`), while `arm64-uefi` and `arm64-extlinux` obtain `linux-image-arm64` from Debian `forky` inside debootstrap.
2. **Permission-Safe Stage Transfer**: Because `actions/upload-artifact` does not preserve Unix executable permissions or kernel module symlinks, CI wraps `work/{swayfx-stage,workstyle-stage,lazyos-stage}` and `work/kernel-stage-mediatek-mt81` in `tar -cpf - ... | zstd` before upload.
3. **Unified Release Verification**: All target directories flatten into one release folder where merged `SHA256SUMS` is re-verified via `sha256sum -c` prior to `gh release create`.

## Acceptance criteria

- [x] behaviour: `./build.sh validate` and three-profile `core/scripts/lib.sh` resolution (`google-asurada`, `arm64-uefi`, `arm64-extlinux`) succeed locally and in `.github/workflows/umbrella.yml`.
- [x] failure: `verify` fails loudly if `VERSION`, `core/VERSION`, `desktop/VERSION`, or `docs/releases/$tag.md` mismatch on tag push; `core/scripts/build.sh` with missing stage under `SKIP_DESKTOP_BUILD=yes` fails cleanly at `install-*` instead of silently producing an incomplete rootfs.
- [x] compatibility: single-command local `./build.sh` without `SKIP_*` flags retains identical end-to-end behavior.
- [ ] hardware: verify `.github/workflows/release.yml` 3-target `ubuntu-24.04-arm` matrix run and boot resulting release images.
- [x] witness: `scripts/check-system.sh`, `./build.sh validate`, and `.github/workflows/specs.yml` pass cleanly.
- [x] witness: `desktop/uis/sway/files/usr/share/doc/lazyos/05-system.md` and root `README.md` reflect the 3 release targets and primary vs fallback install paths.
- [x] witness: `AGENTS.md` documents the multi-target submodule pin workflow (`core/`, `desktop/`, `devices/`).
- [x] unit tests: `cargo test` in `desktop/rust` remains green across all workspace crates after all umbrella & submodule changes.

## Tests

- **Umbrella Validation**: `./build.sh validate` + 3-profile `lib.sh` shell checks (`google-asurada`, `arm64-uefi`, `arm64-extlinux`).
- **Workspace Regression (`lazyos-desktop`)**: `taskset -c 4-7 cargo test --manifest-path desktop/rust/Cargo.toml --workspace --all-targets -j 4`.
- **Remote CI**: verify green workflows across all 4 GitHub repos (`lazyos-devices`, `lazyos-core`, `lazyos-desktop`, `LazyOS` `Specs` & `Umbrella`), plus optional `workflow_dispatch` trigger on `release.yml` to test `ubuntu-24.04-arm` target assembly without using local eMMC.

## Risks

- `actions/upload-artifact` stripping permissions or symlinks from `swayfx`/`kernel-stage`; mitigated by `tar --numeric-owner -cpf - | zstd` archiving between jobs.
- Merging per-target `SHA256SUMS` with relative paths would fail checksum verification; mitigated by `make-release.sh` emitting basename checksums (`sha256sum "${_sums[@]}"` inside `$OUTDIR`) and flattening assets prior to verification.
