# On-device measurements (iPhone Duo simulator, Xcode 27.1 / iOS 27.1)

Measured by logging `UIWindowScene` geometry and the key window's trait collection from the scene delegate
(`sceneDidBecomeActive` and `windowScene(_:didUpdateEffectiveGeometry:)`) of a **portrait-only, iPhone-only**
app (`UISupportedInterfaceOrientations = Portrait`, `TARGETED_DEVICE_FAMILY = 1`, no `UIRequiresFullScreen`).

| Posture | Screen bounds (pt) | Window bounds (pt) | Size class (h × v) | Idiom | Interface orientation | Safe-area insets (T / L / B / R) |
|---|---|---|---|---|---|---|
| Closed (outer display) | 466 × 678 | 466 × 678 | **compact × regular** | phone | portrait (1) | 0 / 0 / 34 / **84** |
| Book ≈90° (inner) | 951 × 669 | 951 × 669 | **regular × regular** | phone | landscapeRight (4) | 0 / 0 / 34 / **84** |
| Open ≈180° (inner) | 951 × 669 | 951 × 669 | **regular × regular** | phone | landscapeRight (4) | 0 / 0 / 34 / **84** |

Transitions (fold/unfold while the app runs) deliver `didUpdateEffectiveGeometry` with intermediate values
(e.g. screen 669 × 951 with a 82 pt top inset for one update) before settling on the table above; a scene
reconnect can also deliver a zero-sized window before `didBecomeActive`. Treat geometry as **dynamic**: never
cache it at launch.

## What this means

1. **The inner display is a regular-width, regular-height environment on the phone idiom.** The system
   does not letterbox a portrait-only app; it hands it a landscape-shaped window and reports
   `horizontalSizeClass == .regular`. Every size-class-adaptive API (`NavigationSplitView`, the native
   `TabView` with `.sidebarAdaptable`, adaptive grids) will switch to its wide layout here. An app that
   never branches on size classes will simply stretch.
2. **The orientation lock is not honoured on the inner display**: the interface orientation is
   landscapeRight even though only portrait is declared. Rotation requests have no effect.
3. **The system rail is a plain safe-area inset.** Both displays report a right inset of 84 pt and a bottom
   inset of 34 pt. Anything that ignores the trailing safe area (or caches insets at launch) will render
   under the status cluster / sensor pill. Respecting safe areas is the whole fix for the rail.
4. The status bar area contributes **no top inset** on either display (the clock lives in the rail), so
   layouts that hard-code a "status bar height" are wrong here.

## Closed posture: who actually renders under the rail?

Re-analysed the accessibility frames of 24 closed-posture captures against the measured rail
(`x ≥ 466 − 84 = 382`). The default SwiftUI layout **does** respect the 84 pt trailing inset: headers,
tab bar, list rows and their chevrons all stop at x ≈ 382. Only three kinds of view put *actionable*
controls under the rail:

| Kind | Example | Why |
|---|---|---|
| Horizontally scrolling carousels | live-card rail on Home / category, a card's bookmark button | the carousel content runs edge to edge; cards partly under the rail are still tappable |
| Full-screen surfaces that opt out of safe areas | a full-screen video player's top-right controls (close, more, share) | the hosting controller disables safe areas to draw video edge to edge |
| UIKit-presented sheets | "Create listing" sheet close button and full-width Continue button | the sheet's content does not inherit the window's trailing inset |

Everything else under the rail is passive (scroll indicators, toolbar wrappers). So on the outer display the
job is not "add an inset everywhere" but: keep carousels' *tappable* cards clear of the rail (or accept
partial overlap but keep a hit target), re-add the trailing inset on full-screen surfaces, and inset sheet
content. The earlier "header icons hidden under the clock" reading was wrong: the bell and cart end at
x ≈ 368, inside the safe area.

## Round 2 additions (2026-11-03)

The build rounds added findings beyond the geometry above: bar compression and overflow, the tab bar
accessory and minimize behaviour, two-column split views, hinge API values at launch, rotation of the
open device, state across folds, toast placement, and rendering traps (thumbnails, zoom transition).
They are collected, grouped and labelled measured / likely / unverified in
[`docs/08-findings.md`](../docs/08-findings.md). Two that change how to read this file:

- **Rotation does not give a laptop pose on the simulator.** Rotating the open device changes the
  reported orientation, but the inner window stays 951 × 669 with the same upright fold (x 456, width 40).
  The portrait inner window (laptop pose) is still unmeasured.
- **A GeometryReader inside a pane's overlay reports the window's insets (R84, B34)** even though its
  frame already excludes them. Do not add them twice.
