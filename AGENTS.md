# AGENTS.md — `Hayato` Umbrella Repository

## Architecture & LLM Routing Map
`Brunux/Hayato` is the umbrella orchestrator tying together **three focused sub-repositories**
as Git submodules so models and contributors work inside the relevant bounded domain (~10% of the
old monorepo context) before updating submodule pins here.

| Task Domain | Submodule / Repo | Enter Here First |
|---|---|---|
| Wayland desktop (`swayfx`), Rust `hayato` TUI/CLI/greeter/notify/theme/MCP, icons, glyphs, user manual (`doc/hayato/`), `30-desktop.sh` | `desktop/` (`Brunux/hayato-desktop`) | `desktop/AGENTS.md` |
| Kernel recipes (`arm64-mainline` + fragments, `mediatek-mt81`), board definitions (`devices/<codename>/`), udev/keyd/IRQ/board overlays, `20-device.sh` | `devices/` (`Brunux/hayato-devices`) | `devices/AGENTS.md` |
| Debian arm64 rootfs assembly, pluggable boot backends (`boot/{depthcharge,uefi,extlinux}.sh`), installers, backup/restore, release imaging, `10-core.sh` | `core/` (`Brunux/hayato-core`) | `core/AGENTS.md` |
| Website (`site/`), release notes (`docs/releases/`), hardware test logs (`reports/`), design specs (`specs/`), root `./build.sh` wrapper | `.` (`Brunux/Hayato`) | This file |

## Quick Routing Rules
- **UI, Rust binary (`hayato`), theme, Waybar, Sway bindings, or manual pages (`01`–`07`)**:
  Work exclusively inside `desktop/`. Pin Cargo builds/Clippy/tests on 8-core ARM64 hosts to big
  cores: `taskset -c 4-7 cargo <cmd> --manifest-path desktop/rust/Cargo.toml -j 4`.
- **Adding a new ARM mainline board or updating kernel config/patches/board quirks**:
  Work inside `devices/` starting from `devices/_template/` and `kernels/arm64-mainline/`. Never
  push hardware quirks into `desktop/` or `core/scripts/rootfs-setup.sh`.
- **Partitioning, rootfs debootstrap, bootloaders, or `make-release.sh` sanitization**:
  Work inside `core/`. Use the uniform `boot_*` backend interface rather than assuming ChromeOS `cgpt`.
- **Every user-facing change ships with three witnesses**:
  1. Executable witness (`check-core.sh` / `check-device.sh` / `check-desktop.sh` + unit tests).
  2. Documentation update in `desktop/uis/sway/files/usr/share/doc/hayato/`.
  3. Concise architectural rule in the owning repository's `AGENTS.md`.

## Umbrella Conventions
- **All versioned artifacts must be in English** (code, comments, commit messages, docs, specs).
- Keep `VERSION`, `core/VERSION`, and `desktop/VERSION` aligned when tagging releases (`vX.Y.Z`).
- Make changes and commit inside the owning submodule first (`core/`, `desktop/`, or `devices/`),
  verify standalone + umbrella checks (`./build.sh validate`), and then bump submodule gitlink pins
  in `Hayato`.
- Release CI uses a 3-stage Hybrid Matrix (`.github/workflows/release.yml`): shared `desktop` and
  `mediatek-mt81` kernel (`google-asurada`, `google-kukui`) build once, then `google-asurada`,
  `google-kukui`, `arm64-uefi`, and `arm64-extlinux` (`debian-arm64`) assemble in parallel before
  merging unified `SHA256SUMS`, generating signed APT metadata (`hayato-apt build-repo`), archiving
  all `<target>.img.xz` and `*.deb` packages on GitHub Releases, and pushing `*.deb` packages to
  the Cloudsmith APT repository (`debian/forky`) when `CLOUDSMITH_API_KEY` is configured.
- Use HTTPS URLs in `.gitmodules` for unauthenticated `git clone --recursive` and CI checkouts.
- Never force-push `main`, and never commit host build state (`REVISION`, `*.img*`, `*.nmconnection`).
