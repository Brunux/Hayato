# Hayato TUI Studio UX Architecture — Full 49-Surface Plan

Branch: `feat/studio-screens`

## Overview
Upgrade complex Hayato TUI apps from flat single-column lists and nested `Picker` loops into cohesive **Master-Detail / Studio** screens matching `games.rs`, `notes.rs`, and `theme_picker.rs`:
- Wide layout (`>= 100` cols): split master-detail / studio panes with live telemetry, inline controls, and previews.
- Compact layout (`80×24`): graceful single-column fallback with compact hero strip.
- Strict `desktop/AGENTS.md` compliance: single `Mode`/`Phase` enum, `ColorRole` only, zero per-frame allocations, zero resident daemons, full mouse + keyboard + gamepad ergonomics, and dual-grid (`80×24` & `152×45`) golden snapshot tests.

## Wave 1 — Core Daily & High-Visibility Studios (6)
- [ ] **1. Capture & Recording Studio** (`system/capture.rs`): Left grouped actions (`Snapshot`, `Record`, `Extract & Share`) + Right **Studio Deck** (live `● READY` / `● REC` timer & file-size hero, inline `^A` Audio `Off/Mic/System` & `^W` Webcam PiP pills, Recent Captures list).
- [ ] **2. Spatial Display Studio** (`system/display.rs` + `workspaces.rs`): Left live **ASCII Monitor Topology Canvas** (`eDP-1` + `DP-*` scaled boxes with coordinates) + Right inline `←`/`→` controls (Position, Mode/Hz, Scale, Workspaces, `● UNSAVED`, Apply & Save).
- [ ] **3. Master-Detail Settings Control Center** (`system/settings.rs`): Left persistent 7-section rail with live badges + Right inline settings pane.
- [ ] **4. Clipboard Inspector** (`system/clip.rs`): Left kind-filtered history list (`All | Text | Link | Image`) + Right cached full-text/code/URL/image-metadata preview + body-replacing `ConfirmWipe`.
- [ ] **5. Package Manager Studio** (`system/pkg.rs`): Unified search bar + Left results list + Right `apt-cache show` inspector expanding inline into `TaskView`.
- [ ] **6. Developer Workbench** (`system/dev.rs`): Left categorized tool rail + Right async Live Context Inspector (Cloudsmith APT, SSH/Git, MCP, boot errors, profile archives).

## Wave 2 — Productivity, Agents & Media Studios (7)
- [ ] **7. AI Agents & Accounts Studio** (`system/agents.rs`)
- [ ] **8. Unified Download Deck** (`system/download.rs`)
- [ ] **9. Reminders & Timers Studio** (`system/remind.rs`)
- [ ] **10. Places & Storage Hub** (`system/places.rs`)
- [ ] **11. Now Playing Media Deck** (`system/media.rs`)
- [ ] **12. Notification Center** (`system/notify.rs`)
- [ ] **13. Interactive Translation Studio** (`system/translate.rs`)

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
