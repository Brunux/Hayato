# Spec 021 — Native `lazyos-greeter` over `greetd` IPC

- **Status**: in progress
- **Phase**: 7 (plan §12 A)
- **Depends on**: spec 001, spec 002, spec 004, spec 013
- **Model**: `claude-opus-5-5` (high) — `greetd` IPC protocol, VT7 compositor/foot session orchestration, PAM authentication state machine, and TUI craft; fallback `claude-sonnet-5-5` (specs/README.md §6)
- **Branch**: `spec/021-greeter`
- **Plan**: [`docs/plan-ui.md`](../docs/plan-ui.md) §12 A
- **Old paths**: replaces `tuigreet` 0.9.1 in `/etc/greetd/config.toml` and `uis/sway/packages.list` with `/usr/bin/lazyos-greeter` (symlink to `/usr/bin/lazyos`), while preserving `/var/lib/lazyos/greeter` state and `~/.config/lazyos/greeter` theme surfaces.

## Problem

The boot login screen still runs `tuigreet` 0.9.1: a static black-and-white/ANSI box on VT7 with no `theme.toml` palette, no theme wallpaper, no live theme switching, no mouse support, and no entry animation (`docs/plan-ui.md` §12 A). Because Debian packages vanilla `tuigreet` 0.9.1 without TOML configuration or custom themes, the first screen a user sees is visually disconnected from the rest of the LazyOS desktop framework.

## Scope

**In:**

- Native `greeter` command inside `lazyos-cli` (`lazyos greeter`, `Shape::Full`, symlink `/usr/bin/lazyos-greeter -> lazyos`).
- Pure-Rust `greetd` IPC client (`src/greeter/ipc.rs`) implementing 4-byte native-endian length-prefixed JSON framing over `GREETD_SOCK` (`create_session`, `post_auth_message_response`, `start_session`, `cancel_session`, and `AuthMessage` / `Error` / `Success` responses) plus a dry-run `PreviewBackend` for `--preview` and tests.
- Interactive `GreeterScreen` implementing `lazyos_ui::Screen` (`src/greeter/screen.rs`):
  - Live tabular clock & date hero card with host/OS mark (`lazyOS_`), greeting banner, and active theme pill.
  - Real login user discovery from `/etc/passwd` (`UID >= 1000` with real login shell) + `[+ Other]` custom username input + remembered `last_user`.
  - Masked `Input` for PAM `Secret` prompts, visible input/notices for `Visible` / `Info` / `Error` PAM messages, inline spinner during async authentication, Caps Lock badge when reported, and automatic `CancelSession` recovery on failed login.
  - Wayland & X11 session discovery from `/usr/share/wayland-sessions/*.desktop` and `/usr/share/xsessions/*.desktop` (`DesktopNames` exported as `XDG_CURRENT_DESKTOP` / `XDG_SESSION_TYPE`), session cycle & modal selector, and remembered `last_session`.
  - Live theme switcher (`F4` / `^T` / ActionStrip) across all 16 built-in themes via `Screen::design()` and PTY OSC palette updates.
  - Bottom `ActionStrip` for `Session`, `Theme`, `Sleep`, `Reboot`, and `Shut down` with mandatory inline Cancel-first confirmation before any power action.
- VT7 compositor session launcher (`lazyos-greeter --session`): generates theme-matched `foot.ini`, `sway.conf`, and wallpaper PNG under `${XDG_RUNTIME_DIR:-/tmp}/lazyos-greeter/` (`--prepare-session` prints paths cleanly for validation) and launches minimal `sway` + `swaybg` wallpaper + fullscreen `foot` running `lazyos-greeter --ui`, falling back cleanly to running `GreeterScreen` directly on VT7 TTY if `sway` or `foot` cannot start.
- Syncs theme automatically with remembered user's `~/.local/state/lazyos/theme/active` (when `follow_user_theme = true`, the default) or enforces the configured `/etc/lazyos/greeter.toml` default theme (`follow_user_theme = false`), defaulting to `solarized`.
- Native **Greeter Settings** surface (`src/greeter/settings.rs`, opened via `lazyos menu greeter`, `lazyos greeter settings`, **Settings → Login screen (Greeter)**, Root Menu **Greeter settings**, or **Ctrl+G** / **F9** inside `lazyos greeter --preview`) editing `/etc/lazyos/greeter.toml` (`follow_user_theme`, `theme`, `show_user_pills`, `remember_user`, `default_session`, `remember_session`, `clock_24h`, `show_power_actions`, `greeting`) with Cancel-first Reset and live preview handoff.
- Retire `tuigreet` from `uis/sway/packages.list` and update `scripts/rootfs-setup.sh` to configure `/etc/greetd/config.toml` and `/var/lib/lazyos/greeter`.

**Out:**

- First-boot onboarding carousel (`lazyos act welcome`), custom `swaylock` replacement, and fingerprint (`fprintd`) hardware enrollment (future specs).

## Design

1. **Multi-call integration without binary bloat**: Keeping `greeter` inside `lazyos-cli` with `/usr/bin/lazyos-greeter -> lazyos` reuses `lazyos-ui`, `lazyos-theme`, `serde_json`, and terminal hygiene (`Drop`, panic hook, signal restore) without duplicating Ratatui across a second 8 MB ELF binary, and passes `lazyos-cli/tests/frame.rs` by implementing `lazyos_ui::Screen` cleanly inside `App`.
2. **Protocol & zero new crate dependencies**: Implementing the small `greetd` IPC protocol directly with `serde_json` + `UnixStream` avoids adding external workspace dependencies and enables deterministic `UnixStream::pair()` integration tests offline.
3. **Preview & live safety**: When invoked with `--ui` under `greetd`, `Esc` clears modals/confirmations/password without closing the greeter window. When invoked from a desktop session (`--preview` or no `GREETD_SOCK`), `GreeterScreen` opens in `PreviewBackend` dry-run mode where `Esc` exits cleanly and authentication simulates session launch without modifying system state or rebooting.
4. **Resilience**: If `sway -c <greeter.conf>` fails (e.g. headless VM, broken DRM, or missing `foot`), `--session` immediately drops into inline Ratatui TUI on VT7 so login never strands the user.

## Acceptance criteria

- [x] behaviour: `lazyos greeter --preview` opens `GreeterScreen` with live clock, user pills, session selector, theme cycling (`^T` / `F4`), masked password box, and Cancel-first confirmation on Sleep/Reboot/Shut down; `lazyos-greeter --session` prepares `foot.ini` (`foot --check-config` clean) + `sway.conf` + wallpaper PNG for the active theme.
- [x] failure: wrong password returns a structured PAM error banner via `CancelSession` recovery and clears only the secret field; missing `GREETD_SOCK` in `--ui` displays an actionable `FailureScreen`; missing `sway`/`foot` falls back to inline TTY TUI.
- [x] compatibility: `/usr/bin/lazyos-greeter` symlink resolves to `/usr/bin/lazyos`, `/etc/greetd/config.toml` uses VT 7 and `_greetd` with `pam_env` locale preservation, and `~/.config/lazyos/greeter` remains generated by `lazyos theme set`.
- [ ] hardware: deploy to rootfs on Hayato (`/usr/bin/lazyos`, `/etc/greetd/config.toml`) and verify VT7 boot/logout login flow and hardware report under `reports/`.
- [x] witness: `scripts/check-system.sh` verifies `lazyos-greeter` presence (`have lazyos-greeter`), `--check` output, `greeter` command registration, and `greetd` configuration.
- [x] witness: `uis/sway/files/usr/share/doc/lazyos/04-software.md` and `01-welcome.md` document how `lazyos-greeter` works, how to preview it safely (`lazyos greeter --preview`), and how to switch themes or revert/recover on VT7.
- [x] witness: `AGENTS.md` records why `lazyos-greeter` runs as a `lazyos` multi-call symlink inside minimal `sway` + fullscreen `foot` with TTY fallback and `UnixStream` `greetd` IPC.
- [x] unit tests: covered by `cargo test` in `lazyos-cli` (`greeter::ipc::tests::*`, `greeter::tests::*`, `greeter::screen::tests::*`, `tests/frame.rs`, and `tests/greeter.rs`).

## Tests

- **Unit & Render** (`cargo test`): `/etc/passwd` user discovery filter, `.desktop` Wayland/X11 session parser (preserving `DesktopNames` and `TryExec`), remembered state round-trip, theme priority resolution, clock formatting, `GreeterScreen` keyboard/Cancel-first power guard transitions, and `TestBackend` render checks at `80x24` and `152x45` (`greeter::screen::tests::renders_cleanly_at_80x24_and_152x45`).
- **Integration**: Full `UnixStream::pair()` `greetd` IPC server/client round-trips (`Success`, `AuthError` + `CancelSession`, multi-step `Info` + `Visible` + `Secret` PAM flow, oversized frame guard) plus `lazyos-greeter --prepare-session` output and `foot --check-config` validation.
- **Hardware**: Deploy `/usr/bin/lazyos` via `scripts/install-lazyos.sh /`, update `/etc/greetd/config.toml` to `/usr/bin/lazyos-greeter --session`, test reboot/logout into VT7 on Hayato, verify active user theme, mouse/touch/keyboard login into Sway, and record report in `reports/`.

## Risks

- Running `sway` as `_greetd` could fail if `sway` tries to source `/etc/sway/config` or lacks seat permissions; mitigated by launching with explicit minimal `-c <runtime>/sway.conf` plus automatic in-process fallback to raw VT7 Ratatui TUI on any non-zero pre-auth exit.
