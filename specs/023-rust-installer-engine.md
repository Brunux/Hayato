# Spec 023 — Pure-Rust Data-Driven Installer Engine (`lazyos installer`)

- **Status**: in progress (pure-Rust installer implemented and tests/dry-runs green; live disk install hardware verification pending)
- **Phase**: 8
- **Depends on**: spec 018, spec 022
- **Model**: `claude-opus-5-5` (high) — irreversible block-device partitioning, credential handling without leaking secrets, ChromeOS `cgpt`/`depthchargectl`/`futility` parity, and multi-boot-backend dispatch (`depthcharge`, `uefi`, `extlinux`); fallback `claude-sonnet-5-5` (specs/README.md §6).
- **Branch**: `spec/023-rust-installer-engine`
- **Plan**: [`docs/plan-installer.md`](../docs/plan-installer.md), [`specs/018-tui-installer.md`](018-tui-installer.md)
- **Old paths**: completes [`worker.rs`](../desktop/rust/crates/lazyos-cli/src/installer/worker.rs) so `lazyos installer` (`lazyos installer apply`) no longer invokes [`core/scripts/install-emmc.sh`](../core/scripts/install-emmc.sh); keeps `core/scripts/install-emmc.sh` intact as a manual/debug fallback for Hayato (`google-asurada`).

## Problem

Spec 018 built the Ratatui wizard screens for `lazyos installer`, but its execution backend (`worker.rs`) remained unfinished: it spawns `install-emmc.sh` inside an unprivileged thread, discards every Localization/Account choice (username, password, fullname, hostname, timezone, locale, keymap), hardcodes ChromeOS `depthcharge` + `Google Hayato (MT8192)` + `/dev/mmcblk0` in `ui.rs`, `preflight.rs`, and `desktop/scripts/check-desktop.sh`, lacks reattach/idle-pause/first-write cancel safety guards, and fails on UEFI/NVMe or U-Boot Extlinux boards.

## Scope

**In:**

- Pure-Rust data-driven **`deviceinfo.rs`** parsing `/etc/lazyos/deviceinfo` (fallback `/usr/share/lazyos/deviceinfo`), `/etc/lazyos/kernel-cmdline.conf`, and `/etc/lazyos/kernel-cmdline-extra` into `BootType::{Depthcharge, Uefi, Extlinux}` without shell sourcing or hardcoded board names.
- Extended **`preflight.rs`** & **`config.rs`**:
  - Hardware discovery across Devicetree model/compatible, DMI SMBIOS (`/sys/class/dmi/id/*`), and `/proc/cpuinfo` with `deviceinfo.name` fallback.
  - Whole-disk target candidate discovery excluding running `/`, `/boot`, `kern_guid=`, SPI `mtd*`, hardware `mmcblk*boot*`/`*rpmb`, and virtual pseudo disks; honors `DEVICE_BLOCK` -> `deviceinfo_install_target` -> non-USB fixed disks; detects `/etc/lazyos/installation` marker.
  - Per-`BootType` tool matrix (`Depthcharge`: `cgpt`, `mkfs.ext2`, `depthchargectl`, `futility`; `Uefi`: `mkfs.vfat` + optional `efibootmgr`; `Extlinux`: `mkfs.ext2`; common: `parted`, `mkfs.ext4`, `rsync`, `blkid`, `blockdev`, `lsblk`, `partx`, `udevadm`, `e2fsck`).
  - Password redaction (`#[serde(skip_serializing)]` / stdin secret passing) so passwords never hit argv, logs, or `/tmp`.
- Pure-Rust installation modules under `desktop/rust/crates/lazyos-cli/src/installer/`:
  - **`disk.rs`**: `udisks2` mask/stop & failure restore, preflight target revalidation, per-`BootType` GPT partitioning (`Depthcharge` GPT header zeroing + `cgpt` + `PARTN`/`PARTLABEL` assertions; `Uefi` ESP FAT32 + ext4; `Extlinux` `legacy_boot` ext2 + ext4), formatting with planned UUIDs, `/etc/fstab` rewriting (preserving auxiliary swap/user lines), clean unmount, and `e2fsck -fn`.
  - **`identity.rs`**: live `rsync -aHAX --delete --info=progress2` streaming percent progress, mountpoint dir recreation (`dev:755, proc:555, sys:555, run:755, mnt:755, media:755`), empty `0444` `/etc/machine-id`, optional SSH host key retention vs regeneration, real application of timezone/locale/keymap/hostname/UID-1000 user & `chpasswd` over stdin, and atomic `/etc/lazyos/installation` marker written last.
  - **`boot.rs`**: pre-build & `futility show` verification before destructive writes on `Depthcharge` + `p1` flash/verify; `systemd-boot` (`BOOTAA64.EFI`/`BOOTX64.EFI`, `loader/entries/lazyos.conf`, `/boot/efi/dtb/`) + optional `efibootmgr` on `Uefi`; `/boot/extlinux/extlinux.conf` + optional `/usr/libexec/lazyos/boot/extlinux-post-disk.sh` hook on `Extlinux`.
  - **`worker.rs`, `mod.rs`, `lib.rs`, `ui.rs`**: elevated execution via `sudo -n setsid systemd-inhibit ... <exe> installer apply --stdin --state-dir /run/lazyos-install`, headless `sudo lazyos installer apply --clone --confirm [--target /dev/...]`, active-install reattach, `swayidle` SIGSTOP/SIGCONT guard, `first_write` cancel lock, multi-disk selector, boot-specific partition diagrams & Completion instructions, dynamic `target_short` confirmation, and live prefilled defaults.
- Witness & `core/` fallback updates:
  - Parameterize `desktop/scripts/check-desktop.sh` (`L1244-1252`) utility checks by `deviceinfo_boot_type`.
  - Preserve [`core/scripts/install-emmc.sh`](../core/scripts/install-emmc.sh) intact as Hayato manual/debug fallback (auto-detect fixed disk when `DEVICE_BLOCK` unset, guard trailing `cgpt show` by `BOOT_TYPE`).
  - Update `core/scripts/write-sd.sh` (allow external SD writers on NVMe laptops) and `core/scripts/lib-dist.sh` (exclude `/etc/lazyos/installation`).

**Out:**

- Hybrid CI release matrix `.github/workflows/release.yml` (`spec 024`).
- LUKS2 full-disk encryption or A/B root slots (future spec).

## Design

1. **Single Data Contract Across Hardware**: `deviceinfo.rs` reads `key="value"` pairs without spawning a shell. Any future Chromebook, ARM64 laptop, or SBC only ships a `deviceinfo` file under `devices/<codename>/`; no Rust code needs board-specific `match` branches.
2. **Credential & Privilege Boundary**: The unprivileged TUI (`lazyos installer`) collects input cleanly and spawns `sudo -n setsid systemd-inhibit --what=sleep:idle:handle-lid-switch --mode=block <exe> installer apply --stdin --state-dir /run/lazyos-install`, feeding config JSON + password payload over `stdin` (`Stdio::piped()`). `worker` applies user passwords inside `chroot <mnt> chpasswd` over stdin and never logs secrets.
3. **Depthcharge Safety Parity**: On `BootType::Depthcharge`, `boot.rs` builds and `futility`-verifies the FIT kpart image *before* `disk.rs` zeros the target GPT areas, and `disk.rs` preserves `lib-cgpt.sh`'s exact protections (`PARTN` + `PARTLABEL` assertion, 33-sector trailing GPT reserve, `/dev` + `/sbin/init` check, read-only `e2fsck -fn`).
4. **Cancellability Gate (`first_write`)**: Cancel (`Esc`/stop) aborts cleanly prior to `partition`; once `partition` begins (`first_write = true`), cancel is disabled (`Esc` can detach the TUI cleanly while the `setsid` worker finishes and updates `/run/lazyos-install/state.json`).

## Acceptance criteria

- [x] behaviour: `lazyos installer` renders boot-appropriate Welcome, partition diagram (`pmOS_kernel`/`pmOS_boot`/`pmOS_root` for `depthcharge`; `lazyos_efi`/`lazyos_root` for `uefi`; `lazyos_boot`/`lazyos_root` for `extlinux`), dynamic `target_short` confirmation (`mmcblk0`/`nvme0n1`/`vda`), `--dry-run` simulation across all 3 boot types, and headless `lazyos installer apply --clone --confirm --help` syntax.
- [x] failure: running root safety check blocks overwriting active `/`, `/boot`, or `kern_guid=` parent disks; `deviceinfo` rejects malformed non-`key="value"` syntax safely; secrets never appear in `InstallConfig` debug logs or serialized public state files.
- [x] compatibility: `rofi-install` symlink still launches `lazyos installer`, existing `PHASES.len() == 6` (`all_phases_are_declared`), `colours`, `frame`, `no_alloc`, and `check-desktop.sh` checks pass across Hayato and mainline targets; `core/scripts/install-emmc.sh` stays intact and `bash -n` clean as a manual fallback.
- [ ] hardware: execute live `lazyos installer` writes against target disks across Hayato (`depthcharge`) and ARM64 UEFI / U-Boot boards and log hardware reports under `reports/`.
- [x] witness: `desktop/scripts/check-desktop.sh` (`scripts/check-system.sh`) validates `lazyos installer --check` and checks installer utilities conditionally by `deviceinfo_boot_type`.
- [x] witness: `desktop/uis/sway/files/usr/share/doc/lazyos/05-system.md` and `04-software.md` document the pure-Rust installer (`depthcharge`, `uefi`, `extlinux`), fresh user/timezone/locale/keymap application, headless `lazyos installer apply`, and `install-emmc.sh` manual fallback.
- [x] witness: `desktop/AGENTS.md` and `core/AGENTS.md` record the data-driven `deviceinfo` contract, `sudo -n setsid systemd-inhibit ... apply --stdin` privilege separation, `first_write` cancel gate, and preserved `install-emmc.sh` fallback.
- [x] unit tests: covered by `cargo test` in `lazyos-cli` (`installer::deviceinfo::tests::*`, `installer::preflight::tests::*`, `installer::disk::tests::*`, `installer::identity::tests::*`, `installer::boot::tests::*`, `installer::worker::tests::*`, `installer::ui::tests::*`, `tests/frame.rs`).

## Tests

- **Unit & Render (`cargo test`)**: `DeviceInfo` parser across `google-asurada`, `arm64-uefi`, `arm64-extlinux`, and future device fixtures; target candidate filtering (excluding SPI `mtd0`, `mmcblk0boot0`, running disk, while allowing `pmOS_kernel` targets and obeying `deviceinfo_install_target`); GPT partition sector geometry math & fstab preservation; `extlinux.conf` / `lazyos.conf` generation; `rsync --info=progress2` line parser; `InstallConfig` secret redaction; `TestBackend` UI renders at `80x24` and `152x45` across `Depthcharge`, `Uefi`, and `Extlinux`; `--dry-run` simulation for all three boot types.
- **Core Script Sanity**: `bash -n core/scripts/*.sh core/boot/*.sh` verifying `install-emmc.sh`, `write-sd.sh`, `lib-dist.sh`.
- **Hardware / VM**: Run `./build.sh check` and `lazyos installer --dry-run` on Hayato; test real installation onto secondary media or QEMU `virt` UEFI disk + reboot.

## Risks

- Changing UID 1000 username during `Fresh` install leaves stale `/home/brunux/.config/bin/...` paths inside Sway configs and `.desktop` files; mitigated in `identity.rs` by rewriting `/home/<old>` -> `/home/<new>` inside target `/etc/sway/`, `/usr/share/applications/org.lazyos.*.desktop`, `/home/<new>/.config/`, updating `/etc/sudoers.d/99-<user>`, and clearing remembered greeter state if referencing `<old>`.
- Running worker in a root process breaks unprivileged TUI polling if `XDG_RUNTIME_DIR` points to `/run/user/1000` only; mitigated by defaulting real installs to `/run/lazyos-install/` (`0755` dir, `0644` state/log) passed explicitly via `--state-dir`.
