# Hayato Connect — Architecture & UI/UX Specification

> **Status:** Draft Specification (Pre-Implementation Design Gate)  
> **Scope:** Extends **Hayato Drop / Share** (`hayato-cli/src/system/share/`) into an **opt-in, zero-daemon, zero-bloat personal device workspace** (`hayato connect` / `hayato share`).

---

## 1. Design Principles & Hard Constraints

1. **Zero Resident Daemons ("Live and Die While Needed"):**  
   No background `systemd` service runs when the user closes **Hayato Connect**. Every listener (HTTPS/WSS server, UDP discovery socket, WebRTC/webcam pipe, clipboard bridge, folder sync) starts when `ConnectScreen` (or `ShareScreen`) opens and terminates cleanly on window close (`Drop`).
2. **Zero UI/Framework Bloat (No Qt, No C++ Companion Daemons):**  
   Runs strictly inside Hayato's existing Ratatui + SwayFX ecosystem using dependencies already present in `desktop/rust/Cargo.lock` (`openssl`, `tokio`, `tokio-native-tls`, `tokio-tungstenite`, `zbus`, `serde_json`, `image`), plus zero-install Web standards on the phone (`HTTPS` + `WSS` + `WebRTC` + Web File System / Clipboard APIs).
3. **Why Not Mandatory KDE Connect Daemons / Qt Libraries?**  
   - Traditional KDE Connect pulls Qt / KDE Frameworks (`kf6-*`, `kdeconnectd` resident daemon).  
   - **Browser-first Encrypted Web App (`HTTPS` + `WSS` + `WebRTC`)** works immediately on **both Android and iOS** by scanning a QR code—no app install required.  
   - **Optional Native KDE Connect v7/v8 Protocol Bridge (Future P2 Adapter, Zero Qt):** Because KDE Connect's wire protocol is simply JSON-lines over UDP port `1716` + TLS-wrapped TCP sockets, Rust (`openssl` + `tokio`) can optionally speak the same wire packets *strictly on demand while Connect is open*—if the user ever wants background Android OS notification forwarding without pulling a single Qt/C++ library. By default, P0/P1 use only the encrypted LAN Phone Web App + existing LocalSend v2 (`224.0.0.167:53317`) compatibility.
4. **No Mandatory Cloud Account:** All discovery, signaling, pairing, encryption, and transfer stay strictly on the local Wi-Fi / LAN subnet.
5. **1-Tap `hayato share` Preserved:** Passing a payload (`hayato share <file|url|text>`) still opens the instantaneous single-action **Hayato Share** sheet (`ShareScreen`), adding `[p] Open in Connect` to promote the active session into the full Connect hub without re-scanning. Opening `hayato connect` (or choosing **Connect** from the menu) launches the multi-section Connect workspace directly.

---

## 2. Transport, Cryptography, Pairing & Device Trust Protocol

### 2.1 Transport Architecture (Zero Extra C++/Qt Dependencies)
```text
┌─────────────────────────────────────────┐       HTTPS / WSS (TLS 1.3) + PIN/SAS       ┌──────────────────────────┐
│  Hayato Desktop (active TUI session)    │ ◀═════════════════════════════════════════▶ │  Phone Mobile Web App    │
│                                         │     Files, Clipboard, Links, Media, Alerts  │  (Chrome / Safari PWA)   │
│  · openssl + tokio-native-tls (HTTPS)   │                                             │                          │
│  · tokio-tungstenite (WSS control bus)  │       WebRTC (ICE/DTLS/SRTP video/audio)    │  · getUserMedia (cam/mic)│
│  · LocalSend v2 UDP 224.0.0.167:53317   │ ◀═════════════════════════════════════════▶ │  · Web Notification API  │
│  · zbus (MPRIS2 & desktop notify hook)  │                                             │  · File / Dir Picker API │
│  · PipeWire / v4l2 sink (while open)    │                                             │                          │
└─────────────────────────────────────────┘                                             └──────────────────────────┘
```

- **Local Identity:** Persistent ECDSA P-256 desktop keypair & self-signed X.509 certificate generated once on first Connect open in `~/.local/share/hayato/connect/identity.{key,pem}` (`0600`). Ephemeral session tokens are minted per launch using CSPRNG (`/dev/urandom`, 128-bit).
- **Zero-HTTP Downgrade Policy:** Connect binds a single **TLS** port per session (replacing plain HTTP for Connect sessions) so clipboard, files, links, and media commands are encrypted in transit across shared/public Wi-Fi.

### 2.2 QR Pairing & Explicit Device Authorization Gate
1. **QR Code Payload:** Encodes the LAN URL, ephemeral pairing token, and desktop certificate SHA-256 SPKI fingerprint:
   `https://<lan-ip>:<port>/?pair=<128-bit-token>&fp=<spki-sha256-b64url>`
2. **Short Authentication String (SAS) & Explicit Approval:**
   - When the phone browser loads the Web App and opens the WSS handshake, both the phone UI and the desktop TUI derive the same **6-digit SAS code** (`HKDF-SHA256(spki_fp || session_nonce || peer_pub)`).
   - The desktop TUI **replaces its entire body** with `ConnectPhase::AuthorizePeer` (Cancel/`Deny` focused first per UI/UX Gate Rule 11):
     - Shows device label (User-Agent model), LAN IP, and 6-digit SAS (`482 - 910`).
     - Only explicit user confirmation (`[Trust & Pair]`) issues a signed session/device token to the phone and upgrades the WebSocket from `Pending` to `Authorized`.
3. **Trust Store (`~/.config/hayato/connect/devices.json`, mode `0600`):**
   - Stores paired device ID, friendly name, key/token digest, last seen timestamp, and **per-capability policy booleans** (`files`, `clipboard`, `links`, `media`, `camera`, `notifications`, `folder_sync`).
   - Previously trusted phones scanning a session QR or connecting via saved URL still authenticate against their stored device secret and can be revoked/unpaired at any time (`d` -> `ConfirmAction`).

---

## 3. Capability Architecture & Scoping

| Capability | Mechanism (Session-Scoped) | Data Flow & Security Controls | Priority |
|---|---|---|---|
| **1. Nearby Discovery** | LocalSend v2 UDP multicast (`224.0.0.167:53317`) + active WSS peer list | Runs only while `ConnectScreen` or `ShareScreen` is open; shows device model, IP, protocol (`HTTPS/WSS` or `LocalSend`). | **P0** |
| **2. Encrypted File Transfer** | Chunked `HTTPS` / `WSS` streaming over TLS (`~/.Downloads`) + existing LocalSend v2 push | Reuses `ShareServer` ZIP bundling & streaming (`MAX_UPLOAD_BYTES` / progress telemetry); never touches disk outside configured destination. | **P0** |
| **3. Shared Clipboard** | Manual `Ctrl+V` push + opt-in two-way watcher (`wl-paste` / `wl-copy` while window open) | Explicit toggle (`OFF` by default until paired or toggled); skips sensitive MIME types/empty updates; clears loop feedback via SHA-256 hash guard. | **P0** |
| **4. Send Links & Docs** | `Ctrl+L` inline compose (`ComposePush`) & phone push `/push/link` | URLs open via `hayato-browser`; Markdown/text snippets can open in `Notes` inbox or clipboard with user preview/action. | **P0** |
| **5. Remote Media Controls** | Pure-Rust `zbus` MPRIS2 bridge (`hayato-cassette`, browsers, `mpv`) over WSS | Play/Pause, Next, Prev, Seek, Volume synced between phone web remote & desktop players. | **P1** |
| **6. Phone Camera as Webcam** | Browser `getUserMedia` -> WebRTC DTLS/SRTP -> session-only PipeWire video source (or `v4l2loopback`) | Virtual webcam node exists **strictly while stream is active & window is open**. Respects mic mute & shows `Cam LIVE` badge + bitrate telemetry. | **P1** |
| **7. Notification Mirroring** | **Honestly Scoped:** Desktop (`hayato-notify`) -> Phone Web Notification API (foreground/open tab); Phone -> Desktop manual push or optional forwarder webhook | Web browsers **cannot** read Android/iOS OS notification shades silently. Desktop-to-phone excludes `Secret`/locked screens & pauses when recording (`hayato_ui::recording::is_recording()`). | **P2** |
| **8. Local Folder Sync** | On-demand manifest diff (`size` + `mtime` + `SHA-256`) between selected local folder and phone folder API / archive | Triggered **explicitly** (`Space` in `Transfer`)—zero resident `inotify` daemon. Shows dry-run diff (`N` push / `M` pull) before applying. | **P2** |

---

## 4. UI/UX Design Gate Specification

### 4.1 Interaction Paradigm: Master-Detail Live Workspace
Instead of modal sub-menus or overloading the quick Share picker:
- **Top `ActionStrip`** switches across 4 sections with zero nesting: `[1] Overview`, `[2] Transfer`, `[3] Remote`, `[4] Alerts`, plus `[Ctrl+Q] Pair QR`.
- **Single-pane (`width < 84`, e.g. `80x24`)**: renders Section Strip + focused Section list & status footer. `Ctrl+Q` switches cleanly to full-screen `PairQr`.
- **Dual-pane (`width >= DUAL_PANE_MIN_WIDTH = 84`, e.g. `94x30` `Alt+Space` float & `152x45` wide)**: left card hosts section controls; right card (`Live Session Deck`) stays pinned showing paired device trust/SAS status, live QR (when unpaired/idle), active transfer progress gauge, or webcam bitrate.

### 4.2 Single `ConnectPhase` Enum
```rust
pub enum ConnectSection {
    Overview, // Devices, trust state, quick Send / Clipboard / Link actions
    Transfer, // Files, links/docs, two-way clipboard toggle, on-demand folder sync
    Remote,   // MPRIS media controller & Phone WebRTC camera toggle/telemetry
    Alerts,   // Desktop <-> Phone notification forwarding toggles & inbox log
}

pub enum PushKind {
    Link,
    ClipboardText,
}

pub enum PendingConfirm {
    UnpairDevice { id: String, label: String },
    StopActiveAndClose,
}

pub enum ConnectPhase {
    Workspace {
        section: ConnectSection,
        strip: ActionStrip,
        strip_focused: bool,
    },
    PairQr {
        qr: QrCode,
        url: String,
        pin: String,
    },
    AuthorizePeer {
        peer_id: String,
        device_label: String,
        remote_ip: String,
        sas_code: String,
        confirm: Confirm, // Default focus: Deny (Cancel-first)
    },
    ComposePush {
        kind: PushKind,
        input: Input, // Rendered with ColorRole::Bg inside Surface
    },
    ConfirmAction {
        action: PendingConfirm,
        confirm: Confirm,
    },
}
```
`Screen::phase()` values: `"connect.overview"`, `"connect.transfer"`, `"connect.remote"`, `"connect.alerts"`, `"connect.pair_qr"`, `"connect.authorize"`, `"connect.compose"`, `"connect.confirm"`. File/folder selection delegates in-window to `FilesScreen` (same pattern as `vpn.rs`).

### 4.3 Non-`Alt` Keybindings & Pointer/Touch Targets
- **Global (`Workspace`)**: `1`–`4` section jump, `Tab`/`BackTab` focus between `ActionStrip` and body `ListState`, `Ctrl+Q` full Pairing QR, `Ctrl+S` Send File/Folder, `Ctrl+V` Push Clipboard, `Ctrl+L` Compose Link/Note, `Ctrl+R` Rescan LAN peers, `Space`/`Enter` activate/toggle row, `Esc` close (`ConfirmAction` if stream/transfer active).
- **Focused sub-sections**: `p`/`n`/`b` in `Remote` for Play-Pause/Next/Prev; `d` on trusted peer row to Unpair (`ConfirmAction`).
- **Modals (`AuthorizePeer`, `ConfirmAction`)**: suppress base `keybar()` (`None`) and delegate strictly to `Confirm::handle` / `Confirm::hit` / `Confirm::click`.
- **Density & Tokens**: `ListState::hit_row` adapts automatically between `1`-row (`Density::Normal`) and `2`-row (`Density::Tablet`) touch targets; zero `Color::Rgb` outside `design.rs`; every state pairs `Glyph` + text status with semantic `ColorRole` (`Ok` / `Warn` / `Danger` / `Muted`).

### 4.4 Responsive Wireframes

#### A. `80x24` Compact Single-Pane (`width < 84`)
```text
Hayato · Connect                                         192.168.1.42 · 1 Paired
────────────────────────────────────────────────────────────────────────────────
[1] Overview  [2] Transfer  [3] Remote  [4] Alerts
╭ Devices & Live Session ──────────────────────────────────────────────────────╮
│ ● Pixel 8 (WebRTC)          Paired · WSS + E2EE · 42 ms                     │
│   Clipboard: Two-way ON · Media: Paused · Cam: Off                           │
│                                                                              │
│ ── QUICK ACTIONS ─────────────────────────────────────────────────────────── │
│ > 󰁪  Send File or Folder…       Ctrl+S · pick in Files -> Phone              │
│   󰅌  Push Clipboard Now         Ctrl+V · "https://hayato.dev/specs"          │
│   󰌷  Send Link / Snippet…       Ctrl+L · open on phone browser               │
│   󰐂  Show Pairing QR (HTTPS)    Ctrl+Q · PIN 482-910 · new device            │
│   󰒍  Nearby LocalSend Peers     1 found (Bruno iPad · 192.168.1.58)          │
│                                                                              │
│ ── RECENT ACTIVITY ───────────────────────────────────────────────────────── │
│   ✓  IMG_4021.jpg               Received -> ~/Downloads (3.4 MiB)            │
│   ✓  Clipboard synced           18 bytes -> Pixel 8                          │
│                                                                              │
│                                                                              │
│ Session live (no background daemon) · closing window stops all ports         │
╰──────────────────────────────────────────────────────────────────────────────╯
1-4 section · Tab strip · Enter run · Ctrl+Q QR · Ctrl+S send · Esc close
```

#### B. `94x30` Floating Window (`width >= 84`, `Transfer` active)
```text
Hayato · Connect                                       192.168.1.42:51420 · TLS · 1 Paired
──────────────────────────────────────────────────────────────────────────────────────────────
[1] Overview  [2] Transfer  [3] Remote  [4] Alerts   [QR] Pair New Device
╭ Transfer & Sync ───────────────────────────────╮ ╭ Pixel 8 · Live Deck ────────────────────╮
│ ── SEND TO PHONE ───────────────────────────── │ │ ● PAIRED  E2EE SAS: 482-910             │
│ > 󰁪  Send File / Bundle…          Ctrl+S       │ │   HTTPS: https://192.168.1.42:51420     │
│   󰌷  Send Link or Note…           Ctrl+L       │ │                                         │
│   󰅌  Push Clipboard               Ctrl+V       │ │   ██████████████  ▄▄▄▄  ██████████████  │
│                                                │ │   ██          ██  ▀██▀  ██          ██  │
│ ── CLIPBOARD BRIDGE ────────────────────────── │ │   ██  ██████  ██  ▄██▄  ██  ██████  ██  │
│   [ON ] Auto-sync Desktop <-> Phone            │ │   ██  ██████  ██  ▀▄▄   ██  ██████  ██  │
│         Last: "cargo test -p hayato-cli"       │ │   ██          ██  ▄▀▄▀  ██          ██  │
│                                                │ │   ██████████████  ▀▄▀▄  ██████████████  │
│ ── RECEIVE INBOX ───────────────────────────── │ │                                         │
│   󰇚  Destination: ~/Downloads                  │ │ ── ACTIVE TRANSFER ──────────────────── │
│      2 files received this session             │ │ Sending: release-notes.pdf              │
│                                                │ │ [████████████░░░░░░░░] 62% · 2.1/3.4M   │
│ ── ON-DEMAND FOLDER SYNC ───────────────────── │ │                                         │
│   󰓦  ~/Documents/Notes <-> Phone/Notes         │ │ ── STREAM GUARD ─────────────────────── │
│      Idle · Space runs 1-shot diff sync        │ │ Webcam: Off · Alerts: Foreground-only   │
│   󰉋  Add Sync Folder Pair…                     │ │                                         │
│                                                │ │ [Ctrl+Q] Full QR  [c] Copy URL          │
│ Press Space to toggle or run sync              │ │ Zero-daemon · active while window open  │
╰────────────────────────────────────────────────╯ ╰─────────────────────────────────────────╯
1-4 tab · Tab strip · Space toggle/sync · Ctrl+S file · Ctrl+V clip · Esc close
```

#### C. `152x45` Wide Workspace (`Remote` active)
```text
Hayato · Connect                                                                                    192.168.1.42:51420 · TLS · Pixel 8 Paired · Cam LIVE
────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
[1] Overview  [2] Transfer  [3] Remote  [4] Alerts                                                                            [Ctrl+Q] Show Pairing QR
╭ Remote Media & Phone Camera ───────────────────────────────────────────────────╮ ╭ Pixel 8 · Live Session Deck ──────────────────────────────────────╮
│ ── NOW PLAYING (MPRIS <-> PHONE WEB REMOTE) ────────────────────────────────── │ │ ● PAIRED  Pixel 8 (Chrome Mobile) · RTT 14 ms · E2EE Verified     │
│   󰎈  hayato-cassette · Nujabes — Feather                                       │ │   Fingerprint SAS: 482-910 (verified) · TLS 1.3 + WebRTC DTLS     │
│      State: Playing · 02:14 / 02:55 · Volume 72%                               │ │                                                                   │
│                                                                                │ │ ── PHONE CAMERA -> WEBCAM FEED ────────────────────────────────── │
│ > 󰐊  Play / Pause                               [p] / Space                    │ │   Status: LIVE  WebRTC H264/VP8 -> PipeWire Virtual Cam         │
│   󰒭  Next Track                                 [n]                            │ │   Source: Back Wide (1280x720 @ 30 fps) · Audio: Muted            │
│   󰒮  Previous Track                             [b]                            │ │   Target: "Hayato Phone Cam" (visible to browser / OBS / Studio)  │
│   󰕾  Mirror Media Controls to Phone             [ON ]                          │ │                                                                   │
│                                                                                │ │   [████████████████████████████░░░░░░] 4.2 Mbps · 0 dropped       │
│ ── PHONE CAMERA AS WEBCAM (WEBRTC) ─────────────────────────────────────────── │ │                                                                   │
│   󰄀  Stream Phone Camera as Linux Webcam        [LIVE]                         │ │ ── QUICK TEST & PREVIEW ───────────────────────────────────────── │
│   󰑐  Switch Lens (Front / Back)                 Back Wide                      │ │   Enter opens viewfinder in hayato-studio, or select in any app.  │
│   󰂬  Resolution / FPS Cap                       720p @ 30 fps                  │ │   Closing this window immediately stops WebRTC + virtual camera.  │
│   󰍬  Include Phone Mic to PipeWire              [OFF]                          │ │                                                                   │
│                                                                                │ │ ── NEARBY & CLIPBOARD TELEMETRY ───────────────────────────────── │
│ ── SCOPED NOTIFICATIONS (SEE [4] ALERTS) ───────────────────────────────────── │ │   Clipboard: Auto-sync ON (last push 12s ago: 18 B)               │
│   󰂚  Desktop -> Phone Tab (while open)          [ON ] (foreground only)        │ │   LocalSend: 1 nearby peer (Bruno iPad · 192.168.1.58)            │
│   󰂛  Phone OS Shade Mirror                      Requires Companion Webhook     │ │   Transfers: 3 done (14.2 MiB) · 0 errors                         │
│                                                                                │ │                                                                   │
│ Space activates selected control · closing Connect stops webcam sink           │ │ Zero-daemon guarantee · all ports & PipeWire node drop on exit    │
╰────────────────────────────────────────────────────────────────────────────────╯ ╰───────────────────────────────────────────────────────────────────╯
1-4 tab · Tab strip · Enter/Space toggle · p/n/b media · Ctrl+S send · Ctrl+V clip · Esc close
```

#### D. Explicit Authorization Gate (`ConnectPhase::AuthorizePeer`)
```text
Hayato · Connect                                                Authorization Required
────────────────────────────────────────────────────────────────────────────────────────

                 ╭ Authorize New Device? ─────────────────────────────╮
                 │                                                    │
                 │  Device:    Mobile Browser (Android 15 · Chrome)   │
                 │  Address:   192.168.1.73                           │
                 │  Verify SAS on phone screen:   482 - 910           │
                 │                                                    │
                 │  Grants access while this window is open:          │
                 │   · Send/receive files & clipboard                 │
                 │   · Media remote & opt-in camera/sync              │
                 │                                                    │
                 │        [ Deny (Esc) ]      [ Trust & Pair ]        │
                 ╰────────────────────────────────────────────────────╯

Left/Right choose · Enter confirm · Esc deny
```

---

## 5. Phased Implementation Plan & Witnesses

- **P0 — Encrypted Transport, Trust Store & Core Hub (`ConnectScreen`):**
  1. Refactor `ShareServer` -> TLS (`openssl` + `tokio-native-tls`) + `tokio-tungstenite` WSS control channel alongside existing ephemeral HTTP/LocalSend fallback.
  2. Persistent identity cert + `~/.config/hayato/connect/devices.json` (`0600`) + 6-digit SAS `AuthorizePeer` gate.
  3. Build `ConnectScreen` (`[1] Overview`, `[2] Transfer`, `[3] Remote` stub/MPRIS, `[4] Alerts` scoped log) with two-way session-only clipboard & links/docs actions, plus `hayato share` `[p] Open in Connect` promotion.
- **P1 — Remote Media Controls & Phone Camera as Webcam:**
  1. Pure-Rust `zbus` MPRIS2 controller + WSS sync to Phone Web App media card.
  2. Browser `getUserMedia` -> WebRTC camera ingest -> session-scoped PipeWire virtual camera node (with clean teardown on toggle/exit and `hayato-studio` validation).
- **P2 — Scoped Alerts & On-Demand Local Folder Sync:**
  1. Desktop-to-Phone foreground notification relay (D-Bus / `hayato-notify` tap with recording/secret guardrails) + authenticated Phone-to-Desktop push/webhook.
  2. Dry-run manifest diff + one-shot bidirectional/unidirectional folder sync inside `Transfer` (never a background daemon).
- **Required Witnesses per Ship:**
  1. Unit tests (SAS derivation, trust store permissions/serialization, WSS auth rejection, clipboard hash loop guard, zero-alloc redraw & snapshots at `80x24`, `94x30`, `152x45`) + `desktop/scripts/check-desktop.sh`.
  2. User manual update in `desktop/uis/sway/files/usr/share/doc/hayato/`.
  3. Concise architectural rule added to `desktop/AGENTS.md`.
