# DuoLab — iPhone Duo pattern catalog (design)

Date: 2026-11-02. Status: draft for review.

## Goal

A small standalone app for trying Apple's iPhone Duo options on the simulator. You flip between layouts, bar setups and overlay strategies to see what works, then keep a shortlist of the practices you want. App-agnostic: no code, names, assets or accounts from any product.

Success: every lab runs on the iPhone Duo sim (iOS 27.1) in the closed, partially open and open poses. Each knob changes something visible. The Notes tab exports the starred choices as markdown.

## Constraints

- **Location:** `iphone-duo-support/demo/DuoLab/`.
- **Project:** a plain Xcode project (`DuoLab.xcodeproj`) with a single app target and a unit-test target. No XcodeGen, no SPM packages, no third-party dependencies.
- **Language:** SwiftUI first. UIKit appears only where a lab compares against it (anti-patterns, custom bars).
- **Deployment target:** iOS 27.1, so there are no `#available` forks. Built with Xcode 27.1.
- **Bundle id:** `com.example.duolab`. Local signing only.
- **Content:** placeholders only (SF Symbols, generated color tiles, lorem text).
- **Info.plist:** launch screen present (F-2h), all orientations supported, no `UIRequiresFullScreen`.

## App structure

The root is a native `TabView` with `Tab` items, so the shell itself shows the system bar behaviour (T-31, F-6a):

| Tab | Purpose |
|---|---|
| Catalog | List of labs. Each row has a title, a one-line question, and its fact IDs. |
| Inspector | Full-screen live readout of the environment (see HUD). |
| Compare | Pick one lab and two variants and render them side by side. |
| Notes | The starred variants, plus an optional free-text note per variant. Exports markdown to the clipboard. |

### HUD (global overlay, toggled from any lab's knob sheet)

It shows the horizontal and vertical size class, window size in points, safe-area insets per edge (leading, trailing, top, bottom), hinge status and angle (from `onHingeChange`), and reserved regions (`.division`, `.occlusion`) drawn as tinted rectangles with labels. It reads live values only and caches nothing (D10).

### Lab frame (shared by every lab)

- The demo content fills the screen.
- A toolbar button "Knobs" opens a sheet with that lab's controls. Each control has a one-line note in the form "Apple says … / watch for …" and the fact IDs from `research/` (F-, T-, M-).
- A star button on the current variant adds it to Notes.

## Labs (v1)

1. **Tab bar.** Knobs: `defaultTabBarPlacement` (automatic, bottom, sidebar), `.sidebarAdaptable` style, `tabBarMinimizeBehavior`, `tabViewBottomAccessory` on/off, badges, `.search` and `.prominent` roles, `toolbarVisibility(.hidden, for: .tabBar)` on a pushed screen, and a re-tap proxy binding (pop to root or scroll to top). The lab presents its own nested `TabView` full screen so the root shell is not affected.
2. **Toolbars and nav bars.** System `.toolbar` items vs a hand-built custom bar, to show which one moves to the side. Also prominent action placement, large vs inline title, and back/close order (F-3c, F-6a).
3. **List → detail.** `NavigationStack` push vs `NavigationSplitView` with two or three columns. Column visibility and preferred compact column (F-4a).
4. **Grids.** Fixed column count vs `GridItem(.adaptive(minimum:))` vs horizontal carousel. Edge clip vs fade. An "even columns around the fold" toggle (F-6b).
5. **Reading width.** Full width vs readable column at 480, 560 or 600 pt, with the header aligned to the column. Content: a settings-style form and long text (D4).
6. **Media + side panel.** `ArrangementView` in `.split` and `.overlay` styles vs a plain `HStack` fallback. The video stand-in either ignores the safe area or respects it (F-3b, D11).
7. **Fold-aware overlays.** A draggable floating bubble with reserved-region avoidance on/off, and a control cluster snapped onto the fold vs moved off it (F-3a, F-6b, D8).
8. **Sheets, popovers, alerts, menus.** Detents, `presentationSizing` (form, page), popover anchoring, confirmation dialogs and menus. Shows where the system moves them aside.
9. **Hinge effects.** An angle-driven decorative effect (for example a light or shadow sweep) through `onHingeChange`. It is limited to effects, as Apple directs (F-3d).
10. **Anti-patterns.** Each one is shown broken next to its fix: `UIScreen.main` sizing, symmetric inset maths (`width - left*2`), safe area cached at launch, `interfaceOrientation`-based layout, and a whole-app clamp to a phone column (F-3f, F-3g, R-§1).

## Data model

- `LabID`: enum of the 10 labs.
- Each lab owns an `@Observable` knob model (`struct`-like values, `Codable`) with a stable variant key, for example `grids:adaptive-200:fade`.
- `PickStore`: `@AppStorage`-backed JSON of `[Pick]` (lab, variant key, note, date). It is the only thing persisted.
- `DeepLink`: parses `duolab://lab/<id>?<knob>=<value>&hud=1`. Launch args `-lab <id>` and `-knob.<name> <value>` map to the same thing, for scripted captures (navigate folded, capture unfolded, per `practices/simulator-capture.md`).

## Error handling

- An unknown lab id or knob value in a deep link falls back to that lab's default and shows a small banner naming the bad value. It never crashes.
- With no hinge (the outer display only reports `.closed`; on other hardware the context is nil), the HUD shows "no hinge" and the hinge lab shows a static explanation.
- Empty reserved regions show "none" in the HUD instead of hiding the row.

## Testing

- **Unit tests:** deep-link and launch-arg parsing, knob ↔ variant-key round trip, PickStore encode/decode, and the markdown export format.
- **Manual and sim pass:** every lab × closed / partially open / open on the Duo sim, with screenshots in `demo/captures/` (outer: `--display=primary`, inner: `--display=primary-1`). Navigate with simnav or deep links while folded, then change pose and capture.

## Out of scope

UIKit twins of every lab, iPad and non-Duo layouts, App Store packaging, localization, and real media playback (a color or gradient tile stands in for video).

## Folder layout

```
demo/
  docs/2026-11-02-duolab-design.md
  DuoLab/
    DuoLab.xcodeproj
    DuoLab/            App, Shell/, HUD/, Labs/<NN-name>/, Model/, Resources/
    DuoLabTests/
  captures/
```
