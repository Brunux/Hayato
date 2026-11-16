# Spec 022 — Debian Packaged ARM64 Kernel & Generic Targets (`arm64-uefi`, `arm64-extlinux`)

- **Status**: in progress (code implemented and local checks green; hardware boot verification on UEFI/Extlinux pending)
- **Phase**: 8
- **Depends on**: none
- **Model**: `claude-opus-5-5` (high) — multi-repo kernel/boot contract across `lazyos-devices` and `lazyos-core` without regressing Hayato; fallback `claude-sonnet-5-5` (specs/README.md §6).
- **Branch**: `spec/022-debian-arm64-targets`
- **Plan**: [`arm64_mainline_plan.md`](https://github.com/Brunux/LazyOS) (Spec 022)
- **Old paths**: extends `scripts/lib.sh`, `scripts/install-kernel.sh`, `scripts/make-image.sh`, `scripts/make-release.sh`, `scripts/rootfs-setup.sh`, `scripts/check-core.sh`, `boot/uefi.sh`, `boot/extlinux.sh` while leaving `google-asurada` (`mediatek-mt81`) and `boot/depthcharge.sh` unchanged.

## Problem

LazyOS only builds a custom `mediatek-mt81` kernel (`google-asurada`), so generic ARM64 UEFI laptops/VMs and U-Boot/SBC boards have no bootable target profiles or release images. Recompiling upstream mainline Linux kernels for every board wastes hours in CI and on eMMC-constrained ARM hosts, whereas Debian `forky` already packages a maintained mainline kernel (`linux-image-arm64`), device-tree blobs, and multi-vendor `firmware-*` packages with security updates via `apt`.

## Scope

**In:**

- Kernel recipe `devices/kernels/debian-arm64/` (`package`: `linux-image-arm64`, `version`: `debian-pkg`, `README.md`) marking apt-delivered kernels (`KERNEL_SOURCE_TYPE="debian-pkg"`).
- Device profiles `devices/devices/arm64-uefi/` (`boot_type="uefi"`, 256 MiB FAT32 ESP, `8192 MiB` image, broad vendor firmware + `systemd-boot` + `efibootmgr`, generic `modules-initfs`) and `devices/devices/arm64-extlinux/` (`boot_type="extlinux"`, 512 MiB `/boot`, `8192 MiB` image, `u-boot-tools` + broad firmware).
- Explicit Hayato metadata (`deviceinfo_image_size_mib="6144"`, `deviceinfo_install_target="/dev/mmcblk0"`) on `devices/devices/google-asurada/deviceinfo` and migration of Hayato's strict `HZ=1000` / `MGLRU` / `schedutil` assertions into `devices/devices/google-asurada/check-device.sh` (`20-device.sh`).
- Documented optional fields in `devices/devices/_template/deviceinfo` and `devices/AGENTS.md`; `debian-pkg` support in `devices/scripts/lib-devices.sh`, `build-kernel.sh`, and `validate-devices.sh`.
- `core/` integration: `resolve_kernel_release` and `IMAGE_SIZE_MIB` defaults in `core/scripts/lib.sh`; Debian DTB sync (`/usr/lib/linux-image-*` -> `/boot/dtbs/`), `initramfs` module injection, and revision stamp update in `install-kernel.sh`; `resolve_kernel_release` in `make-image.sh`; `/etc/kernel/postinst.d/zz-lazyos-boot` hook + expanded `60-io-scheduler.rules` in `rootfs-setup.sh`; non-Hayato-agnostic MGLRU/governor logging in `check-core.sh`; generic DTB copy to `/boot/efi/dtb/` & explicit `systemd-boot` check in `boot/uefi.sh`; optional `boot_flash_spl` hook in `boot/extlinux.sh`.

**Out:**

- Pure-Rust installer engine refactoring and `ui.rs` parameterization (`spec 023`).
- Hybrid 3-target CI release matrix workflow (`.github/workflows/release.yml`) and umbrella pins (`spec 024`).

## Design

1. **Packaged Kernel Contract (`package` file)**: A kernel flavor carrying `kernels/<flavor>/package` sets `KERNEL_SOURCE_TYPE="debian-pkg"`, causing `build-kernel.sh` to exit `0` cleanly without fetching or compiling Linux sources. `KERNEL_RELEASE` is resolved dynamically after chroot apt installation from `$ROOTFS/lib/modules/*` (`sort -V | tail -n1`) via `resolve_kernel_release` in `core/scripts/lib.sh`.
2. **DTB Continuity for Debian Kernels**: Debian `linux-image-<ver>` places compiled `.dtb` trees under `/usr/lib/linux-image-<ver>/`, while LazyOS `boot/uefi.sh`, `boot/extlinux.sh`, and `install-boot.sh` expect `/boot/dtbs/`. Both `install-kernel.sh` (at image build time) and `/etc/kernel/postinst.d/zz-lazyos-boot` (on live non-`depthcharge` systems after `apt upgrade`) sync `/usr/lib/linux-image-<ver>/` into `/boot/dtbs/` and run `CONFIRM=yes /usr/libexec/lazyos/install-boot.sh`.
3. **Preserving Hayato Optimizations**: `google-asurada` retains `mediatek-mt81` (`7.2.7-mt81`), custom patches, `6144 MiB` image sizing, and `HZ=1000`/`MGLRU`/`schedutil` checks in `check-device.sh`, while shared `scripts/check-core.sh` reports kernel MGLRU/governor status informationally so stock Debian kernels pass without false failures.

## Acceptance criteria

- [x] behaviour: `./devices/scripts/validate-devices.sh` passes all profiles (`google-asurada`, `arm64-uefi`, `arm64-extlinux`, `_template`); `build-kernel.sh` exits `0` immediately on `DEVICE=arm64-uefi` and `DEVICE=arm64-extlinux`.
- [x] failure: `resolve_kernel_release` fails loudly when no `/lib/modules/*` directory exists in a target rootfs; `boot/uefi.sh` fails loudly if `systemd-boot` EFI binaries are absent from `$rootfs/usr/lib/systemd/boot/efi/`.
- [x] compatibility: `DEVICE=google-asurada` resolution (`7.2.7-mt81`, `depthcharge`, `6144 MiB`) and all `mediatek-mt81` kernel configs/patches remain untouched.
- [ ] hardware: boot CI-assembled `arm64-uefi` and `arm64-extlinux` images on physical ARM64 UEFI / U-Boot boards or QEMU `virt` and verify `./build.sh check` on Hayato after deploying updated scripts.
- [x] witness: `devices/devices/google-asurada/check-device.sh` (`20-device.sh`), `arm64-uefi/check-device.sh`, `arm64-extlinux/check-device.sh`, and `core/scripts/check-core.sh` (`10-core.sh`) verify target boot artifacts and device-specific tuning without cross-target false failures.
- [x] witness: `desktop/uis/sway/files/usr/share/doc/lazyos/05-system.md` documents `arm64-uefi`, `arm64-extlinux`, `/usr/libexec/lazyos/install-boot.sh`, and automatic `apt upgrade` kernel updates via `/etc/kernel/postinst.d/zz-lazyos-boot`.
- [x] witness: `devices/AGENTS.md` and `core/AGENTS.md` document `kernels/debian-arm64` (`KERNEL_SOURCE_TYPE="debian-pkg"`), `resolve_kernel_release`, and `/usr/lib/linux-image-*` DTB sync.
- [x] unit tests: mock `debian-pkg`, `arm64-uefi`, `arm64-extlinux`, and `google-asurada` backend checks run cleanly in `core/.github/workflows/core.yml`, and `cargo test` in `desktop/rust` remains green.

## Tests

- **Validation (`lazyos-devices`)**: `DEVICES_REPO=$PWD/devices ./devices/scripts/validate-devices.sh`.
- **Mock Integration (`lazyos-core`)**: `bash -n core/scripts/*.sh core/boot/*.sh` plus mock chroot layout tests verifying `resolve_kernel_release`, `install-kernel.sh` DTB sync on a mock `debian-pkg` rootfs, `boot/uefi.sh` (`BOOTAA64.EFI`, `lazyos.conf`, `/boot/efi/dtb/`), and `boot/extlinux.sh` (`FDTDIR /dtbs/`).
- **Workspace Regression (`lazyos-desktop`)**: `taskset -c 4-7 cargo test --manifest-path desktop/rust/Cargo.toml --workspace --all-targets -j 4`.
- **Hardware / VM**: Run `./build.sh check` on Hayato (`google-asurada`); boot CI-produced `arm64-uefi` / `arm64-extlinux` images on ARM64 hardware or QEMU `virt` UEFI.

## Risks

- A `linux-image-arm64` apt upgrade on a live `arm64-uefi` or `arm64-extlinux` machine would leave old kernel files on the FAT32 ESP or `/boot/extlinux/extlinux.conf` if the postinst hook only ran manually; mitigated by installing `/etc/kernel/postinst.d/zz-lazyos-boot` in `rootfs-setup.sh`.
- Debian `linux-image-arm64` may disable or omit `CONFIG_LRU_GEN` / `HZ=1000` by default; mitigated by scoping strict tuning failures to `google-asurada/check-device.sh`.
