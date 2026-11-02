# 08 · What the simulator taught us

Written 2026-11-03 from the DuoLab build rounds (rounds 1 and 2). Docs 00–07 are research: what Apple
and others say. This file is what we saw when we built the labs and ran them.

**Read this first: simulator, not hardware.** Every finding below comes from the iPhone Duo simulator
(Xcode 27.1, iOS 27.1). Nothing has been checked on a real device. The simulator changes pose by
command (closed, book ≈90°, fully open), has no haptics, no camera, a software keyboard only, and
could not produce the laptop pose (horizontal fold). Window sizes, insets, size classes and API values
are probably the same on hardware; timing, animation smoothness, keyboard behaviour and anything
tied to a physical hinge may not be. Treat "measured" as "measured on the simulator".

Confidence labels:
- **measured**: seen on the simulator, in a capture or a logged value, at least once without contradiction.
- **likely**: seen, but not every time, or seen only indirectly.
- **unverified**: we expected it but could not produce the conditions.

Raw numbers live in `research/on-device-measurements.md` and `demo/README.md`. Lab numbers match the
app's topic list (01 Tab bar … 14 Toasts and banners); "Device tab" is the app's second tab.

## Display and safe areas

**The status bar and cameras live in an 84 pt trailing rail on both displays, and the window's top inset is 0.**
Any layout that hard-codes a status-bar height at the top is wrong here; pad each edge by its own inset.
The 82 pt top inset seen inside a tab is the navigation bar's, not the window's.
Shown in: Device tab ("Safe area of this screen"), 10 Pitfalls ("Symmetric insets"). Confidence: **measured**.

**Outer window 466×678 pt (compact × regular); inner window 951×669 pt (regular × regular), landscape-shaped.**
The inner display is a regular-width environment, so every size-class-adaptive container switches to its wide form.
A portrait-only app still gets the landscape-shaped inner window.
Shown in: Device tab ("Window"). Confidence: **measured**.

**The screen is wider than the space you can use: 466/951 pt screen vs 382/867 pt container.**
Sizing from the screen runs content under the rail. Size from the container.
Shown in: 10 Pitfalls ("Sizing from the screen"). Confidence: **measured**.

**The fold's `.division` region is active only in book pose; fully open still reports it, but inactive.**
Fold avoidance must key off "is active", not off the region existing. Book pose puts it around x 455–495 (centre ≈ 475, 40 pt wide).
Shown in: Device tab ("Reserved regions"), 07 Floating overlays, 06 Media. Confidence: **measured**.

**Geometry is transient during a fold.** One update can report a 669×951 screen with an 82 pt top inset before settling, and a scene reconnect can report a zero-sized window.
Never cache geometry at launch; never animate on raw geometry.
Shown in: 10 Pitfalls ("Insets cached at launch"), 13 Motion on fold. Confidence: **measured** (logged values).

**In a pane's overlay, a GeometryReader reports the window's safe-area insets (rail 84, bottom 34) even though its frame already excludes them.**
Adding those insets again pushes anything you place off-centre. Place overlays from the pane's frame only.
Shown in: 14 Toasts and banners ("Pill in the pane"). Confidence: **measured**.

## Bars

**The native tab bar stands vertical in the trailing rail in every pose we could produce.**
It never moves to the bottom of the inner display in the landscape-shaped window. Inner display in portrait was not available (see Hinge and poses).
Shown in: 01 Tab bar. Confidence: **measured** (closed, book, open).

**`.tabBarMinimizeBehavior(.onScrollDown)` does nothing on iPhone Duo.**
The vertical bar stayed the same, frame for frame, while scrolling, in every pose. Use the compression behaviour (below) if you need room.
Shown in: 01 Tab bar ("Minimize on scroll", Avoid). Confidence: **measured**.

**A TabView's bottom accessory ignores a `safeAreaInset` placed around the TabView.**
It drew under a custom bottom bar until that bar became its own row in a VStack. Don't count on safe-area insets to keep the accessory clear of your own chrome.
Shown in: 01 Tab bar ("Bottom accessory"). Confidence: **measured**.

**With 4 tabs and 8 toolbar items folded, the default keeps all 4 tabs and only 3 actions (Share, badged Bell, Like); the rest overflow, the prominent Compose too.**
On a browse screen this is fine. On an editor it hides the main action. Open, four actions fit.
Shown in: 02 Toolbars ("Browse screen: actions give way"). Confidence: **measured**.

**`.toolbarVerticalCompressionBehavior(.prefersToolbarItems)` shrinks the tab bar to one button for the current tab (badge kept) and keeps 7 actions.**
This is the right switch for task screens. Only Delete and Compose were left in overflow.
Shown in: 02 Toolbars ("Task screen: tabs give way"). Confidence: **measured**.

**`visibilityPriority(.high)` works: Share, Bell and Compose stay; Like and below overflow.**
Without priorities Compose was the first to go. Set priorities on frequent, badged and prominent items.
Shown in: 02 Toolbars ("Keep frequent actions longest"). Confidence: **measured**.

**An app's own "More" menu ends up nested inside the system overflow menu.**
Two levels of menu for the same job. Use the system overflow; don't add your own.
Shown in: 02 Toolbars ("Own “more” menu", Avoid). Confidence: **measured**.

**Text-only toolbar items stay in a horizontal strip at the top instead of joining the vertical bar.**
The side column then holds only symbol items and an overflow whose entries have no symbols. Give every item a symbol and a title.
Shown in: 02 Toolbars ("Text-only actions", Avoid). Confidence: **measured**.

**With the keyboard up, the tab bar hides completely when folded and sits under the keyboard when open.**
The same toolbar actions stay visible in both. Don't put anything you need while typing in the tab bar.
Shown in: 02 Toolbars ("Browse screen: actions give way"). Confidence: **measured**.

**A hand-built bar stays a horizontal strip next to the rail; system toolbar items move into the rail column on the closed display.**
Custom bars don't get the vertical layout. Prominent and secondary system items do.
Shown in: 02 Toolbars ("Custom bar"). Confidence: **measured**.

## Split views and hierarchy

**A three-column NavigationSplitView shows two columns on the inner display, even with `columnVisibility = .all`.**
The first column slides in from the sidebar button. Design for two visible columns; a third level is a push inside the detail.
Shown in: 03 List and detail ("Three columns: folders + list + detail"). Confidence: **measured**.

**A tab view's sidebar on the inner display is opt-in; with it on, folding goes back to tabs with the same selection.**
Shown in: 01 Tab bar ("Sidebar when open"). Confidence: **measured** for the opt-in; selection kept is from the option's "look for" text.

## Presentations

**A toast pill centred on the window sits ~42 pt off the content centre on the closed display (half the rail) and straddles the fold in book pose.**
Centre against the source pane, not the window, and keep the pill on one side of an active fold.
Shown in: 14 Toasts and banners ("Pill centred on the window", Avoid, vs "Pill in the pane"). Confidence: **measured**.

**A zoom transition from a card that shows the other display's picture into the live screen produces a ghosted double image.**
Using the card's own cached picture as the cover's first frame fixes it. When the card shows the other display, DuoLab falls back to a fade.
Shown in: the Topics list (tap any card). Confidence: **measured**.

**An open sheet survives fold→open and open→closed when its flag lives above the size-class switch.**
Shown in: 11 Fold mid-task ("State above the layout switch"). Confidence: **measured**.

## Hinge and poses

**`DeviceHinge` exposes only `status` and `angle`; there is no fold direction.**
Book vs laptop is not a hinge value. Tell them apart by the shape of the active `.division` region, or let ArrangementView do it.
Shown in: 09 Hinge effects, Device tab ("Hinge"). Confidence: **measured** (SDK interface and runtime).

**`onHingeChange` delivers the current pose at launch (closed 0°, book 90°, open 180°).**
No "unknown" state lasts past the first frame on the simulator. Still handle nil and unknown; hardware may differ.
Shown in: 09 Hinge effects, Device tab. Confidence: **measured**.

**`overlayArrangementZIndex` read 0 in every pose we tested (closed, book, open).**
We could not test laptop pose, where Apple's docs say the controls should expand. Don't rely on it until checked on hardware; lab 12 switches its expanded controls from the division region instead.
Shown in: 12 Laptop pose. Confidence: **measured** for the poses tested; laptop **unverified**.

**Rotating the open device changes the reported orientation, but the inner window stays 951×669 with the same upright fold (x 456, width 40).**
The simulator cannot produce a laptop (horizontal fold) pose. Lab 12 draws a simulated fold band by hand; its laptop captures are simulations.
Shown in: 12 Laptop pose (simulated laptop switch). Confidence: **measured** for the rotation result; laptop pose itself **unverified**.

**The simulator has no haptics.** Lab 09's "Light tap at each pose" shows a tick mark instead.
Shown in: 09 Hinge effects ("Light tap at each pose"). Confidence: **measured**.

## State across folds

**With state held above the size-class switch, selection, scroll, typed text, keyboard focus, progress and an open sheet all survived fold→open and open→closed.**
This is the pattern to copy. The checklist overlay in lab 11 ticks each one after the change.
Shown in: 11 Fold mid-task ("State above the layout switch", Recommended). Confidence: **measured**.

**The software keyboard stayed up across the fold in the main run; a later run showed the cursor without the keyboard.**
Focus survives; whether the keyboard itself stays up is not settled. Re-check on hardware.
Shown in: 11 Fold mid-task. Confidence: **likely**.

**`.id(sizeClass)` on the root resets everything, the sheet included.**
Shown in: 11 Fold mid-task ("Screen rebuilt on every fold", Avoid). Confidence: **measured**.

**State declared inside each size-class branch resets everything on fold.**
List back at the top, nothing selected, draft empty.
Shown in: 11 Fold mid-task ("State inside each layout", Avoid). Confidence: **measured**.

**Restoring from storage after the rebuild brings the data back, but the detail blinks and focus (and the keyboard) is lost.**
Fine as a crash-recovery backup, not as the main mechanism.
Shown in: 11 Fold mid-task ("Rebuild, then restore", Consider). Confidence: **measured**.

## Rendering and tooling

**SwiftUI content hosted inside the app's hierarchy, even in a detached UIHostingController, adopts the host's navigation controller.**
Titles and toolbars leak into it and no tab bar is drawn. Only a separate UIWindow isolates it; DuoLab's thumbnails render that way.
Shown in: the Topics list thumbnails. Confidence: **measured**.

**A hidden window reads as compact to TabView's sidebar logic unless the trait is overridden.**
Thumbnails of regular-width layouts need the size-class trait set explicitly.
Shown in: 01 Tab bar thumbnails ("Sidebar when open"). Confidence: **measured**.

**Taps only land on the outer display; the inner display has to be captured after a pose change.**
Navigate closed, change pose, then screenshot the inner display (`--display=primary-1`). See `practices/simulator-capture.md`.
Confidence: **measured** (tooling limit, not an app behaviour).

**A container that clips to its bounds can cut off the vertical tab bar, which lives in the trailing safe area.**
Likely why one pane of an old two-up screen showed no tab bar. That screen was removed, so not re-tested.
Confidence: **likely**.

## What still needs hardware or a re-check

- Keyboard staying up across a fold (likely, not proven).
- Laptop pose: window size in portrait, bar axis, `overlayArrangementZIndex`, keyboard position.
- `onHingeChange` at launch and the angle's smoothness on a physical hinge.
- Haptics at pose boundaries.
- Animation smoothness during a real fold (lab 13); the simulator jumps between poses.

## Added after round 5

- **A full-screen cover presented before the scene is active blocks every touch until the presentation finishes** (about 0.6–0.85 s after the first frame, measured with `-duolab.timeline 1`). An option opened from a link is now drawn in the root view instead; the first tap lands within 0.4–0.7 s of the first frame. Measured.
- **In book pose, any single-column list or text column spans the fold unless you split it yourself.** Every Recommended answer now splits at the fold's edges (`FoldColumns`, `FoldLocator`). Measured.
