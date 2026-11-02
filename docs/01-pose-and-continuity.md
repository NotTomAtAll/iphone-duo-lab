# 01 · Poses and continuity: folding mid-task

Researched 2026-11-02. Confidence: **verified** (Apple source or Xcode 27.1 SDK interface),
**secondary** (non-Apple), **our view** (reasoning). No new measurements were taken for this file.

## What we do in DuoLab and why

The existing labs show each pose as a still picture. People don't use the device that way: they read
a list closed, open it to see the detail, prop it on a table for a video, and close it again. Each step
is a live resize of the same scene (verified, [Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).
DuoLab should therefore add one lab where you **start a task, fold, and check what survived**
(backlog B1), and one where the **laptop pose** gets its view-up, controls-down layout (B2). This
doc defines what "survived" means and what is allowed to change.

## 1. The poses, and what the app can actually see

| Pose (Apple's words) | Display | Window / size class | What the app can detect | Confidence |
|---|---|---|---|---|
| Closed | outer | 466×678 pt, compact × regular | size class; hinge `.closed` | verified + measured |
| Closed, landscape ("like a tent") | outer | compact × compact | size class | verified ([111461](https://developer.apple.com/videos/play/tech-talks/111461/)): "a great opportunity to support landscape orientation, as people may want to set the phone down like a tent" |
| Partially folded "like a book" (inner in landscape) | inner | 951×669 pt, regular × regular | active `.division` region, roughly vertical; hinge `.partiallyOpen` + angle | verified; DuoLab measured fold near x≈475 |
| "Seated on a table like a laptop with the inner display facing you" (inner in portrait, half folded) | inner | ≈669×951 pt (portrait), regular × regular | active `.division` region, wide and short (horizontal fold); hinge `.partiallyOpen` | pose verified ([111466](https://developer.apple.com/videos/play/tech-talks/111466/)); window size in portrait **unverified** (we only measured landscape) |
| "Standing on its own, resting on its edges" | either | depends | hinge status/angle | pose verified ([111466](https://developer.apple.com/videos/play/tech-talks/111466/)); which display is active **unverified** |
| Fully open | inner | 951×669 pt, regular × regular | `.division` reported but `isActive == false`; hinge `.fullyOpen` | verified + measured |

Notes that matter for the build team:

- **The hinge API has no axis.** `DeviceHinge` has only `status` and `angle`; `Status` is `.closed`,
  `.partiallyOpen`, `.fullyOpen` (UIKit also has `.unknown`). Verified in the Xcode 27.1
  `SwiftUICore.swiftinterface` and [UIHinge.Status](https://developer.apple.com/documentation/uikit/uihinge/status-swift.enum).
  So "book" vs "laptop" is not a hinge value. You tell them apart by the shape of the active division
  region (`ReservedRegion.frame` taller than wide = book; wider than tall = laptop), or better, you
  don't: `ArrangementView` does it for you (below). our view for the frame test; the region API itself is verified.
- **Android does expose it.** `FoldingFeature.orientation` HORIZONTAL + `HALF_OPENED` = tabletop,
  VERTICAL = book ([fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), secondary).
  Android deliberately does *not* expose the angle; Apple does. Opposite trade-offs.
- **No tabletop gravity signal.** Neither platform tells you the device is actually *on a table*.
  "Laptop" means portrait + half folded; the person may be holding it. Design the bottom half to work
  in the hand too. our view.

## 2. What must not change when the device folds

Apple's rule is one line: "Keep functionality and the state of elements the same between displays"
([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
Apple doesn't list the elements. Google does, as a test ([Tier 3 T-Config_State](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3), secondary),
and Samsung adds the keyboard ([Samsung foldable design](https://developer.samsung.com/one-ui/largescreen-and-foldable/designing_for_foldable.html), secondary).
We adopt the union as DuoLab's continuity checklist:

| Must survive a fold or unfold | Who says so | How it typically breaks in SwiftUI (our view) |
|---|---|---|
| Selected tab and each tab's navigation path | Apple (state), Google | path stored in a view that is rebuilt when an `if sizeClass == .regular` branch flips |
| Selected item in a list/detail | Google canonical list-detail | selection kept in the list view's `@State` instead of above the split view |
| Scroll position | Google, Samsung | view identity changes (`.id(sizeClass)`), or list replaced by grid in another branch |
| Typed text in fields, and the draft | Google, Samsung | field lives in a branch that is destroyed |
| Keyboard focus / keyboard still up | Google ("keyboard state is restored"), Samsung ("keyboard remaining open") | `@FocusState` lost on rebuild. Whether iOS keeps the keyboard up across a fold is **unverified** |
| Media playback position and play state | Google | player owned by a view instead of a model |
| A presented sheet / popover | our view (Apple says sheets "adapt to all poses", [111461](https://developer.apple.com/videos/play/tech-talks/111461/)) | presentation flag in a destroyed branch dismisses it |
| Undo stack, in-progress gesture result | our view | |

The fix is the same in every row: **hoist state above the size-class branch and keep view identity
stable**. `CHECKLIST.md` §6 already says this; B1 makes it visible.

## 3. What should change, and how much

| Changes | Apple's guidance | Verdict for DuoLab |
|---|---|---|
| Split ↔ stack (one more hierarchy level open) | "show an additional level of hierarchy on the larger inner display" (verified) | Recommended. Already lab 03. |
| Column count of grids | "prefer an even number of columns so content divides cleanly" when folded (verified) | Recommended. Already lab 04. |
| Bars horizontal ↔ vertical | system decides; inner portrait keeps horizontal bars (verified, [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)) | System. Don't fight it. |
| Element nudged off the fold | "Move only what's necessary" (verified) | Recommended, lab 07. |
| A whole new layout for laptop pose | optional; "just be sure it has all the same controls and general hierarchy" (verified, [111466](https://developer.apple.com/videos/play/tech-talks/111466/)) | Consider. Backlog B2. |
| Hiding features in one pose | "Don't limit functionality to one pose" (verified) | Avoid. |
| Re-ordering controls between poses | "keep controls' relative positions as similar as possible" (verified) | Avoid. |

Samsung adds a useful limiter: "Not all the screens need to be adjusted for half-folded screen (e.g.
lists of settings)" ([Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html), secondary).
We agree: a settings list gets nothing special in laptop pose.

## 4. Laptop / tabletop pose: view on top, controls on the bottom

Everyone converges on the same layout:

| Source | What they say | Confidence |
|---|---|---|
| Apple tech talk 111466 | "Media can sit at the top, while tappable controls live on a stable base at the bottom." Also: "When the device is partially folded [in portrait], interactive elements move to the bottom half of the display, making them easier to reach while keeping the device stable on the surface." | verified |
| Apple tech talk 111463 | "The top region works well for content that benefits from visibility at a distance… The bottom region works well for interactive controls." An alert moves to the top region in this pose. | verified |
| Apple `OverlayArrangementViewStyle` | Folded in portrait: "secondary view in the top position and the primary view in the bottom position." Doc example puts `PlayerControls()` as primary and `VideoPlayer()` as secondary. | verified ([doc](https://developer.apple.com/documentation/swiftui/overlayarrangementviewstyle)) |
| Samsung Flex mode | "View on top, Control on the bottom"; keep camera preview ratio; "visual transition effect is strongly recommended"; some buttons may stay on top | secondary ([Samsung](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html)) |
| Samsung Flex mode panel | For apps that don't adapt, the system adds its own bottom-half panel (touchpad, brightness, volume, screenshot); apps with their own Flex layout bypass it | secondary ([Samsung support](https://www.samsung.com/ae/support/mobile-devices/how-many-apps-support-flex-mode-on-the-galaxy-z-fold-6/)) |
| Google | tabletop is "great for watching media, taking photos, and making video calls"; quality test: "media controllers move to the horizontal screen area in tabletop posture" | secondary ([fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), [Foldables quality](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/experiences/foldables)) |
| Microsoft Surface Duo | lists a "laptop posture"; "one screen may act as a keyboard" | secondary ([Surface Duo modes](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/postures)) |
| Reviews of iPhone Duo | Netflix ships a half-fold mode with video on top and controls below; the system keyboard sits in the bottom half when the phone is on a desk | secondary ([MacRumors](https://www.macrumors.com/2026/10/26/iphone-duo-is-apples-tiniest-laptop/), [appshunter](https://appshunter.io/blog/best-iphone-duo-apps)) |

**How to build it on iOS 27.1** (verified APIs, our wording):
- Wrap the screen's content in `ArrangementView { controls } secondary: { media }` with
  `.arrangementViewStyle(.overlay)`. Flat or closed: controls float over the media. Book pose:
  side by side (secondary leading, primary trailing). Laptop pose: media top, controls bottom.
- Read `@Environment(\.overlayArrangementZIndex)` in the controls to switch between a compact
  overlay version and an expanded "control deck" version ([doc](https://developer.apple.com/documentation/swiftui/environmentvalues/overlayarrangementzindex)).
  Apple's own demo does exactly this for an Up Next list ([111463](https://developer.apple.com/videos/play/tech-talks/111463/)).
- Use `.overlayArrangementEdge(...)` to flip which side the primary lands on in book pose.
- Keep the arrangement *inside* navigation, not around it, and never inside a `List` or `ScrollView`
  (verified, [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)).

**What goes in the bottom half** (our view, consistent with all sources): the controls people touch
while the device sits still: transport controls, a scrubber, camera shutter and mode, a keyboard or
composer, and the alert's buttons. What stays on top: the thing being watched, the camera preview,
the other person in a call, a large clock or timer. A list of related items can go in the bottom half
only if it is scrollable; it is "controls" in the sense that you touch it.

## 5. Book pose

- The fold divides the inner display "into multiple usable regions" ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).
  Split views move to an even 50/50 around it automatically ([111463](https://developer.apple.com/videos/play/tech-talks/111463/), verified).
- Alerts move to the **trailing** side "closer to where they'll appear as the device closes" (verified, 111463).
  That one sentence is Apple's whole continuity philosophy: anticipate the next pose.
- Google and Microsoft make book posture the reading pose (two-page layout) ([fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), [Surface Duo walkthrough](https://devblogs.microsoft.com/surface-duo/dual-screen-app-design-walkthrough), secondary).
  Apple says continuous scrolling content doesn't displace (verified). Our view: a two-page spread is
  fine for paged content (books, comics, slides); a scrolling article should simply scroll across.

## 6. Closing the device mid-task

- The app keeps running and moves to the outer display; it doesn't relaunch (verified, [Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)).
- Samsung lets the *user* choose what happens on close: "Always", "Swipe to continue", "Never"
  ([SamMobile](https://www.sammobile.com/news/control-how-apps-behave-when-you-fold-your-samsung-galaxy-z-fold-8/), secondary).
  We found no Apple equivalent; whether iOS ever gates continuation on close is **unverified**. Design
  as if the app always continues.
- What collapses: list+detail → detail if one is selected (Google's rule, [canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), secondary).
  SwiftUI's `NavigationSplitView(preferredCompactColumn:)` lets you choose ([doc](https://developer.apple.com/documentation/swiftui/navigationsplitview/init(preferredcompactcolumn:sidebar:detail:)), verified API).
  Our view: show the detail if the person was looking at it; show the list if nothing was selected.
- A popover on the inner display becomes a sheet in compact width by default; control it with
  `presentationCompactAdaptation(_:)` ([doc](https://developer.apple.com/documentation/swiftui/view/presentationcompactadaptation(_:)), verified API).
  What happens to an *already open* popover when you close the device is **unverified**: lab B1 should show it.
- New windows cannot be created on the outer display; handle errors when requesting scenes
  (verified, [111464](https://developer.apple.com/videos/play/tech-talks/111464/)).

## 7. Letterbox and compatibility (what *not* to demo as good)

- Old-SDK apps keep "a familiar size and aspect ratio" when open; 27 SDK avoids the status bar;
  27.1 SDK is edge to edge (verified, see `research/apple-foldable-facts.md` 2j).
- `UIRequiresFullScreen` makes the app **scale** on the inner display, it still resizes on open/close
  (verified, [111461](https://developer.apple.com/videos/play/tech-talks/111461/)).
- Google's Tier 3 bar: "App is not letterboxed; it does not run in compatibility mode"; Samsung:
  "fills the entire screen without letterboxing" (secondary). Apple's only letterbox rule is for games:
  "Prefer changing the aspect ratio over letterboxing… add artwork to the padding area" (verified).
- DuoLab should keep "Clamp to a phone column" as an Avoid in lab 10, and could add a "Scaled
  compatibility" Avoid preview (backlog B12, low priority).

## Sources

**Apple says** (verified)
- [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo); [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- Tech talks [111461](https://developer.apple.com/videos/play/tech-talks/111461/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/)
- [ArrangementView](https://developer.apple.com/documentation/swiftui/arrangementview), [OverlayArrangementViewStyle](https://developer.apple.com/documentation/swiftui/overlayarrangementviewstyle), [overlayArrangementZIndex](https://developer.apple.com/documentation/swiftui/environmentvalues/overlayarrangementzindex), [UIArrangementViewController](https://developer.apple.com/documentation/uikit/uiarrangementviewcontroller), [UIHingeInteraction](https://developer.apple.com/documentation/uikit/uihingeinteraction), [UIHinge.Status](https://developer.apple.com/documentation/uikit/uihinge/status-swift.enum), [ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion)
- Xcode 27.1 SDK: `onHingeChange(isEnabled:_:)` takes `(DeviceHingeContext, DeviceHingeContext)`; `DeviceHinge { status, angle }`.

**Others do** (secondary)
- Google: [fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware), [canonical layouts](https://developer.android.com/develop/ui/compose/layouts/adaptive/canonical-layouts), [Tier 3](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3), [Foldables quality](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/experiences/foldables), [Pixel Fold guide](https://android-developers.googleblog.com/2023/06/pixel-fold-and-pixel-tablet-developers-guide.html)
- Samsung: [Designing for foldables](https://developer.samsung.com/one-ui/largescreen-and-foldable/designing_for_foldable.html), [Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html), [Flex panel support](https://www.samsung.com/ae/support/mobile-devices/how-many-apps-support-flex-mode-on-the-galaxy-z-fold-6/), [continuity setting](https://www.sammobile.com/news/control-how-apps-behave-when-you-fold-your-samsung-galaxy-z-fold-8/)
- Microsoft: [Surface Duo device modes](https://learn.microsoft.com/en-us/previous-versions/dual-screen/design/postures), [design walkthrough](https://devblogs.microsoft.com/surface-duo/dual-screen-app-design-walkthrough)
- iPhone Duo coverage: [MacRumors](https://www.macrumors.com/2026/10/26/iphone-duo-is-apples-tiniest-laptop/), [appshunter](https://appshunter.io/blog/best-iphone-duo-apps)

**We think** (our view): the division-frame test for book vs laptop; the continuity table's failure
modes; detail-wins-on-close; settings lists get no laptop layout; "design the bottom half for the hand too".
