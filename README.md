<p align="center"><img src="desktop/brand/social-preview.png" width="720" alt="Hayato_ - Debian for ARM Chromebooks &amp; Mainline ARM64. Keyboard first. Light. Fast. Fun."></p>

# Hayato (`0.6.0`)

**Website:** [brunux.github.io/Hayato](https://brunux.github.io/Hayato/) · **Brand:** [`desktop/brand/`](https://github.com/Brunux/hayato-desktop/tree/main/brand)

A **Debian arm64** (`forky`) desktop OS built for MediaTek ChromeOS Chromebooks
(`google-asurada` MT8192 & `google-kukui` MT8183) and generic ARM64 systems, now
organized as a clean umbrella hub over three modular
public repositories designed for effortless ARM64 mainline porting and small LLM context windows.

The name is a Japanese word for a falconer; the mascot is a **golden eagle**; the session defaults to
**Tokyo Night**; the promise is **light. fast. fun.** There is no Japanese visual identity - the
word carries the idea, and the eagle carries the attitude. `desktop/brand/` is the source of the
mark, and `specs/026-hayato-rebrand.md` is the change that got here.

| Submodule | Repository | Owns |
|---|---|---|
| [`core/`](https://github.com/Brunux/hayato-core) | `Brunux/hayato-core` | Debian arm64 rootfs builder, pluggable boot backends (`depthcharge`, `uefi`, `extlinux`), installers (`write-sd.sh`, fallback `install-emmc.sh`), release sanitizer (`make-release.sh`), backup/restore, `10-core.sh` witness |
| [`desktop/`](https://github.com/Brunux/hayato-desktop) | `Brunux/hayato-desktop` | Wayland SwayFX session, `rust/` multi-call `hayato` TUI/CLI/installer/greeter/notify/MCP suite, theme engine, Nerd Font glyphs, icons, user manual (`doc/hayato/`), `30-desktop.sh` witness |
| [`devices/`](https://github.com/Brunux/hayato-devices) | `Brunux/hayato-devices` | `debian-arm64` packaged kernel (`linux-image-arm64`), mainline Linux `arm64-mainline` + composable SoC Kconfig fragments, `mediatek-mt81`, declarative `devices/_template/`, `20-device.sh` witnesses |
| `.` (Umbrella) | `Brunux/Hayato` | Submodule pins, root `./build.sh` wrapper, landing site (`site/`), release notes (`docs/releases/`), hardware reports (`reports/`), design specs (`specs/`) |

## Clone & Build

```sh
git clone --recursive https://github.com/Brunux/Hayato.git
cd Hayato

DEVICE=google-asurada sudo ./core/scripts/00-deps.sh   # host build dependencies (Debian / Alpine)
DEVICE=google-asurada ./build.sh                       # kernel + swayfx + workstyle + hayato + rootfs + kpart
DEVICE=google-asurada sudo ./build.sh sd /dev/mmcblk1  # flash microSD/USB
```

Useful `./build.sh` targets:
- `./build.sh kernel` — Build and stage device kernel (`devices/scripts/build-kernel.sh`)
- `./build.sh desktop` — Stage SwayFX, Workstyle, and Rust `hayato` binaries
- `./build.sh rootfs` — Debootstrap Debian `forky` arm64 and install kernel + desktop
- `./build.sh image [IMG]` — Build sanitized disk image via configured `boot_type`
- `./build.sh release [DIR]` — Build sanitized, compressed `<target>.img.xz` release image and `SHA256SUMS`
- `./build.sh check` — Run modular health verification (`10-core.sh` + `20-device.sh` + `30-desktop.sh`)
- `./build.sh validate` — Validate devices, Kconfig fragments, shell scripts, and umbrella paths

## Flashing a Release Image

Releases ship four targets built on ARM64 runners via our Hybrid Matrix workflow:
- **`google-asurada.img.xz`** (`6144 MiB`) — Google Hayato Chromebook (MT8192, custom `mediatek-mt81` kernel with optimizations + `depthcharge`)
- **`google-kukui.img.xz`** (`6144 MiB`) — Google Kukui Chromebook family (MT8183: Lenovo IdeaPad Duet `krane`, `kodama`, `kakadu`, `katsu`, `jacuzzi`, shared `mediatek-mt81` kernel + `depthcharge`)
- **`arm64-uefi.img.xz`** (`8192 MiB`) — Generic ARM64 UEFI laptops, desktops, and VMs (Debian `linux-image-arm64` + `systemd-boot` + multi-vendor firmware)
- **`arm64-extlinux.img.xz`** (`8192 MiB`) — Generic ARM64 U-Boot SBCs (Debian `linux-image-arm64` + `/boot/extlinux/extlinux.conf` + multi-vendor firmware)

1. Download the desired `<target>.img.xz` and `SHA256SUMS` from [Releases](https://github.com/Brunux/Hayato/releases).
2. Verify checksum and write to a microSD/USB drive:
   ```sh
   sha256sum -c --ignore-missing SHA256SUMS
   xz -dc <target>.img.xz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```
3. Boot the external drive (on ChromeOS developer mode: `crossystem dev_boot_usb=1 dev_boot_signed_only=0`, Ctrl+U / external disk). Default live account: user `brunux`, password `debian` (`sudo` enabled).
4. Optionally install onto internal storage using the pure-Rust installer:
   ```sh
   hayato installer                                  # full-screen TUI wizard (user, timezone, target selection)
   sudo hayato installer apply --clone --confirm     # headless live-clone install
   # Hayato manual fallback if needed:
   CONFIRM=yes sudo /usr/libexec/hayato/install-emmc.sh
   ```

## Adding a New ARM64 Board

All hardware support lives cleanly inside [`hayato-devices`](https://github.com/Brunux/hayato-devices):
1. Copy `devices/_template/` to `devices/<codename>/`.
2. Set `deviceinfo_boot_type` (`extlinux`, `uefi`, or `depthcharge`), `deviceinfo_arch`, and `deviceinfo_dtb`.
3. Select `debian-arm64` (Debian packaged `linux-image-arm64`) or `arm64-mainline` (composable Kconfig fragments `chromebook-ec`, `rockchip-rk3588`, `qcom-laptop`, `rpi5`) in `kernel`.
4. Place board-specific udev rules, services, or keymaps under `devices/<codename>/files/` and hardware tests in `check-device.sh`.

## Screenshots & Evidence

- Desktop, TUI launcher, themes, and hardware screenshots live in [`docs/screenshots/`](docs/screenshots/).
- Real hardware boot & check-system captures live in [`reports/`](reports/).
- Active specs & release notes live in [`specs/`](specs/) and [`docs/releases/`](docs/releases/).
