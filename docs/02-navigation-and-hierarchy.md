# 02 · Navigation and hierarchy

Researched 2026-11-02. Confidence: **verified** / **secondary** / **our view**, as in `00-principles.md`.
Tab bar API facts are in `research/native-tabbar-liquid-glass-facts.md`; this file is about *structure*.

## What we do in DuoLab and why

Labs 01 (tab bar), 02 (toolbars) and 03 (list and detail) show the containers. They don't yet show
**where Back lives** on each display, **what a push does inside a split view**, or **how a zoom
transition behaves when the source and destination sit in different panes**. Those are the questions
people ask after the first fold. Backlog items B3 (collapse rules), B7 (zoom across panes) and B8
(deep hierarchy on the inner display) answer them. The rule we demonstrate: *same hierarchy everywhere,
one extra level visible when open, and Back always at the top of the bar nearest the content it pops.*

## 1. Top-level navigation: tab bar vs sidebar

| Option | What Apple says | Measured / known | DuoLab verdict |
|---|---|---|---|
| Native `TabView`, default placement | "tabs will appear on the inner and outer display, laying out vertically when appropriate" ([111461](https://developer.apple.com/videos/play/tech-talks/111461/), verified). On the vertical bar the tab bar "stays bottom aligned" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified). | vertical, in the trailing 84 pt rail, in every pose we captured (all landscape) | **Recommended** (lab 01) |
| Sidebar on the inner display, `.defaultTabBarPlacement(.sidebar)` | "this isn't for every app. It works best for information-dense apps like this example from Health" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified) | opt-in only; `sidebarAdaptable` alone does not give a sidebar | **Consider** for 5+ destinations or sections (lab 01) |
| Prominent tab (`TabRole.prominent`) | iOS 27; one tab, sits apart (verified, see tab bar facts #3) | not tested on Duo | **Consider**; a candidate option for lab 01 |
| Minimize on scroll | HIG frames it as "minimize the tab bar to preserve the toolbar actions" in task views via `toolbarVerticalCompressionBehavior` (verified) | `.tabBarMinimizeBehavior` did nothing on Duo (measured, `demo/README.md`) | **Avoid** as a scroll effect; see B6 for the compression alternative |
| Custom bottom bar | Custom bars are not converted to vertical (verified) | stays a horizontal strip | **Avoid** |

Others: Google replaces the bottom navigation bar with a **navigation rail** on large screens
([Tier 2 UI_Secondary_Elements](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), secondary),
and suggests a rail even on cover screens because it avoids cutouts and respects the short height
([Android postures](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation), secondary).
Apple reached the same answer by moving the tab bar into the side rail. There's nothing to port.

**Re-tap to pop to root** still matters: there is no native hook in SwiftUI, use a proxy binding
(tab bar facts #21, secondary). On the inner display a re-tap should pop the *detail* column first,
then the list (our view).

## 2. Second level: list + detail, and the third column

- Split views "expand on the inner display and collapse to a single pane on the outer display", and
  adjust to the fold automatically ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
  In book pose the columns become an even 50/50 ([111463](https://developer.apple.com/videos/play/tech-talks/111463/), verified).
- **Bars in a split view**: the sidebar/content column keeps horizontal bars, the detail column gets
  the vertical bar. Inspectors keep horizontal bars ([Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), [111462](https://developer.apple.com/videos/play/tech-talks/111462/), verified).
  Mail keeps list controls "above the leading pane to indicate that they apply to the list"
  ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
- **Three columns don't fit**: a three-column `NavigationSplitView` shows two on the open display even
  with `columnVisibility = .all` (measured, `demo/README.md`). Treat the inner display as a two-column
  canvas (our view). Apple's examples are all two-column (Mail, Notes, Reminders).

Google's list-detail canonical layout spells out collapse/expand behaviour Apple leaves implicit
([canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), secondary):
1. Both panes → narrow: the **detail stays**, the list hides.
2. Detail only → wide: both show, and **the list highlights the selected item**.
3. List only → wide: list plus a **placeholder** detail.

We adopt all three for DuoLab (our view). Rule 3 means the inner display needs an empty-detail state
that isn't blank: a short hint ("Pick an item") or the first item auto-selected. Apple doesn't say
which; we lean to a hint because auto-selecting changes state on unfold, which breaks P2 (our view).

Google's supporting pane is the other two-pane shape: a primary area (~70% on expanded width) plus a
pane that is meaningless on its own (comments, a playlist, tools) (secondary). On Duo this is
`ArrangementView(.split)` with a layout ratio (`splitArrangementLayoutRatio`), not a split view,
because there is no navigation between the panes ([ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview), verified API; mapping is our view).
Microsoft's "companion pane" is the same pattern ([Surface Duo walkthrough](https://devblogs.microsoft.com/surface-duo/dual-screen-app-design-walkthrough), secondary).

## 3. Where Back goes

| Context | Where Back is | Source |
|---|---|---|
| Vertical bar (outer display; inner in landscape) | **top of the vertical bar**, then the prominent action (Done) | verified, [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [111462](https://developer.apple.com/videos/play/tech-talks/111462/) |
| Inner display in portrait | horizontal bar, top leading, as on any iPhone | verified, [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| Split view, detail pushed | detail column's bar, i.e. the vertical bar on the trailing edge | verified (detail column owns the vertical bar) |
| App on the left in Split View multitasking | vertical bar on the **left** edge | verified, [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| Custom Back/Close | `ToolbarItem(placement: .cancellationAction)` so it lands at the top | verified, [Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) |
| Right-to-left languages | bar stays on the same hardware side | verified, [111462](https://developer.apple.com/videos/play/tech-talks/111462/) |

Consequences (our view):
- On the open display in landscape, Back for the detail is at the **top right**, far from the list on
  the left. That is by design: Back pops the column the bar belongs to. Don't add a second Back button
  in the content to "fix" the distance.
- The **swipe from the leading edge** of the detail column remains the fast way back. Don't put
  horizontal swipe gestures (carousels, swipe-to-page) flush against the detail column's leading edge.
- In a collapsed split view (closed), the system Back returns from detail to list. Google needs an
  explicit `BackHandler` for this case ([canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), secondary);
  `NavigationSplitView` does it for you (verified behaviour of the container on compact iPhone).

## 4. Deep hierarchy on the inner display

Problem: on the outer display a five-level drill-down is five pushes. On the inner display with two
columns, where do levels 3–5 go?

| Option | Verdict | Why |
|---|---|---|
| Push levels 3+ inside the detail column; list stays put | **Recommended** | keeps the list as the stable anchor; Back pops the detail stack; matches Mail and Notes (our view, consistent with verified "additional level" guidance) |
| Shift columns left (level 2 becomes the list, level 3 the detail) | **Avoid** | the anchor moves on every tap; contradicts "keep controls' relative positions as similar as possible" (verified HIG) |
| Three columns | **Avoid** | measured: only two show |
| Present level 3+ as a sheet | **Consider** only for self-contained tasks (edit, compose) | HIG sheets: "for a simple task" (verified, [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)) |
| New window for a deep item | **Consider** on the inner display only | multiple scenes are supported; not available on the outer display (verified, [111464](https://developer.apple.com/videos/play/tech-talks/111464/)) |

On fold to the outer display, the user should land on the deepest level they were on, with the same
Back chain (P2). That requires one navigation path owned above the split view (our view; this is the
SwiftUI `NavigationSplitView` + `NavigationStack` in detail pattern).

## 5. Zoom transitions

- `navigationTransition(.zoom(sourceID:in:))` + `matchedTransitionSource(id:in:)`, iOS 18
  ([zoom](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)), verified).
  "The cell you tap morphs into the incoming view… continuously interactive, allowing you to grab and
  drag it around" ([WWDC24 10145](https://developer.apple.com/videos/play/wwdc2024/10145/), verified).
- Sheets can morph out of the toolbar button that presents them by making that item the zoom source
  ([WWDC25 323](https://developer.apple.com/videos/play/wwdc2025/323/), verified).
- **Where zoom fits on Duo** (our view): grid → full-screen item (photos, cards) on either display.
  It is the natural fit for lab 04 grids and lab 06 media.
- **Where it doesn't**: list → detail inside a split view, where the destination opens in the *other*
  column. A zoom that flies across the fold to a different pane reads as a page change, not a push.
  Whether the system even animates a zoom from the content column into the detail column is
  **unverified**; B7 should test it and show the plain push as the recommended option there.
- **Fold during a zoomed-in view**: the source cell may move or vanish after the resize (different
  column count). The dismiss animation then has nowhere sensible to return to. Test it; if it looks
  wrong, let dismissal fall back to the default (our view; behaviour unverified).

## 6. Other platforms, briefly

| Pattern | Source | iOS equivalent | DuoLab |
|---|---|---|---|
| List-detail with explicit collapse rules | Google canonical layouts | `NavigationSplitView` + `preferredCompactColumn` | yes, B3 |
| Supporting pane (≈70/30) | Google canonical layouts | `ArrangementView(.split)` + layout ratio | yes, extends lab 06 |
| Dual view (same data, two forms: map + list) | Microsoft Surface Duo | two-column split with a shared model | consider (B10) |
| Navigation rail instead of bottom bar | Google | system vertical tab bar | no, the system does it |

## Sources

**Apple says** (verified)
- [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [HIG: Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets)
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- Tech talks [111461](https://developer.apple.com/videos/play/tech-talks/111461/), [111462](https://developer.apple.com/videos/play/tech-talks/111462/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/)
- [zoom(sourceID:in:)](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)), [WWDC24 10145 Enhance your UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/), [WWDC25 323 Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [NavigationSplitView(preferredCompactColumn:)](https://developer.apple.com/documentation/swiftui/navigationsplitview/init(preferredcompactcolumn:sidebar:detail:)), [defaultTabBarPlacement](https://developer.apple.com/documentation/swiftui/view/defaulttabbarplacement(_:)), [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview)

**Others do** (secondary)
- Google: [Canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), [Tier 2](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), [Postures and orientation](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation)
- Microsoft: [Dual-screen app design walkthrough](https://devblogs.microsoft.com/surface-duo/dual-screen-app-design-walkthrough)

**We think** (our view): two-column ceiling as a design rule; placeholder hint over auto-select;
push-inside-detail for deep levels; no second Back; zoom only where source and destination share a pane.
