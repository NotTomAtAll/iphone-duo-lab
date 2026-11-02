# 04 · Motion and animation on a folding display

Researched 2026-11-02. Confidence: **verified** / **secondary** / **our view**, as in `00-principles.md`.
Nothing here was timed or recorded by this research pass.

## What we do in DuoLab and why

Apple animates its own chrome when the device folds (bars change axis, sheets slide off the fold,
Liquid Glass morphs). Apple says almost nothing about how *your* content should animate when the
window resizes under it. That gap is where apps either snap harshly or animate through garbage
frames. DuoLab should add one lab (backlog B4, top 5) that runs the **same layout change four ways**
(no animation, animate everything, animate only the discrete change, reduce motion) so people can
fold the simulator and see the difference. Lab 09 (hinge effects) gets a Reduce Motion switch and
smoothing (B9).

## 1. What Apple ships for motion (verified)

| Thing | What it does | Source |
|---|---|---|
| Liquid Glass morphing between contexts | "As you go between states in an app, Liquid Glass dynamically morphs between the controls in each context… a singular floating plane" | [WWDC25 219 Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/) |
| `GlassEffectContainer` + `glassEffectID(_:in:)` | Custom glass shapes in one container blend and morph; the ID animates shapes "to and from each other during transitions" | [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer), [glassEffectID](https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)), [WWDC25 323](https://developer.apple.com/videos/play/wwdc2025/323/) |
| Sheets morphing out of their button | Make the toolbar item a zoom source and the sheet content the destination | [WWDC25 323](https://developer.apple.com/videos/play/wwdc2025/323/) |
| Zoom navigation transition | Cell morphs into the destination; "continuously interactive… grab and drag it around, from the beginning or during the transition" | [WWDC24 10145](https://developer.apple.com/videos/play/wwdc2024/10145/), [zoom(sourceID:in:)](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)) |
| Vertical bar on/off | "When the value changes, the system animates the transition: content reflows to or from the horizontal bars while the status bar changes axis" | [toolbarVerticalBehavior](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)) |
| Reduce Motion with Liquid Glass | "Reduced Motion decreases the intensity of some effects and disables any elastic properties for the material" (automatic) | [WWDC25 219](https://developer.apple.com/videos/play/wwdc2025/219/) |
| Springs | `.smooth`, `.snappy`, `.bouncy` presets; springs keep velocity when retargeted | [WWDC23 10158 Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/) |
| Wallpaper zoom on open | System wallpaper "reacts to the angle of the hinge and applies a zoom effect" | [111464](https://developer.apple.com/videos/play/tech-talks/111464/) |

HIG Motion, the rules that apply directly ([Motion](https://developer.apple.com/design/human-interface-guidelines/motion), verified):
- "Add motion purposefully… Don't add motion for the sake of adding motion."
- "Make motion optional… avoid using it as the only way to communicate important information."
- "Aim for brevity and precision in feedback animations."
- "In apps, generally avoid adding motion to UI interactions that occur frequently." Opening and
  closing the device *is* frequent ("People may open and close the device frequently", [111466](https://developer.apple.com/videos/play/tech-talks/111466/)).
- "Let people cancel motion… don't make people wait for an animation to complete."

What Apple doesn't say: how app content should animate on the fold resize. **unverified / not documented.**

## 2. What others say about posture transitions

- Samsung: "A visual transition effect is strongly recommended when the layout changes between the
  two modes" (normal ↔ Flex) ([Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html), secondary).
  Also: "The ratio and shape of important items need to be maintained between normal and Flex mode
  (e.g., camera preview)" (secondary).
- Google: no animation rule for postures; advises against precise-angle animations because "sensor
  accuracy can vary from device to device" ([fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), secondary).
  Landscape reflow guidance: "If the content didn't scroll in portrait, don't make it scroll in
  landscape" ([Android postures](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation), secondary).
- Nil Coalescing maps the hinge angle linearly to a 0–1 progress value between 80° and 170° for a
  bloom effect, and says layout should come from reserved regions/arrangements because layout only
  changes when the fold becomes active or inactive, not on every angle change
  ([Nil Coalescing](https://nilcoalescing.com/blog/DrivingSwiftUIAnimationsWithTheHingeAngleOnIPhoneDuo), secondary).

## 3. How to animate a layout change when the window resizes (our view, grounded)

The evidence that shapes this: a fold delivers **intermediate geometry** before it settles (one update
at 669×951 with an 82 pt top inset, and sometimes a zero-size window on reconnect, measured in
`research/on-device-measurements.md`). An implicit animation on raw geometry animates *through* those
frames.

**Rule A. Animate discrete layout modes, not sizes.** Derive a small enum from inputs that only change
at real boundaries: horizontal size class, whether a `.division` region is active, and the
arrangement's z-index or split axis. Attach the animation to that value:

```swift
// our sketch, not Apple sample code
enum LayoutMode: Equatable { case compact, wide, foldedBook, foldedLaptop }
content
    .animation(.smooth(duration: 0.3), value: mode)   // only when the mode flips
```

Avoid a bare `.animation(.default)` with no value, and avoid `withAnimation` inside
`onGeometryChange` for width or height.

**Rule B. Let continuous reflow just lay out.** Grids changing from 3 to 4 columns, text rewrapping,
list rows widening: don't animate. A crossfade (`contentTransition(.opacity)` or a short `.opacity`
transition) is the most you need. Moving 40 cells at once is the "excessive movement" Apple warns about
([111463](https://developer.apple.com/videos/play/tech-talks/111463/), verified quote; applying it to
reflow is our view).

**Rule C. Move displaced elements with matched geometry.** When a single element moves off the fold
(a floating button, a mini player, a panel), give it a stable identity and animate its frame so the
eye can follow it to its new region (`matchedGeometryEffect`, or simply a stable `id` inside an
animated mode change). This is Apple's displacement pattern made visible; Samsung's "visual transition"
rule supports it.

**Rule D. The system's chrome is already animating.** Bars, sheets, alerts, split-view columns:
don't add your own animation to them; you'll double-animate or fight the system timing.

**Rule E. Never block.** No `.disabled(isAnimating)`, no delayed state commit. A fold must be
interruptible by another fold (people open and close quickly). Springs retarget cleanly, which is a
reason to use them over fixed-duration curves ([WWDC23 10158](https://developer.apple.com/videos/play/wwdc2023/10158/), verified).

**Rule F. Keep scroll position still.** Whatever animates, the item at the top of the viewport before
the fold should be at the top after. Use `scrollPosition(id:)` to pin it
([scrollPosition](https://developer.apple.com/documentation/swiftui/view/scrollposition(_:anchor:)), verified API).
Google treats a lost scroll position as a quality failure (secondary, [Tier 3](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3)).

**UIKit equivalent.** Do mode changes in `viewWillTransition(to:with:)` with
`coordinator.animate(alongsideTransition:)` so they ride the system's resize animation; observe
`horizontalSizeClass` via trait registration. Whether the Duo fold drives `viewWillTransition` the same
way rotation does is **unverified**; B4 should log it.

**Presets we'll use** (our view): `.smooth` (no bounce) for layout modes; `.snappy` for a single
element nudged off the fold; no `.bouncy` on layout, bounce on a 951 pt surface reads as wobble.

## 4. Hinge-driven animation

- The hinge already *is* the animation: map angle → progress directly, no `withAnimation`, so the
  effect tracks the hand (our view; consistent with [111464](https://developer.apple.com/videos/play/tech-talks/111464/) "observed live… ideal for driving interactions or effects").
- Smooth noisy input with a short low-pass filter or by quantising to ~1°; Google's warning about
  sensor variance suggests this, and the simulator's reported angle can be stale
  (`practices/simulator-capture.md`). secondary + our view.
- Only animate on **status** changes (`.closed` → `.partiallyOpen` → `.fullyOpen`), e.g. a small
  settle spring when the effect reaches its end state.
- Handle `hinge == nil` (no hinge) and `.unknown` (UIKit) by showing the effect at rest, not hidden
  (verified API, [UIHinge.Status](https://developer.apple.com/documentation/uikit/uihinge/status-swift.enum)).
- Disable the effect when not visible (`onHingeChange(isEnabled:)`) to save work (verified API in the
  Xcode 27.1 SDK interface).

## 5. What not to animate

| Don't animate | Why | Confidence |
|---|---|---|
| Raw width/height on resize | animates through intermediate frames | our view, from measurement |
| Every cell in a reflowing grid | excessive movement; slow; distracting on a frequent action | our view + HIG |
| Bars, sheets, alerts, split columns | system animates them | verified (system behaviour), our view (don't double up) |
| Scroll offset during a fold | loses the reading position | secondary (Google), our view |
| Hinge angle with `withAnimation` | lags behind the hand | our view |
| Anything with bounce on a layout change | wobble on a large surface | our view |
| Toasts sliding across the fold | crosses the curve; reads as a page change | our view, see `03-presentations-and-feedback.md` |

## 6. Reduce Motion

- System glass reduces itself automatically ([WWDC25 219](https://developer.apple.com/videos/play/wwdc2025/219/), verified).
- Your content: read `@Environment(\.accessibilityReduceMotion)` and replace movement with an opacity
  crossfade or an instant change ([accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion), verified API).
- Hinge effects under Reduce Motion: keep the *state* change (lamp on/off) but drop the continuous
  motion (no tilt, no parallax) (our view; HIG "Make motion optional").
- Zoom transitions: the system handles Reduce Motion for navigation transitions; we haven't verified
  what zoom degrades to on iOS 27.1 (**unverified**, add to B4).

## Sources

**Apple says** (verified)
- [HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion); [WWDC25 219 Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/); [WWDC25 323 Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/); [WWDC24 10145 Enhance your UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/); [WWDC23 10158 Animate with springs](https://developer.apple.com/videos/play/wwdc2023/10158/)
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer), [glassEffectID](https://developer.apple.com/documentation/swiftui/view/glasseffectid(_:in:)), [zoom](https://developer.apple.com/documentation/swiftui/navigationtransition/zoom(sourceid:in:)), [toolbarVerticalBehavior](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)), [scrollPosition](https://developer.apple.com/documentation/swiftui/view/scrollposition(_:anchor:)), [contentTransition](https://developer.apple.com/documentation/swiftui/view/contenttransition(_:)), [accessibilityReduceMotion](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion)
- Tech talks [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/)

**Others do** (secondary)
- [Samsung Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html); [Google fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware); [Android postures](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation); [Nil Coalescing hinge animations](https://nilcoalescing.com/blog/DrivingSwiftUIAnimationsWithTheHingeAngleOnIPhoneDuo)

**We think** (our view): rules A–F, the presets, the "don't animate" table, hinge smoothing.
