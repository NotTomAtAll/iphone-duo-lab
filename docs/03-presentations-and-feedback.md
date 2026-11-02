# 03 · Presentations and feedback: sheets, popovers, alerts, menus, toasts, haptics

Researched 2026-11-02. Confidence: **verified** / **secondary** / **our view**, as in `00-principles.md`.

## What we do in DuoLab and why

Lab 08 shows the system presentations as they are (form sheet, page sheet, popover, alert,
confirmation dialog, menu), because Apple moves them for us. What's missing is the *choices* a team
still makes: **sheet placement and sizing on the inner display**, **whether a sheet keeps its vertical
bar**, and above all **toasts and banners**, which Apple doesn't ship and every app builds. Toasts are
where we see the most fold and rail bugs (`CHECKLIST.md` §7). Backlog B5 (toasts, top 5) and B11
(sheet placement) turn this doc into options with verdicts.

## 1. What the system does for you (don't rebuild it)

| Presentation | Outer display | Inner display | Book pose | Source |
|---|---|---|---|---|
| Sheet | toolbar goes vertical by default | centred, horizontal bars | "sheets slide over to avoid resting in the fold" | verified, [111466](https://developer.apple.com/videos/play/tech-talks/111466/), [111461](https://developer.apple.com/videos/play/tech-talks/111461/) |
| Sheet with `presentationPlacement(.leading)` | n/a | leading, horizontal bar | | verified, [Preparing doc](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo) |
| Sheet with `presentationPlacement(.trailing)` | n/a | trailing, **gets a vertical bar** | | verified, same + [111462](https://developer.apple.com/videos/play/tech-talks/111462/) |
| Alert | | | moves to the **trailing** side | verified, [111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| Alert, laptop pose | | | moves to the **top** region | verified, [111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| Context menu / popover / action sheet | | | repositioned around the fold, keeps relationship with its source (Photos: cell and menu move together) | verified, [111463](https://developer.apple.com/videos/play/tech-talks/111463/) |
| Search field | over the keyboard on iPhone | uses extra width | "width and position adapt to remain over the view it's searching" | verified, [111463](https://developer.apple.com/videos/play/tech-talks/111463/) |

`presentationPlacement` is iOS 27.0 and "Only sheet presentations respect this placement"
([PresentationPlacement](https://developer.apple.com/documentation/swiftui/presentationplacement), verified).

## 2. Sheets: the choices left to you

| Choice | Options | Verdict | Why |
|---|---|---|---|
| Placement on the inner display | `.automatic` / `.center` · `.leading` · `.trailing` | **Automatic** by default. **Trailing** for a sheet that edits the detail pane. **Leading** for one that acts on the list. | Apple: "Locate controls near the content they affect" ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified). Mapping to placement is our view. |
| Vertical bar in a sheet on the outer display | default (vertical) · `toolbarVerticalBehavior(.disabled)` | Default. Disable **only** for a sheet whose sole item is Close. | "if a sheet is control-heavy with only one item, like the close button here, consider disabling a vertical bar" ([111462](https://developer.apple.com/videos/play/tech-talks/111462/), verified). With it disabled, "sheets stop just short of the front-facing camera" ([111466](https://developer.apple.com/videos/play/tech-talks/111466/), verified). |
| Sizing | `.form` · `.page` · `.fitted(...)` · `.sticky(...)` via `presentationSizing` | `.form` for input, `.page` for reading; add `.fitted(vertical:)` + `.sticky` for content-length sheets | API since iOS 18 ([presentationSizing](https://developer.apple.com/documentation/swiftui/view/presentationsizing(_:)), verified). HIG: "Present a sheet in a default size that helps people retain their context. Avoid displaying a sheet that covers most or all of its window" ([Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), verified). |
| Detents | `.medium`, `.large`, custom | Custom detents must compute from the sheet's context height, never the screen | already in `CHECKLIST.md` §7; screen height differs by 2× between displays (our view) |
| Sheet over a split view | one sheet for the app · per-pane sheet | per-pane via placement when the task is pane-specific | our view |

Google says the same thing about width from the other side: "Bottom sheets are not full width on large
screens… Small edit menus or modals don't cover the entire screen" ([Tier 2 UI_Secondary_Elements](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), secondary).
For a filter sheet on a wide screen Google suggests a **side sheet** ([Android postures](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation), secondary);
on Duo that is `presentationPlacement(.trailing)` or `.leading` (our mapping).

**Folding with a sheet open** (B1 checks this): the sheet must stay presented, keep its scroll and
input, and re-place itself. Apple says sheets "adapt to all poses" (verified, [111461](https://developer.apple.com/videos/play/tech-talks/111461/)).
Whether a custom detent re-resolves on fold is **unverified**.

## 3. Popovers, menus, alerts

- **Popovers belong in regular width only.** "Avoid displaying popovers in compact views… use a sheet
  instead" ([HIG Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers), verified).
  SwiftUI adapts automatically; `presentationCompactAdaptation(_:)` lets you choose the compact form
  ([doc](https://developer.apple.com/documentation/swiftui/view/presentationcompactadaptation(_:)), verified).
  So the same button shows a popover open and a sheet closed. That is correct, not inconsistent.
- **Every popover needs an anchor** (`CHECKLIST.md` §7). In UIKit an unanchored popover crashes in
  regular width; this matters newly on iPhone because the inner display is regular (our view, standard UIKit behaviour).
- **Animate popover size changes** "to avoid giving the impression that a new popover replaced the old
  one" ([HIG Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers), verified).
- **Alerts for critical, actionable information only** ([HIG Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), verified).
  Don't use an alert as a toast. On Duo the alert also *moves with the pose*, which a custom alert won't.
- **Menus**: use the system overflow menu on vertical bars; "Reserve the ellipsis symbol for overflow,
  and give other menus a distinct symbol" ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), verified).

## 4. Toasts and banners (Apple has none)

### What exists
| Source | Rule | Confidence |
|---|---|---|
| Apple HIG Feedback | Prefer status integrated into the interface, near the items it describes (Mail's toolbar status); alerts for critical info; confirm only significant completions | verified, [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback) |
| Apple | No toast/snackbar component in SwiftUI or UIKit | verified by absence (none in HIG component list or SDK) |
| Material snackbar | bottom, centred by default; may sit on the **leading edge** on large screens; widens on medium/large; appears **above** FABs | secondary, [material.io snackbars](https://material.io/components/snackbars) |
| Microsoft Surface Duo | snackbar shows on **one** screen only, never under the hinge; `SnackbarContainer` targets first, second or both screens "where the user is currently focused" | secondary, [Fluent dual-screen](https://devblogs.microsoft.com/surface-duo/fluent-ui-android-dual-screen), [snackbar post](https://devblogs.microsoft.com/surface-duo/snackbar-dual-screen/) |
| Microsoft Flutter | spanned dialogs default to the first (left) screen; `anchorPoint` moves them | secondary, [hinge-aware popups](https://learn.microsoft.com/en-us/dual-screen/flutter/hinge-aware-popup-routes) |
| GNOME HIG | toasts towards the bottom, horizontally centred | secondary, [GNOME toasts](https://developer.gnome.org/hig/patterns/feedback/toasts.html) |
| iOS community | bottom for "done" confirmations, top for notification-like status; libraries offer both | secondary, e.g. [AlertToast](https://github.com/elai950/AlertToast) |

### Our recommendation for DuoLab (our view, built from the rows above)

1. **Prefer inline.** If the result is visible (a row appears, a badge changes), don't toast at all.
2. **Bottom pill for transient confirmations** ("Saved", "Copied", "Undo"), **top banner only for
   persistent state** ("Offline"), and the persistent banner goes in a `safeAreaInset`/`safeAreaBar`
   so it *pushes* content instead of covering it ([safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)), verified API).
   A top toast on Duo also competes with system notification banners. On the outer display the clock
   lives in the rail, so the top edge is free, which is tempting, but don't.
3. **Centre on the content area, not the window.** On both displays the window has an 84 pt trailing
   rail; centring on the window puts the pill 42 pt off-centre and can tuck its edge under the rail.
   Size from the live safe area at show time (already `CHECKLIST.md` §7).
4. **Inner display, flat: in the pane the action came from.** A list action toasts over the list, a
   detail action over the detail. Same reason Apple keeps controls "near the content they affect".
   Cap the width (≈ 360 pt) so it doesn't stretch across 867 pt.
5. **Book pose: never across the fold.** Constrain to one side of the active division. For global
   messages pick the **trailing** side, mirroring where Apple sends alerts (verified behaviour, applied
   to toasts by us).
6. **Laptop pose: top region, near its bottom edge, clear of the fold.** Apple sends alerts to the top
   region because it's visible at a distance (verified); the bottom region is busy with controls and
   the keyboard. A fold margin of the region's own `margins` keeps it out of the curve.
7. **Keyboard up: above the keyboard** (use the keyboard safe area; `UIKeyboardLayoutGuide` in UIKit,
   [doc](https://developer.apple.com/documentation/uikit/uikeyboardlayoutguide), verified API).
8. **Re-place on fold.** If a toast is on screen when the pose changes, move it with the same short
   animation as the layout (see `04-motion-and-animation.md`) or simply dismiss it. Never leave it
   hanging where the old layout had it.
9. **Accessibility**: post a VoiceOver announcement, keep it ≥ 4 s or until tapped, and never make the
   toast the only way to undo (Material allows one action; we'd still mirror Undo elsewhere). HIG:
   "Make sure all feedback is accessible" (verified, [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback)).

## 5. Haptics on pose change

- Apple documents **no haptic for folding** and no haptic guidance for Duo (verified by absence in the
  HIG Duo page and all six tech talks).
- HIG haptics: "build a clear, causal relationship between each haptic and the action that causes it…
  If a haptic doesn't reinforce a cause-and-effect relationship, it can be confusing and seem
  gratuitous"; "Use system-provided haptic patterns according to their documented meanings"
  ([Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics), verified).
- Our view: **don't** play a haptic when the layout changes on fold. The person already feels the
  hinge, and a buzz on every open/close is noise. **Do** consider a light `.selection` or `.impact`
  (`sensoryFeedback(_:trigger:)`, [doc](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)), verified API)
  when a **hinge-driven effect** crosses a meaningful threshold the user is aiming for (a lamp
  switching on at 90°, a page landing), once per crossing, with hysteresis so it doesn't chatter.
  Samsung and Google say nothing about haptics on posture (verified by absence in the pages we read).

## Sources

**Apple says** (verified)
- [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [Sheets](https://developer.apple.com/design/human-interface-guidelines/sheets), [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers), [Alerts](https://developer.apple.com/design/human-interface-guidelines/alerts), [Feedback](https://developer.apple.com/design/human-interface-guidelines/feedback), [Playing haptics](https://developer.apple.com/design/human-interface-guidelines/playing-haptics)
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo); tech talks [111461](https://developer.apple.com/videos/play/tech-talks/111461/), [111462](https://developer.apple.com/videos/play/tech-talks/111462/), [111463](https://developer.apple.com/videos/play/tech-talks/111463/), [111466](https://developer.apple.com/videos/play/tech-talks/111466/)
- [presentationPlacement](https://developer.apple.com/documentation/swiftui/view/presentationplacement(_:)), [presentationSizing](https://developer.apple.com/documentation/swiftui/view/presentationsizing(_:)), [presentationCompactAdaptation](https://developer.apple.com/documentation/swiftui/view/presentationcompactadaptation(_:)), [toolbarVerticalBehavior](https://developer.apple.com/documentation/swiftui/view/toolbarverticalbehavior(_:)), [safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)), [sensoryFeedback](https://developer.apple.com/documentation/swiftui/view/sensoryfeedback(_:trigger:)), [UIKeyboardLayoutGuide](https://developer.apple.com/documentation/uikit/uikeyboardlayoutguide)

**Others do** (secondary)
- Google: [Tier 2](https://developer.android.com/docs/quality-guidelines/adaptive-app-quality/tier-2), [Postures and orientation](https://developer.android.com/design/ui/mobile/guides/layout-and-content/postures-and-orientation); [Material snackbars](https://material.io/components/snackbars)
- Microsoft: [Fluent UI dual-screen controls](https://devblogs.microsoft.com/surface-duo/fluent-ui-android-dual-screen), [Snackbar for dual-screen](https://devblogs.microsoft.com/surface-duo/snackbar-dual-screen/), [Flutter hinge-aware popups](https://learn.microsoft.com/en-us/dual-screen/flutter/hinge-aware-popup-routes)
- [GNOME HIG toasts](https://developer.gnome.org/hig/patterns/feedback/toasts.html), [AlertToast](https://github.com/elai950/AlertToast)

**We think** (our view): sheet placement mapping to panes; the nine toast rules; no haptic on fold,
optional haptic on hinge-effect thresholds.
