# Spec 026 — The Hayato rebrand

- **Status**: in progress (code, brand, theme and wallpapers on `brand/hayato`; image build and GitHub renames pending)
- **Phase**: 9
- **Depends on**: spec 004 (theme engine), spec 021 (greeter), spec 024 (release matrix)
- **Branch**: `brand/hayato`
- **Supersedes**: the naming rules in `docs/plan-rebrand.md` (Nureb → LazyOS), for the second rename

## Problem

The distribution is called LazyOS everywhere: the binary, the eight Rust crates, the config and
data directories, the systemd units, the launcher entries, the icon theme, the MCP server, the
images and the four repositories. The brand is a lowercase `z` and a cursor with the tagline "lazy
by design", drawn in Solarized, and the session boots Solarized.

The project is now **Hayato**: a golden eagle, a Tokyo Night session, and the promise **light.
fast. fun.** Carrying two names through the code and the docs costs every reader a translation, so
this is one rename in one release, 0.6.0.

## Scope

**In:**

- **Identity.** `LazyOS` → `Hayato` in prose, `lazyos` → `hayato` in identifiers, `LAZYOS_*` →
  `HAYATO_*` in the environment. The multicall binary, its `argv[0]` symlinks, the eight crates,
  `/etc/hayato`, `~/.config/hayato`, `/usr/share/hayato`, `/usr/libexec/hayato`,
  `/usr/share/doc/hayato`, `org.hayato.*` launcher entries, the `Hayato` icon theme, the MCP
  server name and its `hayato://manual/*.md` resources, `ID=hayato` in `os-release`, and the
  default hostname.
- **Brand.** `brand/mark-48.txt` is the mark: a golden eagle on a 48×48 grid. `hayato.svg`,
  `hayato-24.svg`, `hayato-16.svg`, `wallpaper.svg` and `social-preview.svg` are generated from it,
  and the fastfetch wordmark and the screensaver art are sampled from the same grid, so no surface
  can drift. The wordmark is `Hayato_` with an orange cursor; the tagline is **light. fast. fun.**
- **The name is philosophy, not decoration.** No kanji or kana anywhere in the product. The meaning
  of *hayato* is stated once, in prose, in `brand/README.md` and in `01-welcome.md`.
- **Theme.** Tokyo Night becomes the default: first in the cycle, the fallback palette, and the
  theme every committed surface is rendered from. Solarized stays as one of the sixteen.
- **Wallpapers.** Exactly three per built-in theme (48 files), all reviewed: no wordmark, logo,
  trademark or third-party character art. `scripts/fetch-wallpapers.py` is the manifest and
  `brand/wallpapers.md` records every source and every rejection.
- **Version.** `VERSION`, `core/VERSION`, `desktop/VERSION` → `0.6.0`.

**Out:**

- History: `reports/`, `docs/releases/v0.x`, `specs/001`–`025`, `docs/plan*.md` and
  `docs/design/` keep the old name. They are the record of what happened, not a claim about today.
- Device codenames: the Google Hayato Chromebook stays `google-asurada`, and the hardware keeps its
  own name in `devices/`. The brand never appears as a device.
- Release images: this spec changes the code and the assets; `./build.sh release` runs later.
- GitHub repository renames: `Brunux/LazyOS` → `Brunux/Hayato` and the three sub-repositories are
  the maintainer's step, after the pins land. `.gitmodules` carries the new URLs so the switch is
  one edit away.

## Design

1. **One rename, one pass, one allowlist.** The rename is mechanical (`lazyos`/`LazyOS`/`LAZYOS` →
   `hayato`/`Hayato`/`HAYATO`, longest token first) over tracked text files, with the history
   directories excluded by path. The excluded set is the allowlist the guard checks against.
2. **One drawing, every size.** The mark is a grid, not a vector: 48 px is 1×1, 24 px is 2×2, 16 px
   is 3×3, and the terminal art is the 24 px form in half blocks. No surface resamples another.
3. **The palette is the theme's.** The mark is fixed to Tokyo Night (a logo does not change with the
   wallpaper); the wallpaper follows the theme, which the engine already does per theme.
4. **Wallpapers are a manifest.** The fetcher holds `theme → three sources`, converts to JPG at
   2560 px wide, and refuses a theme that does not declare exactly three. Rejections are recorded
   with their reason so a later fetch cannot quietly re-add them.

## Acceptance criteria

1. `git grep -i lazyos` returns only the history allowlist (`reports/`, `docs/releases/`,
   `docs/design/`, `docs/plan*.md`, `specs/001`–`025`).
2. `hayato --version` prints `0.6.0`; `ID=hayato` and `PRETTY_NAME="Hayato 0.6.0"` in `os-release`.
3. `scripts/make-brand.sh` regenerates every brand file from `mark-48.txt`, and the 16 px icon is
   legible.
4. A fresh session starts in Tokyo Night, `Alt+Shift+T` cycles sixteen themes and returns to Tokyo
   Night, and every committed surface's header says `Hayato theme: Tokyo Night (tokyo-night)`.
5. Every built-in theme lists exactly three wallpapers, all present, none carrying a brand word
   (`cargo test -p hayato-theme --test wallpapers`).
6. `check-desktop.sh`, `check-core.sh`, `check-device.sh` and `./build.sh validate` pass.

## The three witnesses

1. **Executable**: `cargo test --workspace --all-targets`, `tests/wallpapers.rs` (three per theme,
   files present, no brand word), and the three `check-*.sh` runs.
2. **Documentation**: `desktop/uis/sway/files/usr/share/doc/hayato/01-welcome.md` (the mark, the
   idle screen, the name), `brand/README.md` (the rules), `brand/wallpapers.md` (provenance).
3. **Architecture**: a rule in `desktop/AGENTS.md` (the grid is the source of truth; the mark is
   never recoloured per theme) and this spec in the umbrella.
