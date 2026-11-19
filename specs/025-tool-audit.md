# Spec 025 — Tool audit: readable tokens, honest states, one header grammar

- **Status**: in progress (Phases 0–2 implemented; snapshot net covers 24 screens)
- **Phase**: post-0.5 (polish of the ported framework)
- **Depends on**: 002 (design system), 004 (theme engine), 007 (menu/ask), 009 (search), 010/011/012/017 (pickers and surfaces)
- **Model**: `deepinfra/deepseek-ai/DeepSeek-V4.1-Flash-1017` (this session) — the audit is mostly
  measurement and token work; the visual judgement is bounded by the existing design system.
  Fallback `claude-sonnet-5-5`.
- **Branch**: `spec/025-tool-audit`
- **Plan**: [`docs/plan-ui.md`](../docs/plan-ui.md) §4 (design language), §5 (surfaces), §14 (motion)
- **Old paths**: unchanged. This spec changes rendering and copy, not commands, symlinks or files.

## Problem

All 59 commands now draw through one shell, and the shell has four defects that every surface
inherits:

1. **The selected row is not readable in every theme.** Row metadata is drawn with the palette's
   `dim` role on top of `selection`. Computed over the 16 built-in themes, `dim` on `bg` is below
   the 4.5:1 body floor in 6 themes (Solarized 2.79, Catppuccin Latte 2.69, One Dark 3.24,
   Everforest 3.56, Nord 4.25, Tokyo Night 4.40); `dim` on `selection` fails in 15 of 16; the
   selection fill is 1.15–1.56:1 against the background in every theme (Solarized is 1.00 because
   `selection == surface`); the border (`surface_alt`) is below the 3:1 UI floor in 11 themes.
   `lazyos-theme/src/theme.rs:288` deliberately excludes `dim` from the contrast floor, and
   `lazyos-ui/src/widgets.rs:1078,1118` puts it on the selection fill.
2. **The key bar cuts words.** `draw_keybar` (`lazyos-ui/src/widgets.rs:210`) writes a hint and
   stops when the row runs out, so a label is cut mid-word: “Fastfetc”, “[Esc] clos”, “[Es”.
   Confirmed on About and Free space at 106 columns; 13 screens declare five or more hints.
3. **Several states dead-end.** An empty folder shows only `..` and `hidden files`; a missing
   `fd`/`rg` says “there is nothing to walk with” and offers nothing; Ask with no agent still
   says “Enter asks” and only refuses after Enter.
4. **Every card repeats its own name.** “LazyOS · Power” over “Power”, “Settings · Settings”,
   About with three identity blocks, “End a process · Process manager”. The header has no
   grammar, so the left side is sometimes the product, sometimes the surface, sometimes a verb.

The result is a framework that looks coherent and specific, but is harder to read and slower to
scan than it should be.

## Scope

**In:**

- `lazyos-ui`: derived readable roles (`Muted`, `Border`, `Selection`, `SelectionText`,
  `SelectionDim`, `KeyText`), the selected-row styles, the key-bar overflow rule.
- `lazyos-cli`: the empty-folder row, the Ask no-agent state, the header/card-title grammar and
  the copy of the counts (Phase 1), the About consolidation (Phase 1).
- Golden snapshots at 80×24 and 152×45 for every screen touched, and for the screens that have
  none yet (Phase 2).

**Out:**

- A new visual direction, new glyphs, new themes, or a different card shape.
- Behaviour changes to destructive actions. The Cancel-first confirm stays exactly as it is.
- Installing packages from inside Find/Grep (needs a product decision and a `menu pkg --search`
  path; Phase 2 at the earliest).

## Design

### Readable roles are computed, not stored

A theme file keeps saying `dim = …` and `selection = …`; the UI derives what it needs **once**,
when the session's palette is read (`Design::new` / `with_palette`), never per frame:

| Role | Derived from | Floor | Why |
|---|---|---|---|
| `Muted` | `dim` lifted toward `text` | 4.5:1 on `bg` | secondary text that carries meaning (details, statuses, hints) |
| `Border` | `surface_alt` lifted toward `text` | 3.0:1 on `bg` | a card boundary is a UI component |
| `Selection` | the theme's `selection` | distinct from `bg` | lifting the fill to 3:1 made the theme's own text 1.9:1 on it; the 3:1 cue is the accent bar and the bold label |
| `SelectionText` | `text` lifted toward the extreme | 4.5:1 on `Selection` | the selected label |
| `SelectionDim` | `Muted` lifted toward `text` | 4.5:1 on `Selection` | the selected row's detail |
| `KeyText` | `bg` lifted toward the extreme | 4.5:1 on `Accent` | the key chip's letters |

`TextStyle::Dim` maps to `Muted`; `TextStyle::Selected`/`SelectedDim` are new. `ColorRole::Dim`
still returns the raw palette value for anything that wants the theme's own quiet grey; widgets
ask for the style, not the role.

This keeps the solarized byte-for-byte invariant in `theme.rs` (theme files and generated
surfaces do not change) while making the TUI readable on every palette. If a future theme is
unreadable, the new test names it.

### Key bar

A hint is drawn only if its whole `[key]  label` fits; otherwise the bar writes `…` and stops.
A partial label is never drawn. The trailing separator spaces may be truncated, the word may not.

### Empty and refused states

- Files: an empty folder (or an empty search) gets a row that says so and names the way out
  (`Ctrl+H shows hidden files`). It is informational: Enter does nothing.
- Ask: with no agent, the card leads with the refusal and the key bar says `Enter  open Agents`;
  Enter opens the Agents menu instead of asking a question nobody can answer.
- Find/Grep: the message names the exact package and command. An install action is deferred to
  Phase 2 because it needs a confirmed `menu pkg --search` path.

### Header grammar

One rule, enforced by review and snapshots: the header's left side is the surface
(`LazyOS · Menu` only for the root menu and the palette), the right side is the status, and the
card title is the **context**, not the screen name. A picker's header is
`<name> · <question>`; when the question repeats the name, the question changes.

## Findings and scores

`H` hierarchy · `T` typography · `C` colour · `S` spacing · `St` states · `A` accessibility ·
`Cp` copy. 1 = broken, 5 = strong.

| Family | H | T | C | S | St | A | Cp | Evidence |
|---|---|---|---|---|---|---|---|---|
| Shell | 3 | 4 | 2 | 3 | 4 | 2 | 4 | selected detail 3.15:1 (Tokyo), 2.42:1 (Solarized) |
| Root menu | 3 | 4 | 2 | 3 | 4 | 2 | 4 | 51 flat rows; “51 rows” |
| Palette | 2 | 4 | 2 | 3 | 4 | 2 | 3 | 71 rows; first 20 repeat the menu |
| Pickers | 3 | 4 | 2 | 3 | 3 | 2 | 4 | “Settings · Settings”; hibernate reason cut |
| Files/search | 4 | 4 | 2 | 4 | 3 | 2 | 4 | empty folder and missing tools dead-end |
| Notes | 4 | 4 | 2 | 4 | 4 | 2 | 4 | strong list + preview |
| Ask | 3 | 4 | 2 | 4 | 2 | 2 | 4 | no-agent state still invites Enter |
| Task | 4 | 4 | 2 | 3 | 3 | 2 | 4 | log scrolls but says nothing |
| About | 2 | 4 | 2 | 2 | 3 | 2 | 3 | three identity blocks; chips and key bar cut |
| Free space | 3 | 4 | 2 | 3 | 4 | 2 | 4 | good WORKING state; status twice |
| Learn | 3 | 4 | 2 | 3 | 4 | 2 | 4 | chips duplicate the key bar |
| Notification card | 4 | 4 | 3 | 4 | 3 | 3 | 4 | 18 px close target |
| Games | 4 | 4 | 2 | 4 | 3 | 2 | 4 | tabs + hero; good empty |
| Installer (code) | 4 | 4 | 2 | 3 | 4 | 2 | 4 | long key hints will clip at 80 |
| Greeter (code) | 4 | 4 | 2 | 4 | 4 | 2 | 4 | same tokens |

Averages: H 3.2 · T 4.0 · **C 2.1** · S 3.4 · St 3.4 · **A 2.1** · Cp 3.9.

No banned default is present (no gradient, no emoji icons, no glassmorphism, no stock copy).
The one near miss is “grey on grey” in the selected row, which is the first fix.

### Phase 0 measured

| Pair | Solarized before → after | Tokyo Night before → after |
|---|---|---|
| `dim` on `bg` | 2.79 → **4.51** | 4.40 → **4.51** |
| border on `bg` | 2.79 → **3.01** | 1.91 → **3.01** |
| `dim` on `selection` | 2.42 → **4.50** | 3.15 → **4.50** |
| text on `selection` | 4.86 → 4.86 | 7.57 → 7.57 |
| selection fill on `bg` | 1.15 (unchanged; the bar is the cue) | 1.40 (unchanged) |

## Work

### Phase 0 — readable and honest (this branch)

- [x] `Muted`, `Border`, `Selection`, `SelectionText`, `SelectionDim`, `KeyText` computed in
      `Design`; `TextStyle::Dim` uses `Muted`; selected rows use the selection styles.
- [x] Border and scrollbar track use `Border`; key chips use `KeyText`.
- [x] `draw_keybar` drops a whole hint and writes `…`; never cuts a label.
- [x] Files: the empty-folder/empty-search row.
- [x] Ask: the no-agent card and `Enter  open Agents`.
- [x] Snapshot updates for the states that changed; new snapshot for the no-agent and empty
      folder states.
- [x] Unit tests for the derived floors, the key bar and the empty folder; an integration test
      for the no-agent Enter.

### Phase 1 — hierarchy and copy

- [x] Header grammar and card titles (`Settings · Settings`, `End a process · Process manager`,
      the duplicated `Menu`/`Power`/`About` titles). One rule: header `<product> · <surface>`,
      card title = the context; a picker question that repeats the name is not drawn.
- [x] Menu section headings (`Row::heading` + `Group::heading`) and honest counts:
      “52 commands”, “1 match”, “0 matches”. A heading is never a cursor stop or a click.
- [x] Palette identity: the superset is kept (it is the palette) but grouped under the same
      headings, the prompt says “type a command, theme or setting”, the themes sort into
      `System`, and a theme row says “the palette and its wallpaper”, not the command.
- [x] About: card title “This machine” instead of a second “About”; the revision line keeps the
      whole fact; the action chips already drop whole pills.
- [x] Hibernate reason shortened to “Needs a swap partition of 2 GB+ labelled lazyos_swap.” so
      the actionable part is whole at 80 columns.

### Phase 2 — consistency and the net

- [x] Task log position and a failure card: the log has a scrollbar and a
      `[paused]` marker, the outcome is a coloured card (Done/Failed/Stopped), and a
      failure offers `l` (log) and `c` (copy error).
- [x] Notification close target 44 logical px (the glyph stays 12 px). The keyboard
      dismissal is the existing `$mod+Shift+comma` binding (`dismiss-newest`).
- [x] Find/Grep install action: `menu pkg --search <package>` opens the package search
      on `fd-find` or `ripgrep`; `Ctrl+I` is the one key, and the keybar drops the
      useless “open”/“copy path” hints while the tool is missing.
- [x] Snapshot net, first pass: `tests/screens.rs` renders 24 screens at 80×24 and
      152×45. Seven have golden files (Capture, QR, Reminders, Calculator, Developer,
      Notifications, Clipboard); seventeen are smoke renders because their rows depend on
      the machine (Media, Applications, Learn, Games, Keys, Colour, Emoji, About, Clean,
      Audio, Bluetooth, Network, Window, Run, Kill, Controller, Packages). The screens touched in Phases 0–1
      (menu, palette, ask, files, find, grep, notes, pickers, task) already had goldens.
      The remaining surfaces (Agents, Places, Download, Layout, File actions,
      Translate, Dictate, Theme, Controller, Installer, Greeter) are the next pass.
- [x] Empty-state cards are 76 wide and ellipsize instead of cutting a word; the
      Reminders, Notifications and Clipboard hints fit at 80 columns.
- [x] Settings: the picker question is “What do you want to change?” and Accessibility
      has Reduced motion plus the on-screen keyboard (the touch-target/tablet toggle
      stays under Input, so one key never lives in two sections).

## Acceptance criteria

- [x] Every built-in theme clears `Muted` 4.5 on `bg`, `Border` 3.0 on `bg`, `Accent` 3.0 on
      `bg`, `SelectionText`/`SelectionDim` 4.5 on `Selection`, `KeyText` 4.5 on `Accent`, and
      the selection fill is distinct from the background. Observed by
      `every_builtin_theme_clears_the_derived_floors` in `lazyos-ui/src/design.rs`.
- [x] No key bar cuts a word at 80×24 or 152×45; the last hint (the way out) stays on the right.
      Observed by `the_keybar_drops_a_hint_rather_than_cutting_its_label` and the About capture.
- [x] An empty folder and a search with no results say so and name the way out. Observed by the
      `files-empty` snapshots and `an_empty_folder_says_so_and_keeps_the_switch`.
- [x] Ask with no agent says so before the field and Enter opens the Agents menu. Observed by
      the `ask-no-agent` snapshots and `ask_without_an_agent_opens_the_agents_menu`.
- [x] The selected row's detail is readable on every theme. Observed by the contrast test and
      the 80×24 snapshots.
- [x] No screen repeats its own name: the header carries the surface and the card carries the
      context; a picker whose question repeats the name draws no title. Observed by the
      `picker-format-*`, `menu-*`, `files-*` and `notes-*` snapshots.
- [x] The menu groups its rows with headings the cursor and a click skip, and the count says
      commands or matches. Observed by `a_heading_is_drawn_but_never_selected` and the menu
      snapshots at both grids.
- [x] A failed task shows its error in a danger card and offers `c` to copy it; the log shows a
      scrollbar and `↑↓`/`End` are in the keybar. Observed by the `task-*` snapshots.
- [x] A missing `fd`/`rg` offers the package search on that package. Observed by
      `a_missing_walker_offers_the_package_that_provides_it` and
      `a_missing_ripgrep_offers_the_package_that_provides_it`.
- [x] The notification close target is 44 logical px. Observed in
      `lazyos-notify/src/render.rs`.
- [x] Settings → Accessibility has two real rows and each settings key belongs to one section.
      Observed by `every_settings_row_belongs_to_one_section`.
- [x] `cargo test -p lazyos-ui -p lazyos-cli` is green; `cargo clippy --all-targets -D warnings`
      is green.
- [ ] `desktop/scripts/check-desktop.sh` (and `./build.sh validate`) are green on the Hayato.
- [x] The manual paragraph in `desktop/uis/sway/files/usr/share/doc/lazyos/02-menus.md` and the
      `desktop/AGENTS.md` bullet are in the same change.

## Tests

- **Unit** (`lazyos-ui/src/design.rs`): every built-in palette clears every derived floor.
- **Unit** (`lazyos-ui/src/widgets.rs`): the key bar drops a hint rather than cutting its label;
  the selected row uses `SelectionText`/`SelectionDim`.
- **Unit** (`lazyos-cli/src/files/browse.rs`): an empty directory produces the informational row.
- **Unit** (`lazyos-cli/tests/files.rs`): `Ctrl+I` on a missing walker/searcher hands the package
  name to `menu pkg --search`.
- **Unit** (`lazyos-cli/src/system/settings.rs`): every settings key belongs to one section.
- **Snapshot** (`lazyos-cli/tests/`): `menu`, `ask-no-agent`, `files-empty`, `find-no-fd`,
  `grep-no-ripgrep`, `picker-format-*`, `notes-*` at 80×24 and 152×45.
- **Screen net** (`lazyos-cli/tests/screens.rs`): 24 more screens at both grids, seven with
  goldens and seventeen as smoke renders; an isolated home keeps the rows deterministic and a
  path normalisation keeps the capture snapshot free of the runner's temp directory.
- **Integration**: the menu test that opens Ask with no agent on `PATH` and asserts the Agents
  choice.

## Risks

- **The selection fill stays the theme's** (1.15–1.56:1 against the background). Lifting it to
  3:1 made solarized's own text 1.9:1 on the fill, which is a worse trade. The 3:1 cue is the
  accent bar and the bold label; review that combination on the Hayato before merging. If it
  reads as too weak, the next step is a dedicated `selection_fill` token in the theme, not a
  computed lift that breaks the text.
- **A computed `Muted` that equals `Dim`** in themes that already pass would hide the hierarchy.
  The test asserts the role is used, not that it differs; the visual check is the snapshot.
- **Snapshot churn.** The empty-folder and no-agent changes are intentional; regenerate with
  `UPDATE_SNAPSHOTS=1` and read the diff, never accept it blind.
