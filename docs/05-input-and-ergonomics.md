# 05 · Input and ergonomics: reach, keyboard, drag, pointer, camera

Researched 2026-11-02. Confidence: **verified** / **secondary** / **our view**, as in `00-principles.md`.
No hands-on device testing was done; reach claims are reasoning, not measurement.

## What we do in DuoLab and why

The 951 pt inner display is held with two hands, propped on a table, or folded like a book. Each
grip puts a different part of the screen under the thumbs, and the keyboard moves (and splits)
with the pose. DuoLab can't measure hands, but it can **overlay reach zones per pose** (backlog B13),
**show where a composer sits when the keyboard is up in each pose** (B14), and **lay out a camera
screen for every pose with a placeholder preview** (B15; the simulator has no camera). These are
lower priority than continuity and laptop pose, but they are where Duo apps feel wrong in the hand.

## 1. Reach

**What Apple says** (verified)
- Outer display: controls "move to the right side of the display in order to maximize vertical space
  and to make them easier to reach with your right thumb" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/)).
- Inner display: "Controls move to the side there as well, maximizing vertical space for your content
  and keeping them within easy reach" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/)).
- Book pose: interactive elements move to the sides "where they're easier to target"; laptop pose:
  "interactive elements move to the bottom half… easier to reach while keeping the device stable"
  ([111466](https://developer.apple.com/videos/play/tech-talks/111466/)).
- Vertical bars are hardware-aligned and "stay on the same side in right-to-left languages"
  ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)).
  There is no left-handed mirror.
- Touch targets: the standard 44×44 pt; no Duo-specific size (see `research/apple-foldable-facts.md` 6b).
  Google's equivalent is 48 dp ([Tier 2 Touch_Targets](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), secondary).

**Reach map per pose** (our view; general grip research such as
[Hoober 2013, UXmatters](https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php)
is about slab phones and is secondary context only)

| Pose / grip | Easy | Hard | Implication |
|---|---|---|---|
| Closed, one hand (right) | right edge (the rail), lower-middle | top-left corner | the system bar is already in the easy zone; keep a screen's primary in-content action low or let it live in the bar |
| Open flat, two hands, landscape | left and right lower thirds | top centre, the middle band | trailing rail is reachable by the right thumb; **nothing system sits under the left thumb**, so a leading-pane action belongs low on the leading side (Mail keeps list controls above the leading pane, verified HIG) |
| Book pose, two hands | the outer edges of each half | the fold and the top centre | same as above plus: never put targets in the curve (P5) |
| Laptop pose, on a table | the bottom half, everywhere | the top half (it tilts back and wobbles: "the top half can wobble while typing", secondary [tapsmart via search](https://www.tapsmart.com/tips-and-tricks/iphone-duo-half-fold/)) | controls down, view up (P9) |
| Open portrait, one hand | lower third | the top | horizontal bars return here (verified); treat like a big phone |

## 2. Keyboard

| Fact | Confidence | Source |
|---|---|---|
| Accessory bars "should remain attached to keyboard rather than moving to the vertical axis" | verified | [111462](https://developer.apple.com/videos/play/tech-talks/111462/) |
| Bars may overflow "as other competing UI appears, like the keyboard" | verified | [111462](https://developer.apple.com/videos/play/tech-talks/111462/) |
| Search field rides over the keyboard, and adapts width/position to "remain over the view it's searching" when folded | verified | [111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| Inner display in landscape, held partly folded: the keyboard **splits** under both thumbs; flat again, it rejoins | secondary | [9to5Mac](https://9to5mac.com/2026/09/18/iphone-duo-videos-reveal-split-keyboard-app-multitasking-more/), [iDevice](https://idevice.com/the-iphone-duo-splits-its-keyboard-under-both-thumbs) |
| On a desk in laptop pose, the keyboard occupies the **bottom half**, text above | secondary | [MacRumors](https://www.macrumors.com/2026/10/26/iphone-duo-is-apples-tiniest-laptop/) |
| A Bluetooth keyboard works and hides the on-screen keyboard | secondary | [iThinkDiff](https://www.ithinkdiff.com/iphone-duo-tablet-mode-keyboard-mouse/) |
| Whether a split Duo keyboard reports as "undocked" to `UIKeyboardLayoutGuide.followsUndockedKeyboard` | **unverified** | [UIKeyboardLayoutGuide](https://developer.apple.com/documentation/uikit/uikeyboardlayoutguide) exists |
| Whether the keyboard stays up across a fold | **unverified** (Google and Samsung require it) | [Tier 3](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3), [Samsung](https://developer.samsung.com/one-ui/largescreen-and-foldable/designing_for_foldable.html) |

What we recommend (our view):
- **Use the keyboard safe area, not a guessed height.** SwiftUI does this by default; in UIKit pin to
  `view.keyboardLayoutGuide`. A split keyboard leaves the centre uncovered; don't add a full-width
  bottom inset when only the corners are covered.
- **Composer placement in laptop pose:** if the keyboard owns the bottom half, a composer pinned above
  the keyboard lands right at the fold. Capture this (B14) before deciding; if it sits in the curve,
  give it a margin from the division region.
- **Don't fight the split keyboard** with custom input views that assume a full-width keyboard.
- **External keyboard:** the inner display is regular × regular, so iPad-style keyboard shortcuts
  (`.keyboardShortcut`) make sense; Google requires Tab/arrow navigation, Enter-to-send and Esc-to-close
  for large screens ([Tier 2 keyboard](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), secondary).
  Apple has no Duo-specific rule. Low priority for DuoLab.

## 3. Drag and drop between halves

- In-app drag: `draggable` / `dropDestination`; WWDC26 adds reorderable containers that work with any
  container, not only `List` ([WWDC26 269](https://developer.apple.com/videos/play/wwdc2026/269/),
  [draggable](https://developer.apple.com/documentation/swiftui/view/draggable(_:)), verified).
- Between apps: Duo has Split View multitasking with a 50/50 split (verified, [111466](https://developer.apple.com/videos/play/tech-talks/111466/)).
  Cross-app drag between the two halves is not described by Apple for Duo (**unverified**); iPad
  behaviour suggests it works with standard item providers.
- Others: Google lists drag and drop as a Tier 1 differentiator ([adaptive quality](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality), secondary);
  Microsoft built Surface Duo patterns around dragging between screens (secondary).
- Our view: a drag *through* the fold is fine (it's continuous movement, like scrolling); a **drop
  target in the fold** is not. Highlight the target pane, not a strip at the seam. DuoLab could show
  this in the list/detail lab as "drag a row into the detail" (B10, optional).

## 4. Pointer and hover

- iOS shows no pointer on Duo by default; a mouse needs AssistiveTouch, then the cursor "works like an
  iPad cursor" with rough edges ([iThinkDiff, Oct 22 2026](https://www.ithinkdiff.com/iphone-duo-tablet-mode-keyboard-mouse/), secondary).
- `hoverEffect(_:isEnabled:)` exists and is cheap to add ([doc](https://developer.apple.com/documentation/swiftui/view/hovereffect(_:isenabled:)), verified API).
- Google requires hover states for actionable elements on large screens (secondary).
- Verdict: **not a DuoLab lab.** Note it in the checklist; standard controls already handle it.

## 5. Camera and the selfie preview

| Fact | Confidence | Source |
|---|---|---|
| Two front cameras (outer ultrawide, inner under-display); `Virtual Front Camera` switches between them automatically on open/close, limited to 1080p/60 fps and no depth | verified | [111465](https://developer.apple.com/videos/play/tech-talks/111465/) |
| Individual cameras + `AVCaptureDeviceDirectionCoordinator` tell you which camera faces the user as the device opens, closes or flips | verified | [111465](https://developer.apple.com/videos/play/tech-talks/111465/), [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces) |
| Mirror the preview when the rear camera is forward-facing (rear-camera selfie) | verified | [111465](https://developer.apple.com/videos/play/tech-talks/111465/) |
| Inner camera is an **occlusion** reserved region, active only while the camera is active; "If its viewfinder is central to your experience, keep important content and controls clear of that area" | verified | [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) |
| Rear camera on the inner display leaves space around the preview: offset the preview and group controls in the remaining space, or fill | verified | [111465](https://developer.apple.com/videos/play/tech-talks/111465/) |
| `CameraCaptureAccessory` shows extra UI on the outer display while the app is full screen on the inner display with an active camera session (teleprompter, a face for a child) | verified | [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) |
| Tabletop camera: viewfinder top, controls bottom | secondary | [Android camera codelab](https://developer.android.com/codelabs/android-camera-foldables#5) via [fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware) |
| Keep camera preview ratio and shape between normal and half-folded | secondary | [Samsung Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html) |
| Camera preview must be correct folded, unfolded, rotated, and on front and back screens | secondary | [Google Foldables_Camera](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/experiences/foldables) |

What a half-open camera screen should do (our view, consistent with all of the above):
- **Laptop pose**: preview in the top half at its native ratio, shutter/mode/zoom in the bottom half.
  That's `ArrangementView(.overlay)` with controls as primary and preview as secondary.
- **Book pose**: preview on one side, controls on the trailing side (toward the rail), so the right
  thumb shoots.
- **Never let the shutter sit in the inner camera's occlusion region** while that camera is active.
- DuoLab can demo the layout with a gradient placeholder; the simulator has no camera, so the camera
  APIs themselves stay in BuildNotes only.

## Sources

**Apple says** (verified)
- [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo); [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- Tech talks [111462](https://developer.apple.com/videos/play/tech-talks/111462/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111464](https://developer.apple.com/videos/play/tech-talks/111464/), [111465](https://developer.apple.com/videos/play/tech-talks/111465/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/); [WWDC26 269 What's new in SwiftUI](https://developer.apple.com/videos/play/wwdc2026/269/)
- [Choosing a camera by the direction it faces](https://developer.apple.com/documentation/avkit/choosing-a-camera-by-the-direction-it-faces), [UIKeyboardLayoutGuide](https://developer.apple.com/documentation/uikit/uikeyboardlayoutguide), [draggable](https://developer.apple.com/documentation/swiftui/view/draggable(_:)), [hoverEffect](https://developer.apple.com/documentation/swiftui/view/hovereffect(_:isenabled:))

**Others do** (secondary)
- Google: [Tier 2](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), [Tier 3](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-3), [Foldables quality](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/experiences/foldables), [fold-aware](https://developer.android.com/develop/ui/compose/layouts/adaptive/foldables/make-your-app-fold-aware)
- Samsung: [Flex mode](https://developer.samsung.com/one-ui/foldable-and-largescreen/foldable-excl-flex.html), [Designing for foldables](https://developer.samsung.com/one-ui/largescreen-and-foldable/designing_for_foldable.html)
- iPhone Duo coverage: [9to5Mac](https://9to5mac.com/2026/09/18/iphone-duo-videos-reveal-split-keyboard-app-multitasking-more/), [iDevice](https://idevice.com/the-iphone-duo-splits-its-keyboard-under-both-thumbs), [MacRumors](https://www.macrumors.com/2026/10/26/iphone-duo-is-apples-tiniest-laptop/), [iThinkDiff](https://www.ithinkdiff.com/iphone-duo-tablet-mode-keyboard-mouse/), [TapSmart](https://www.tapsmart.com/tips-and-tricks/iphone-duo-half-fold/)
- [Hoober, How do users really hold mobile devices (UXmatters, 2013)](https://www.uxmatters.com/mt/archives/2013/02/how-do-users-really-hold-mobile-devices.php)

**We think** (our view): the reach map; composer-at-the-fold risk; drop targets not in the fold;
pointer is not a lab; half-open camera layout.
