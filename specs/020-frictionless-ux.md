# Spec 020 — Intuitive, Frictionless, Self-Contained UX Overhaul

- **Status**: draft
- **Phase**: 6 (plan §16)
- **Depends on**: spec 014, spec 017, spec 019
- **Model**: `claude-opus-5-5` (high) — cross-surface UX architecture, async state machines, and visual polish; fallback `claude-sonnet-5-5` (specs/README.md §6)
- **Branch**: `spec/020-frictionless-ux`
- **Plan**: [`docs/plan-ui.md`](../docs/plan-ui.md) §16
- **Old paths**: keeps all ~64 symlinks in `~/.config/bin/` and ~55 keybindings working while upgrading the interactive behavior of `menu net`, `menu bluetooth`, `menu audio`, `menu display`, `menu settings`, `menu pkg`, `menu clean`, `menu format`, `menu swap`, `menu dev`, `menu dns`, `menu download`, `menu file-actions`, `menu calc`, `menu emoji`, `menu clip`, `menu qr`, `menu about`, `menu learn`, `menu remind`, `menu window`, `menu apps`, `menu kill`, `bar-power`, `bar-updates`, `lazyos-camera`, and `lazyos-profile`.

## Problem

While specs 001–019 migrated all 45+ surfaces to the native Rust TUI framework (`lazyos`) and retired `rofi`, many surfaces inherited the legacy one-shot `rofi -dmenu` lifecycle ("Close-Then-Block-Then-Toast"):
1. **Manual discovery friction**: Opening `lazyos menu net` (`bar-net`) runs `nmcli ... --rescan no`, displaying only stale cached networks; clicking "Rescan networks" closes the window, blocks for 5 seconds, fires a toast, and exits without showing the results. Turning Wi-Fi on also exits immediately instead of scanning and listing networks.
2. **External toasts instead of in-window progress**: 17 `Picker`-based surfaces close their window as soon as an option is selected, block on slow commands (`nmcli`, `parted`, `mkfs`, `swapon`, `rm -rf`, `udisksctl`), and fire external `say()` (`notify-send`) toasts. Even custom `Screen` implementations (`bluetooth.rs`, `pkg.rs`, `audio.rs`, `notify.rs`, `clip.rs`, `about.rs`, `window.rs`) block the UI thread synchronously (preventing `PkgStage::Installing` from ever rendering!) and fire redundant `busy` + `say` toasts on top of the active TUI window.
3. **Inconsistent filtering, layout spacing, and bugs**:
   - 9 custom `Screen`s (`emoji.rs`, `clip.rs`, `audio.rs`, `bluetooth.rs`, `about.rs`, `colour.rs`, `media.rs`, `notify.rs`, `remind.rs`) never call `self.list.type_filter(key)`, breaking search in `menu emoji` (1,300 rows) and `menu clip`.
   - `learn.rs` has an off-by-2 index bug where selecting the first two manual pages triggers `search_manuals()` / `run_apropos()` instead of opening the pages.
   - `apps.rs` omits row glyphs (`glyph: None`), hardcodes `/home/brunux`, and overwrites `frecency.json` with an incompatible schema.
   - `dns.rs` ("Type the servers") calls nonexistent `lazyos menu --ask`; `download.rs` and `file_actions.rs` pass invalid `--app`/`--title`/`--glyph` flags to `lazyos notify send`.
   - `lazyos-camera` calls deleted `ui_say` from `lib-rofi.sh`; `lazyos-profile` calls deleted `bar-pick` during restore; `settings.rs` calls `makoctl` instead of `lazyos-notify`'s DND state; `bar-power` spawns legacy `swaynag`.

## Scope

**In:**

- **Phase 1 — `lazyos-ui` Widgets, Dynamic Window Resize & Core Primitives**:
  - `Screen::desired_size(&self) -> Option<(u16, u16)>` & `request_window_size(width_px, height_px)`: dynamically resize and re-center the live floating `foot` window in Sway (`swaymsg [pid=<ppid>] floating enable, resize set width <W> px height <H> px, move position center` with `XTWINOPS` `\x1b[4;<H>;<W>t` fallback) whenever a screen transitions between compact and expanded views (e.g., showing a Wi-Fi QR code, opening a wide log/manual detail pane, or transitioning a compact wizard into `TaskView`).
  - `ActionStrip`, `ActionItem`, and `ActionStripEvent`: dedicated zero-allocation horizontal pill bar for tool-level actions (`Tab` focuses, `Left`/`Right` moves, `Enter`/`Space` activates, `Ctrl+<Key>` shortcuts, mouse click support) so `ListState` holds strictly domain results.
  - `ActionRunner<T>` & `ActionNotice`: single-polled background task runner (`poll(&mut self) -> Option<T>`) with transient vs. persistent status lifecycle (`clear_status()` on routine scan completion, 3-second `set_transient()` for positive state transitions, and `set_persistent_error()` / `set_persistent_info()` for high-signal outcomes).
  - `ListState::update_rows(&mut self, rows: Vec<Row>)`: preserve selected row identity (`.value`/`.label`), active filter query, and scroll offset when background scans refresh a list.
  - Unified density-aware `list_layout(area: Rect, design: &Design) -> (Rect, Rect)` derived from `draw_card`'s inner `Rect`.
  - Zero-allocation visual craft primitives in `lazyos-ui::widgets`:
    - `draw_scrollbar`: 1-column scrollbar (`│` track, `█` thumb) rendered automatically on `ListState` and `LogPane` when `total > capacity`.
    - `draw_filter_bar`: unified search bar with `Glyph::Search`, active cursor block `█`, and stack-formatted match counter (`14/52`).
    - `QrCode` & `draw_qr`: in-window Unicode half-block (`▀`, `▄`, `█`, ` `) QR code renderer (2 vertical modules per cell row) for `menu qr` and `menu net`.
    - Fix steady-state heap allocation in `TaskView::draw` by replacing `format!("{} running", ...)` with a static `RUNNING_BADGES` table.
  - In-window `ActionRunner<T>` (non-blocking background thread + 100ms braille spinner + in-window status/error banner) and in-process `TaskView` step/command execution without emitting external `busy` toasts when a TUI window is visible.
  - Route `missing(NEEDED)` pre-flight checks to in-window `FailureScreen` (`Err(Failure)`) instead of external `say()` toasts.
- **Phase 2 — Live Auto-Discovery, Hero Cards & Persistent Control Surfaces**:
  - `system/net.rs` (`NetScreen`): show cached APs immediately with a top connected-network hero card and 4-bar signal meters (`▂▄▆█`) while auto-triggering a background `nmcli device wifi rescan` (`⠋ Scanning…` badge in header) that updates `ListState` in-place. Keep window open on radio toggle, rescan, password prompt, connection, and inline Wi-Fi QR view (`NetMode::WifiQr`, dynamically resizing the window to fit the QR card and shrinking back on `Esc`).
  - `system/bluetooth.rs` (`BluetoothScreen`): top controller status strip (`[POWERED ON]`/`[POWERED OFF]` badge + active scan spinner); auto-trigger scan after power-on; move power/connect/pair/disconnect to background threads polled by `tick()` with in-window status; remove all external `busy`/`say` calls.
  - `system/audio.rs` (`AudioScreen`): top hero card displaying live `draw_gauge` volume bars (`▕██████░░░░▕  65%`) and `[DEFAULT]` / `[MUTED]` badges for active Output and Input; support `Left`/`Right` (`-`/`+`) for live volume adjustment and `m` for mute in-place; remove external `say()` toasts.
  - `system/display.rs` (`DisplayScreen`): keep window open when applying arrangement, resolution, or scale so users can preview and tune multiple display settings in one session; remove selectable dummy `"-" ` separator rows.
  - `system/settings.rs` (`SettingsScreen`): keep Settings open when toggling switches (`wifi-radio`, `bt-radio`, `night`, `dnd`, `touchpad`, `automount`, `tablet`, `rotation`), updating row status in-place; replace `makoctl` DND calls with `$XDG_RUNTIME_DIR/lazyos/notify/dnd`; add missing `"theme"` row.
  - `system/clean.rs` (`CleanScreen`): top reclaimable-space gauge card + per-category proportion bars calculated asynchronously on open with spinners; clean selected categories in-window and update freed bytes in-place without closing.
- **Phase 3 — Self-Contained `TaskView` & Domain-Tailored Visual Surfaces**:
  - `system/pkg.rs` & `menu updates`: run `apt-get install`, `purge`, `update`, and `full-upgrade` asynchronously inside `PkgScreen` / `TaskView` (dynamically resizing from query to results/task geometry) so live log lines and progress render at 10 fps without freezing the UI or firing external toasts.
  - `system/format.rs` & `system/swap.rs`: open TUI window with informative empty state + `r` Rescan when no removable disk is present; run `parted`, `mkfs`, `mkswap`, `swapon`/`swapoff` inside in-window `TaskView` ending on the persistent result banner.
  - `system/download.rs` & `system/file_actions.rs`: run `yt-dlp`, `tar`, `unzip`, `ffmpeg`, and `udisksctl` with in-window progress/status; fix invalid `lazyos notify send` flags.
  - `system/dev.rs` & `bin/lazyos-profile`: confirm restore in-TUI (`Question::ask`), pass `--yes` to `lazyos-profile`, and run backup/restore/report inside in-window `TaskView`.
  - Domain-tailored visual upgrades:
    - `system/qr.rs`: in-window half-block `draw_qr` rendering with dynamic window resize (`(680, 340)` menu $\leftrightarrow$ `(740, 660)` QR view) and `c` to copy payload.
    - `system/colour.rs`: dual-pane layout with left truecolor swatch block (`██`), RGB channel bars, and WCAG contrast ratios alongside right format list.
    - `system/calc.rs`: top expression & live result hero card (with hex/binary integer preview) + bottom scrollable session history card.
    - `system/about.rs`: top 2-column hardware/OS dashboard card (with memory & disk gauges) + interactive diagnostic actions that expand in-window into `AboutMode::Detail` (`1080x720` `LogPane`).
    - `system/media.rs`: top Now-Playing hero card with playback state badge (`[▶ PLAYING]` / `[⏸ PAUSED]`) and transport controls.
    - `system/kill.rs`, `system/dns.rs`, `system/ssh.rs`, `system/tz.rs`, `system/vnc.rs`, `system/places.rs`: live process refresh in `kill.rs`; in-window custom DNS input in `dns.rs`; persistent in-window toggles in `ssh.rs` and `vnc.rs`.
- **Phase 4 — Universal Search, Icon Consistency & Bug Fixes**:
  - Wire `self.list.type_filter(key)` into `emoji.rs`, `clip.rs`, `audio.rs`, `bluetooth.rs`, `about.rs`, `colour.rs`, `media.rs`, `notify.rs`, and `remind.rs`.
  - Fix `learn.rs` off-by-2 row index bug.
  - Fix `apps.rs` missing row glyphs, hardcoded `/home/brunux` path, and `frecency.json` schema mismatch.
  - Fix `window.rs` to reload window list in-place on `Alt+1` close; implement `remind.rs` in-window new reminder prompt; remove redundant launch/copy toasts (`apps.rs`, `run.rs`, `window.rs`, `notify.rs`, `clip.rs`).
- **Phase 5 — Session Scripts & Waybar Entry Points**:
  - Fix `lazyos-camera` (`notify-send` replacing deleted `ui_say`/`$UI_ICON_*`).
  - Replace `bar-power`'s `swaynag` banner (and `$mod+Shift+e` in `sway/config`) with native `lazyos` TUI power/battery status screen; bind Waybar `battery` right-click to `rofi-power` (`lazyos menu power`).
  - Swap Waybar `pulseaudio` clicks so Left-Click opens `bar-audio` (`lazyos menu audio`) and Right-Click toggles mute, matching every other Waybar module.
  - Add right-click on `custom/keyboard-layout` to open `rofi-layout`, left-click on `backlight` to open `rofi-display`, and left-click on `custom/updates` to open `lazyos menu pkg` / `TaskView`.

**Out:**

- `lazyos-greeter` (spec 013) and `theme from-wallpaper` (future spec).

## Design

1. **When to use In-Window UI vs External Notifications (`lazyos-notify`)**:
   - **Rule**: If a TUI window is open on screen, 100% of progress, status, warnings, and results belong **inside that TUI window** (header spinner, status strip, `Card::render`, or `TaskView`). Calling `Card::send()` / `say()` / `notify-send` from an active TUI screen is forbidden.
   - **Exceptions (External Toast Allowed)**:
     1. Hardware key OSD (`bin/osd` for volume, mic, brightness).
     2. Screen capture (`bin/screenshot`, `system/capture.rs`, `system/colour.rs` pixel picker) where the floating `foot` window must unmap before `grim`/`slurp`/`wf-recorder` captures the screen.
     3. Direct headless keybindings (`system/dictate.rs` `Alt+Ctrl+X`, `system/translate.rs` `Alt+Ctrl+T`) that act on the currently focused window without stealing Wayland focus.
     4. `Card::secret` when copying a generated secret as the window closes, and background timer firing (`remind`).
2. **Non-Blocking Discovery & `ListState::update_rows`**:
   - Every discovery menu (`net`, `bluetooth`, `clean`, `kill`, `places`) renders immediately with initial/cached state and spawns a background worker thread.
   - `Screen::needs_tick()` returns `Some(Duration::from_millis(100))` while any worker is active.
   - When new rows arrive, `ListState::update_rows(new_rows)` preserves the highlighted item's `.value`, re-runs the active case-folded filter, and keeps the viewport offset stable.
3. **Dynamic Post-Map Window Resizing (`Screen::desired_size` & `request_window_size`)**:
   - While initial window creation uses `--window-size-pixels` on `foot` to avoid map-time races, once `App::run_until` has drawn its first frame and `foot` is mapped in Sway, `Screen::desired_size(&self) -> Option<(u16, u16)>` allows any screen to dynamically resize and re-center its floating container on mode transitions via `swaymsg [pid=<ppid>] floating enable, resize set width <W> px height <H> px, move position center` (with `XTWINOPS` `\x1b[4;<H>;<W>t` fallback).
   - Used for showing Wi-Fi/text QR codes in-window (`menu net`, `menu qr`), expanding `menu about` / `menu learn` into wide log/manual views (`1080x720`), expanding compact wizards (`pkg`, `format`, `swap`, `dev`, `download`) into `TaskView` (`940x620`), and sizing compact tools (`calc`, `audio`, `clean`, `colour`) to fit their content.
4. **Zero-Allocation Ratatui Visual Craft**:
   - `draw_scrollbar` (1-col `│` / `█` scrollbar when `total > capacity`), `draw_filter_bar` (`Glyph::Search` + `█` cursor + stack-formatted match counter), `draw_qr` (Unicode half-block `▀`/`▄`/`█` QR matrix), and domain hero cards (`audio` volume gauges, `net` 4-bar signal meters & connected hero card, `clean` storage proportion bars, `colour` dual-pane truecolor swatch & WCAG card, `calc` live result hero card, `about` 2-column hardware/OS dashboard, `media` now-playing hero card) all render directly into `ratatui::buffer::Buffer` with 0 steady-state heap allocations per frame.

## Acceptance criteria

- [ ] behaviour: opening `lazyos menu net` (`bar-net`) immediately shows cached networks while running a background Wi-Fi rescan (`Scanning…` spinner in header) and updates the list in-place without resetting the cursor; selecting "Rescan networks" or toggling Wi-Fi radio stays inside the window; connecting to a network shows live in-window status and errors without firing external toasts.
- [ ] behaviour: `lazyos menu bluetooth`, `lazyos menu audio`, `lazyos menu display`, `lazyos menu settings`, and `lazyos menu clean` perform all toggles and actions in-window, updating row state in-place without closing the window or firing external `say()` / `busy` notifications.
- [ ] behaviour: `lazyos menu pkg`, `lazyos menu format`, `lazyos menu swap`, `lazyos menu dev` (profile export/import/report), and `lazyos menu download` execute their multi-step/streaming operations inside an in-window `TaskView` and display the final result in-window.
- [ ] behaviour: typing characters in `lazyos menu emoji`, `lazyos menu clip`, `lazyos menu audio`, `lazyos menu bluetooth`, `lazyos menu about`, `lazyos menu notify`, and `lazyos menu remind` filters the list in real time via `ListState::type_filter`.
- [ ] behaviour: `lazyos menu learn` opens the exact manual page selected (indices 0 and 1 fixed); `lazyos menu apps` draws Nerd Font glyphs on every row and shares `menu::frecency::Frecency` without corrupting `frecency.json`; `lazyos menu dns` custom server input prompts in-window; `lazyos-camera` and `lazyos-profile` run without retired `lib-rofi.sh` / `bar-pick` errors.
- [ ] failure: when a required tool is missing or an operation fails, the surface renders an in-window error banner or `FailureScreen` (`Card::render`) instead of exiting silently or relying on an external toast.
- [ ] compatibility: all symlinks in `~/.config/bin/` (`bar-net`, `bar-bt`, `bar-audio`, `bar-power`, `rofi-*`) and headless query flags (`menu net --status`, `menu clean --dry-run`, `menu places --rows`, `menu translate --languages`) remain 100% compatible.
- [ ] witness: `scripts/check-system.sh` verifies that no `ui_say` / `bar-pick` / `makoctl` references remain in session scripts or `system/*.rs`, that `foot.ini` has `selection-target=both`, and that all menu commands pass behavioral checks.
- [ ] witness: `uis/sway/files/usr/share/doc/lazyos/04-software.md` and `02-rofi.md` document the self-contained in-window TUI behavior and `foot` auto-copy.
- [ ] witness: `AGENTS.md` documents the three-part frictionless UX rule (anticipate primary intent on open, in-window progress over external toasts, consistent foundation with domain-tailored layouts).
- [ ] unit tests: `cargo test --workspace` covers `ListState::update_rows` cursor preservation, `learn` row indexing, `apps` frecency round-trip, `net` state transitions, and snapshot tests for updated screens.

## Tests

- **Unit** (`cargo test`):
  - `lazyos-ui`: `ListState::update_rows` preserves cursor by `.value` and re-applies active filter; `list_layout` respects `Density::Normal` and `Density::Tablet`.
  - `lazyos-cli`: `apps::frecency` compatibility with `menu::frecency::Frecency`; `learn` page list indexing; `calc` live expression evaluation; `settings` DND file toggle.
- **Snapshot** (`TestBackend` at 80x24 and 152x45):
  - `NetScreen` (scanning state, connected state, inline error banner), `AudioScreen` (with volume gauges), `CleanScreen`, `CalcScreen`.
- **Integration**:
  - Verify zero `makoctl`, `ui_say`, or `bar-pick` invocations across `rust/` and `uis/sway/files/home/.config/bin/`.
- **Hardware**:
  - On the Hayato Chromebook: click Wi-Fi, Bluetooth, Audio, Battery, and Settings in Waybar; verify immediate scan/feedback in-window, zero redundant toast popups while TUI is open, and smooth live updates. Record in `reports/`.

## Risks

- **Background threads outliving a closed TUI window**: every background thread spawned by a `Screen` (`nmcli`, `bluetoothctl`, `apt-get`, `yt-dlp`) must be tied to a channel or child PID that is dropped/terminated cleanly when the user presses `Esc` or closes the window.
