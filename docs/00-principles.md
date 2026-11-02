# 00 · Principles for a foldable iPhone app

Researched 2026-11-02 for DuoLab. Read with `research/apple-foldable-facts.md` (device facts) and
`research/on-device-measurements.md` (what the simulator hands the app). This file does not repeat
those facts; it turns them into rules.

Confidence labels, same as the research files:
- **verified**: an Apple source says it (HIG, developer docs, tech talk transcript, or the Xcode 27.1 SDK interface).
- **secondary**: only non-Apple sources say it (Google, Samsung, Microsoft, blogs, reviews).
- **our view**: reasoning from the sources, not stated by anyone. Labelled every time.

Nothing in these docs was measured by the research pass. Measurements quoted come from the existing
`research/on-device-measurements.md` and `demo/README.md`.

## What we do in DuoLab and why

DuoLab already shows ten layout decisions (tab bar, toolbars, list/detail, grids, reading width,
media, floating overlays, presentations, hinge effects, pitfalls). Those labs cover *where things go
on each display*. What they don't cover yet is *what happens between displays*: folding mid-task,
the laptop pose, feedback placement, and motion during a resize. The 12 principles below are the
spine for both sets. Each one names the lab that shows it today, or the backlog item
(`07-lab-backlog.md`) that will.

## The principles

### P1. Design two size classes, not five poses
- **Rule.** Build a compact-width layout (outer display) and a regular-width layout (inner display). Let
  every pose fall out of those two plus safe areas and reserved regions. Never branch on pose, device
  model, idiom or interface orientation.
- **Why.** Apple: "Supporting the device's various poses doesn't mean designing a custom layout for each
  one… A compact width layout for the outer display and a regular width layout for the inner display
  give you the fundamentals for every pose" ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
  The tech talk adds "Avoid fixed widths, breakpoints, or any metrics tied to a specific screen"
  ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified). Google says the same
  in its own terms: think in panes, and treat window size class as the input ([Android postures](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation), secondary).
- **Lab.** 03 List and detail, 04 Grids, 10 Pitfalls ("Layout by orientation", "Sizing from the screen").

### P2. Folding is a resize, not a relaunch: keep every piece of state
- **Rule.** Navigation path, selection, scroll position, typed text, keyboard focus, playback position
  and any presented sheet survive a fold or unfold. Hoist state above any size-class branch.
- **Why.** Apple: "Keep functionality and the state of elements the same between displays" and "People
  may open and close the device frequently while using your app, so it needs to be predictable and
  consistent inside and out" ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified).
  Google makes it a pass/fail test: scroll position kept, typed text kept "and the keyboard state is
  restored", playback resumes ([Tier 3 Config_Changes](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3), secondary).
  Samsung: the app should continue "where the user left off", text entry should carry over with the
  keyboard still open ([Samsung foldable design](https://developer.samsung.com/one-ui/largescreen-and-foldable/designing_for_foldable.html), secondary).
- **Lab.** Not yet. Backlog **B1 Fold mid-task** (top 5).

### P3. Small moves beat rearrangement
- **Rule.** When the device folds, move only what must move to stay visible and tappable. Move related
  elements together. Don't move an element far from its source.
- **Why.** "Avoid extreme layout changes as people fold the device. Move only what's necessary… favor
  small adjustments over rearrangement" ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
  The "displacement" pattern: "when elements work together, move them together… Moving an element far
  away from its source weakens their visual relationship" ([111463](https://developer.apple.com/videos/play/tech-talks/111463/), verified).
- **Lab.** 07 Floating overlays (fold-aware overlay vs controls split by the fold).

### P4. Let system containers and presentations do the adapting
- **Rule.** Reach for `NavigationSplitView`, `TabView`, sheets, alerts, menus, popovers and
  `ArrangementView` before writing custom geometry. They already collapse, move off the fold, and put
  bars on the side.
- **Why.** "Components like alerts, context menus, and sheets automatically move to account for the
  fold, while larger components like split views adapt their columns' width and margins"
  ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
  Custom `UIToolbar`/`UINavigationBar`/`UITabBar` bars are not converted to vertical bars
  ([Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo), verified).
- **Lab.** 01 Tab bar, 02 Toolbars ("Custom bar" = Avoid), 03 List and detail, 08 Presentations.

### P5. Nothing tappable in the fold; scrolling content may cross it
- **Rule.** In book pose, keep buttons, fields and cards clear of the active `.division` region. Lists,
  feeds and articles may scroll through it. In grids, prefer an even column count so the fold lands in a gutter.
- **Why.** "Keep interactive elements out of the curve region as much as possible… Scrollable content
  doesn't need to avoid this region" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified).
  "Continuous scrolling content like articles, feeds, documents, and lists don't displace"
  ([111463](https://developer.apple.com/videos/play/tech-talks/111463/), verified). Samsung: "Avoid
  positioning interactive elements near the crease" (secondary). Google: allow "a wider gutter to
  accommodate the hinge" (secondary).
- **Lab.** 04 Grids (even columns), 07 Floating overlays.

### P6. Bars live on the side: order them, label them, prioritise them, don't fight them
- **Rule.** Back/Close at the top of the vertical bar, then the prominent action. Give every item a symbol
  and a title. Set visibility priorities so frequent actions and badged items overflow last. Use the
  system overflow menu. Don't opt out of vertical bars except for single-page, bottom-heavy UIs or a
  sheet with one button.
- **Why.** All verified in [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
  and [111462](https://developer.apple.com/videos/play/tech-talks/111462/): "In general, don't override
  the default bar placement"; "Items overflow from bottom to top by default"; `toolbarVerticalBehavior`
  docs: "Treat it as a stable choice: avoid changing it frequently as the user navigates"
  ([doc](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)), verified).
- **Lab.** 01 Tab bar, 02 Toolbars. Backlog **B6 Bar compression** extends it.

### P7. Respect each safe-area edge and each reserved region separately
- **Rule.** Size from the container, inset by each edge independently, and query `ReservedRegion` for
  custom chrome. Never assume left == right. Never cache geometry.
- **Why.** "Safe areas are often asymmetric… avoid assuming that insets on opposite sides are equal"
  ([111461](https://developer.apple.com/videos/play/tech-talks/111461/), verified). Measured: 84 pt
  trailing rail on both displays, transient geometry during a fold
  (`research/on-device-measurements.md`).
- **Lab.** 10 Pitfalls (symmetric insets, insets cached at launch, sizing from the screen).

### P8. Inner display: one more level of the same hierarchy
- **Rule.** Open shows list *and* detail (or sidebar + content); closed shows one of them. The hierarchy
  and the set of destinations stay the same.
- **Why.** "Maintain your app's information hierarchy, but show an additional level of hierarchy on the
  larger inner display if it makes sense" (Mail example, [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
  "Just make sure your hierarchy doesn't change between the outer and inner displays"
  ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified). Google's list-detail
  canonical layout defines exactly what to keep visible when it collapses ([canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), secondary).
- **Lab.** 03 List and detail. Backlog **B3 Collapse rules** covers the fold moment.

### P9. Laptop pose is optional, and when you do it: view up, controls down, same controls
- **Rule.** With the inner display in portrait and half folded on a table, put the thing people watch
  in the top half and the things they tap in the bottom half. Keep every control that exists in other
  poses.
- **Why.** "Media can sit at the top, while tappable controls live on a stable base at the bottom. If you
  decide to do a special layout for this pose, just be sure it has all the same controls and general
  hierarchy as other poses" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified).
  `ArrangementView(.overlay)` does this split for you: folded in portrait, secondary on top, primary at
  the bottom ([OverlayArrangementViewStyle](https://developer.apple.com/documentation/swiftui/overlayarrangementviewstyle), verified).
  Samsung Flex mode ("View on top, Control on the bottom"), Android tabletop posture and Microsoft's
  laptop posture are the same idea (secondary).
- **Lab.** Partly 06 Media (`ArrangementView` split). Backlog **B2 Laptop pose** (top 5).

### P10. The hinge angle drives effects, not layout
- **Rule.** Use `onHingeChange` / `UIHingeInteraction` for playful or expressive effects (a page curl,
  a lamp, a whammy bar). Use size classes, `ArrangementView` and reserved regions for layout. Always
  handle a nil hinge and an `.unknown` status.
- **Why.** "Hinge data is observed live, and is ideal for driving interactions or effects. For layout,
  use the arrangement and region APIs" ([111464](https://developer.apple.com/videos/play/tech-talks/111464/), verified).
  Google does not even expose an angle: "animations or logic based on the precise hinge angle must be
  tuned to the device" ([fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), secondary).
- **Lab.** 09 Hinge (effects). Backlog **B9 Hinge effect hygiene** adds reduce-motion and smoothing.

### P11. Animate the change of arrangement, not every geometry tick
- **Rule.** Animate discrete changes (split ↔ stack, column count, a panel appearing at the fold) with a
  short spring keyed on that discrete value. Let continuous resizing just lay out. Respect Reduce Motion.
  Never make people wait for a fold animation.
- **Why.** Apple's motion guidance: purposeful, brief, cancellable, optional
  ([HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion), verified). Samsung:
  "A visual transition effect is strongly recommended when the layout changes" for Flex mode (secondary).
  Measured: a fold delivers intermediate geometry (`research/on-device-measurements.md`), so animating
  on raw geometry animates through a wrong frame (our view).
- **Lab.** Not yet. Backlog **B4 Motion on fold** (top 5).

### P12. Feedback stays near its content and goes where the eye goes next
- **Rule.** Prefer inline status. For transient confirmations (a toast), place them inside the safe area,
  in the pane the action came from, never across the fold, never under the trailing rail. Critical
  messages use system alerts.
- **Why.** Apple: "Consider integrating status feedback into your interface" and use alerts for critical,
  actionable information ([HIG Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), verified).
  In book pose alerts move to the trailing side "closer to where they'll appear as the device closes";
  propped on a table the same alert moves to the top region ([111463](https://developer.apple.com/videos/play/tech-talks/111463/), verified).
  Apple has no toast component (verified by absence); Microsoft's foldable snackbar shows on one screen
  only (secondary). Placement rules for toasts are our view, see `03-presentations-and-feedback.md`.
- **Lab.** 08 Presentations (system alerts, menus). Backlog **B5 Toasts and banners** (top 5).

## Things we deliberately don't make principles

- **"Span content across the fold."** Microsoft's "extended canvas" and "two page" patterns assume a
  hard seam between two screens. Apple's fold is a curve on one panel, and Apple's guidance is to *avoid*
  the curve for interactive content, not to design around a seam. We show a two-page reader only as an
  effect (09 Hinge "Book pages"). our view.
- **"Different app on the outer display."** Google allows a focused cover-screen UI for flip phones
  ([Android postures](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation), secondary).
  Apple's outer display is a full iPhone-sized display and Apple says "Don't limit functionality to one
  pose" (verified). Not a principle for Duo.

## Sources

**Apple says** (verified)
- HIG: [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [Motion](https://developer.apple.com/design/human-interface-guidelines/motion), [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- Tech talks: [111461 Prepare](https://developer.apple.com/videos/play/tech-talks/111461/), [111462 Raise the bar](https://developer.apple.com/videos/play/tech-talks/111462/), [111463 Strike a pose](https://developer.apple.com/videos/play/tech-talks/111463/), [111464 Multiple displays and scenes](https://developer.apple.com/videos/play/tech-talks/111464/), [111466 Design](https://developer.apple.com/videos/play/tech-talks/111466/)
- [OverlayArrangementViewStyle](https://developer.apple.com/documentation/swiftui/overlayarrangementviewstyle), [toolbarVerticalBehavior](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:))

**Others do** (secondary)
- Google: [Make your app fold aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), [Postures and orientation](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation), [Canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), [Adaptive quality Tier 3](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3)
- Samsung: [Designing for foldables](https://developer.samsung.com/one-ui/largescreen-and-foldable/designing_for_foldable.html), [Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html)
- Microsoft: [Surface Duo snackbar](https://devblogs.microsoft.com/surface-duo/snackbar-dual-screen/)

**We think** (our view): P11's "don't animate raw geometry" and P12's toast placement rules; the two
non-principles above.
