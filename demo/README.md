# DuoLab: pick your iPhone Duo layout practices

DuoLab is a standalone SwiftUI app with no product code in it. It covers the **ten layout decisions** every app makes on the iPhone Duo. Each decision comes with a few curated **options**, and each option is a real approach with a verdict (Recommended, Consider, Avoid), its strengths and costs, and what to try on the device. You try the options live, choose one per topic, and share the result with the team as a **playbook**. Original spec: `docs/2026-11-02-duolab-design.md`; v2 redesign: `docs/2026-11-02-duolab-v2.md`.

## Run it

- Open `DuoLab/DuoLab.xcodeproj` in Xcode 27.1 and run the `DuoLab` scheme on an **iPhone Duo** simulator. The deployment target is iOS 27.1.
- It is a plain Xcode project with file-system synced folders. A new `.swift` file in `DuoLab/DuoLab/` joins the target automatically.
- Tests: `xcodebuild -project DuoLab/DuoLab.xcodeproj -scheme DuoLab -destination 'platform=iOS Simulator,name=iPhone Duo 2' test` (19 Swift Testing tests, including catalog checks: every option's settings are valid and distinct, and every design topic has a Recommended option).

## How it works

| Screen | What it does |
|---|---|
| Explore | One scrolling gallery. Each topic is a title, a plain question and a row of option cards you swipe sideways. **Open / Folded** in the toolbar switches every picture between the two displays. Long-press a card for **Use this**. |
| Option preview | Tap a card and it zooms open into the live option. The glass controls at the bottom: close, ‹ option ›, **i** (what it is, what to try, good / watch out, Apple's suggestion, and "How it's built" with the technical names), and **Use this**. |
| Playbook | Your choices, one per topic. Tap one to add a reason, try it again or remove it. **Share** sends the list as text with links back to each option. |
| Device | Window size, safe area, hinge angle and the fold, live. |

The thumbnails are rendered in hidden windows behind the app, in light and dark mode, and cached on disk: the first launch fills them in within a few seconds, and later launches show them instantly. Rendered inside the app's own views instead, an option's navigation bar leaks into the app's bar and its tab bar doesn't draw.

## Topics and options

| # | Topic | Options |
|---|---|---|
| 01 | Tab bar | Native tab bar ✓ · Sidebar when open · Minimize on scroll ✗ (does nothing on Duo) · Bottom accessory · Hide bar on detail |
| 02 | Toolbars | System toolbar ✓ · With a bottom toolbar · Inline title, more actions · Custom bar ✗ · Navigation screen, default compression ✓ · Task screen, tabs give way ✓ · Visibility priorities ✓ · Own "more" menu ✗ · Text-only items ✗ |
| 03 | List and detail | Two columns ✓ · Three columns · Detail first · One column, push ✗ · Fold keeps the open item ✓ · Fold shows the list · Third level in the detail column ✓ · Third level replaces the split ✗ |
| 04 | Grids | Adaptive grid, even columns ✓ · Large adaptive tiles · Carousel rows · Fixed two columns ✗ · Clipped carousel ✗ |
| 05 | Reading width | Readable column ✓ · Narrow form ✓ · Full-width text ✗ · Column, header left behind ✗ |
| 06 | Media | Split around the fold ✓ · Panel over video · Fixed side panel · Full-bleed video · Panel in a sheet ✗ |
| 07 | Floating overlays | Fold-aware overlay ✓ · Controls split by the fold · Fold-unaware ✗ |
| 08 | Presentations | Form sheet · Page sheet · Popover · Alert · Confirmation dialog · Menu (built in) · Sheet in the trailing half ✓ · Centred sheet · Full-screen instead of a spanning sheet ✗ |
| 09 | Hinge | Book pages · Lamp light · Card tilt (effects) · Effect only ✓ · Layout from angle ✗ · Haptic tick · Reduce Motion |
| 10 | Pitfalls | Sizing from the screen · Symmetric insets · Insets cached at launch · Layout by orientation · Clamp to a phone column (each Broken / Fixed) |
| 11 | Fold mid-task | State above the layout switch ✓ · Restore from storage · State inside each layout ✗ · Identity keyed on size class ✗ |
| 12 | Laptop pose | Video up, controls down ✓ · Side by side · Same layout everywhere · Laptop-only layout ✗ · Controls on top ✗ |
| 13 | Motion on fold | Animate the layout switch only ✓ · No animation · Animate everything ✗ · Reduce Motion crossfade (built in) |
| 14 | Toasts | Inline status ✓ · Pill in the pane ✓ · Top banner · Centred on the window ✗ · Full-width bar ✗ · Alert ✗ |
| 15 | Two panes and drag | Two panes, drag across ✓ · Two panes, move by tap · One pane, push ✗ · Grid spanning the fold ✗ |
| 16 | Keyboard per pose | Composer above the keyboard ✓ · Composer in its pane ✓ · Fixed bottom ✗ · Composer across the fold ✗ |
| 17 | Transitions | Zoom into a push ✓ · Zoom into a cover · Plain push · Hand-made hero ✗ · No transition ✗ |
| 18 | Camera per pose | Preview upright, controls flat ✓ · Book: controls beside the preview ✓ · Same everywhere · Rear-camera selfie on the outer display · Controls over the preview ✗ |
| 19 | Small windows | Adaptive ✓ · Sized from the screen ✗ · Minimum-width guard ✗ · Not rebuilt: the compatibility box (built in) |

**Guided tour:** `duolab://tour`, `duolab://tour/7?paused=1&compare=1`, or `-tour 1 -tourStep 7 -tourPaused 1 -tourCompare 1`.

✓ = Recommended, ✗ = Avoid, unmarked = Worth a try unless noted.

Capture switches: `-duolab.hideBar 1` hides the lab controls, `-duolab.present 1` opens a presentation at launch, `-duolab.pinToast 1` shows a toast at launch, `-duolab.focusComposer 1` focuses the keyboard lab's field, `-reachOverlay 1` shows the reach bands.

## Deep links and launch args

```
duolab://topic/grids                          topic page
duolab://topic/grids/fixed-two?measure=1      preview an option with the overlay
duolab://topic/tabbar/native?minimize=never   preview with a setting changed
duolab://tab/playbook
xcrun simctl launch <udid> com.example.duolab -topic media -option fixed-panel -measure 1
```

A bad topic, option or setting shows a banner and is ignored.

## Capturing

`scripts/capture.sh [open|book|closed …]` folds the sim (`rocketsim duo pose`; simctl has no pose verb) and captures home, playbook, device and every topic page into `captures/<name>-<pose>.png`. `OPTIONS="grids/fixed-two media/sheet"` adds option previews, `TOPICS=` limits the topics, and `MEASURE=1` turns the overlay on.

## What the first capture pass showed (Duo sim, iOS 27.1, 2 Nov 2026)

| Topic | Closed (outer) | Book (partially open, 90°) | Fully open (180°) |
|---|---|---|---|
| Window | 466×678, compact × regular | 951×669, regular × regular | 951×669, regular × regular |
| Window safe area | L0 T0 **R84** B34 | L0 T0 R84 B34 | L0 T0 R84 B34 |
| Fold (`.division`) | none | **active**, around x 475 | reported but **inactive** |
| Occlusions | 2 | 1 | 1 |
| Native tab bar | vertical, in the trailing rail | vertical, in the trailing rail | vertical, in the trailing rail (the inner window is landscape-shaped) |
| `ArrangementView(.split)` | stacks video over panel | splits at the fold | side by side |

- **A three-column `NavigationSplitView` shows two columns on the open display** (867 pt inner window), even with `columnVisibility = .all`. The folders column slides in from the sidebar button.
- **Minimize on scroll does nothing on the Duo.** `.tabBarMinimizeBehavior(.onScrollDown)` left the vertical tab bar unchanged, frame for frame, while scrolling (outer display, iOS 27.1 sim). The option is marked Avoid.
- **A TabView's bottom accessory ignores a `safeAreaInset`** placed around the TabView. It drew under the preview bar until the bar became a separate row in a VStack.
- **The fold is active only when partially open.** Fully open still reports the division, but `isActive == false`. Fold avoidance should key off `isActive`, not off the region existing.
- **`onHingeChange` delivers the current pose at launch** (closed 0°, partially open 90°, fully open 180°), so no "unknown" state lasts past the first frame.
- **Window top inset is 0 on both displays.** Status and cameras live in the 84 pt trailing rail; the 82 pt top inset you see inside a tab is the nav bar's, not the window's.
- **The `UIScreen` trap is visible:** screen width 466/951 vs container 382/867 (the rail eats 84). Sizing from the screen runs content under the rail.
- A system toolbar's prominent and secondary items move into the trailing rail column on the closed display; the custom bar stays a horizontal strip next to the rail.

## Notes

- In a side-by-side layout, a vertical tab bar lives in the trailing safe-area rail. A container that clips to its bounds (`.clipped()`) cuts it off, which is the likely reason one pane of the old Compare screen showed no tab bar. That screen was removed in v2, so this was not re-tested.
