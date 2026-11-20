# The bar as the session's statusline — 2026-11-19

A visual change, so the evidence is the picture and the numbers behind it.

The three images were drawn by **waybar itself**, at the panel's 1366×30, in a
throwaway `swayfx` session (`WLR_BACKENDS=headless`) with the shipped
`config.jsonc` and the generated `style.css` for Solarized Dark. Rendering it
off-screen is what keeps the live session out of the capture.

| | file |
|---|---|
| before | `screenshots/2026-11-19/bar-before.png` |
| after | `screenshots/2026-11-19/bar-after.png` |
| states | `screenshots/2026-11-19/bar-states.png` — work in progress and a critical battery |

Before is eleven rounded cards with a hue per icon and a workspace pill filled
with the accent. After is one edge-to-edge line: a flat segment per module, the
active workspace as a tab (selection tint, bold label, 2px accent rule on its
bottom edge), and exactly two filled chips — the running task and a mode. The
states image is the proof that the loud ones still read: the chip is the
background colour on the *readable* warning colour, and the critical battery is
`text` on the palette's danger tint with a 2px danger bar.

The numbers the design rests on, from `cargo test -p lazyos-theme` and
`a_status_drawn_as_text_clears_the_body_text_floor` (all sixteen built-in
themes):

- `text` on the background clears 4.5:1 — the palette's own validation floor;
- `ok_text` / `warn_text` / `danger_text` clear 4.5:1 on the background, and the
  background clears 4.5:1 on them, which is the inverted pair a filled chip
  uses;
- the active workspace label is `text` on `selection`, with the accent rule as
  the 3:1 cue, so the tab is never marked by its fill alone.

The old stylesheet's clock and tooltip used `strong`, the *bright* end of the
palette: `#bcc0cc` on `#eff1f5` in Catppuccin Latte, 1.6:1. That is the bug the
redesign removes, not a taste change.
