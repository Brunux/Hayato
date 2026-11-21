# Hayato TUI Studio UX Architecture — Full 49-Surface Plan

Branch: `feat/studio-screens`

## Overview
Upgrade complex Hayato TUI apps from flat single-column lists and nested `Picker` loops into cohesive **Master-Detail / Studio** screens matching `games.rs`, `notes.rs`, and `theme_picker.rs`:
- Wide layout (`>= 100` cols): split master-detail / studio panes with live telemetry, inline controls, and previews.
- Compact layout (`80×24`): graceful single-column fallback with compact hero strip.
- Strict `desktop/AGENTS.md` compliance: single `Mode`/`Phase` enum, `ColorRole` only, zero per-frame allocations, zero resident daemons, full mouse + keyboard + gamepad ergonomics, and dual-grid (`80×24` & `152×45`) golden snapshot tests.

## Wave 1 — Core Daily & High-Visibility Studios (6)
- [x] **1. Capture & Recording Studio** (`system/capture.rs`): Left grouped actions (`Snapshot`, `Record`, `Extract & Share`) + Right **Studio Deck** (live `● READY` / `● REC` timer & file-size hero, inline `^A` Audio `Off/Mic/System` & `^W` Webcam PiP pills, Recent Captures list).
- [x] **2. Spatial Display Studio** (`system/display.rs`): Left live **ASCII Monitor Topology Canvas** (`eDP-1` + `DP-*` scaled boxes with live arrangement & `● LIVE`/`● UNSAVED` pill) + Right inline `←`/`→` controls (Position, Mode/Hz, Scale, Power toggles, Apply & Save).
- [x] **3. Master-Detail Settings Control Center** (`system/settings.rs`): Left persistent 7-section rail (compact horizontal tab bar on `< 100` cols) + Right live settings pane with instant switching.
- [x] **4. Clipboard Inspector** (`system/clip.rs`): Left kind-filtered history list (`All | Text | Links | Images`) + Right cached full-text/URL/image-metadata preview + body-replacing `ConfirmWipe`.
- [x] **5. Package Manager Studio** (`system/pkg.rs`): Unified search bar + Left results list + Right cached `apt-cache show` inspector expanding full-width into `TaskView`.
- [x] **6. Developer Workbench** (`system/dev.rs`): Left categorized tool rail + Right Workbench Inspector (command, highlights, paths & safety contract).

## Wave 2 — Productivity, Agents & Media Studios (7)
- [x] **7. AI Agents & Accounts Studio** (`system/agents.rs`): Left installed/available agent rail (`★ default`, active account) + Right Agent Deck (binary, npm package, account profiles, inline `Ctrl+D` default & `Ctrl+A` accounts).
- [x] **8. Unified Download Deck** (`system/download.rs`): Single-screen URL input (auto-filled from clipboard), inline `Tab` Video / Audio (m4a) toggle, embedded `TaskView`, and Recent Downloads list on the right.
- [x] **9. Reminders & Timers Studio** (`system/remind.rs`): Left active systemd user timers + Right Timer Details & Quick Presets deck.
- [x] **10. Places & Storage Hub** (`system/places.rs`): Left folders/disks/mounts/tools + Right Storage Inspector with live `df` capacity gauge and `Ctrl+T` terminal-here shortcut.
- [x] **11. Now Playing Media Deck** (`system/media.rs`): Left Now Playing hero & transport deck + Right Players & Controls list.
- [x] **12. Notification Center** (`system/notify.rs`): Left history + DND/Restore/Dismiss action strip + Right full-body Message Inspector + guarded `ConfirmDismiss` on `Ctrl+X`.
- [x] **13. Interactive Translation Studio** (`system/translate.rs`): Left 26-language target selector + Right Live Translator workbench (`Ctrl+T` translates clipboard live & copies).

## Wave 3 — System Config, Safety Wizards & Reference Studios (10)
- [ ] **14. Safe Disk Formatter** (`system/format.rs`)
- [ ] **15. Memory & Auxiliary Swap Studio** (`system/swap.rs`)
- [ ] **16. Screen Share (VNC) Control Panel** (`system/vnc.rs`)
- [ ] **17. Remote Login (SSH) Panel** (`system/ssh.rs`)
- [ ] **18. DNS Resolver Studio** (`system/dns.rs`)
- [ ] **19. Date, Time & Timezone Studio** (`system/tz.rs`)
- [ ] **20. Keybindings Reference Studio** (`system/keys.rs`)
- [ ] **21. Process Monitor & Killer** (`system/kill.rs`)
- [ ] **22. Gamepad Studio** (`system/pad.rs`)
- [ ] **23. Live QR Studio** (`system/qr.rs`)
