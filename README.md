# DuoLab

**Try every iPhone Duo layout decision live, then pick the one that works.**

DuoLab is a SwiftUI app for Apple's foldable iPhone. Seventeen questions every app has to answer on a device that folds, each with the realistic answers side by side, a verdict for each, and the reasoning behind it. Open an answer full screen, fold and unfold the simulator, and see what actually happens.

![DuoLab on the open and the folded display](docs/images/home.png)

## Run it

Xcode 27.1 · iPhone Duo simulator · no dependencies.

```bash
open demo/DuoLab/DuoLab.xcodeproj
```

Pick an iPhone Duo simulator, run, then change the pose in Device Hub (Closed, Partially Open, Open) and watch the layouts react. Jump straight to any answer with a link:

```
duolab://topic/grids/adaptive-even
xcrun simctl launch booted com.example.duolab -topic media -option arrangement-split
```

## The questions

| | |
|---|---|
| ![Tab bar](docs/images/tabbar.png) **Tab bar** · How should the tab bar behave when the phone folds and opens? | ![Toolbars](docs/images/toolbars.png) **Toolbars** · Where do the screen's action buttons go, and what gives way when the side bar runs out of room? |
| ![List and detail](docs/images/listdetail.png) **List and detail** · Should a list and the item you open sit side by side? | ![Grids](docs/images/grids.png) **Grids** · How should a photo grid use the big display without a photo on the fold? |
| ![Reading width](docs/images/reading.png) **Reading width** · How wide should text and forms be? | ![Media](docs/images/media.png) **Media** · Where does chat go next to a video, in every pose? |
| ![Overlays](docs/images/overlays.png) **Floating overlays** · How do floating controls stay clear of the fold and the cameras? | ![Presentations](docs/images/sheets.png) **Presentations** · Where do sheets, popovers and alerts appear? |
| ![Hinge](docs/images/hinge.png) **Hinge** · What can the fold angle bring to life, and what should it never decide? | ![Pitfalls](docs/images/pitfalls.png) **Pitfalls** · What breaks first on a foldable, broken and fixed side by side. |
| ![Fold mid-task](docs/images/continuity.png) **Fold mid-task** · Did anything get lost when I opened the phone? | ![Laptop pose](docs/images/laptop.png) **Laptop pose** · Half open on a table: what goes up top and what goes below? |
| ![Motion](docs/images/motion.png) **Motion on fold** · Should the layout animate when the phone opens, and how much? | ![Toasts](docs/images/toasts.png) **Toasts** · Where should a "Saved" message appear on each display? |
| ![Two panes](docs/images/twopanes.png) **Two panes and drag** · Can two screens live side by side, and can I drag between them? | ![Keyboard](docs/images/keyboard.png) **Keyboard per pose** · Where does the keyboard go, and does my draft survive a fold? |
| ![Transitions](docs/images/transitions.png) **Transitions** · Which transitions feel right on a foldable, and which get in the way? | |

Every answer carries a verdict: **Recommended**, **Worth a try**, **Avoid**, or **Built in** when the system decides. The verdicts come from Apple's guidance where it exists, from what Samsung, Google and Microsoft learned on their foldables where it doesn't, and from measurement on the simulator. The **i** button on any answer shows the reasoning and, under *How it's built*, the exact API.

![An answer running full screen](docs/images/topic-page.png)

## What the simulator taught us

Measured on the iPhone Duo simulator, iOS 27.1, and baked into the verdicts:

- **The inner display is regular × regular**, like an iPad, and it ignores a portrait-only orientation lock.
- **The status bar and cameras live in an 84 pt strip on the trailing edge** of both displays; the window's top inset is 0. Anything sized from the screen instead of its container runs under that strip.
- **The fold is reported only when the device is partly open.** Fully open, the division region exists but is inactive, so fold avoidance must check `isActive`.
- **The native tab bar stands upright in that strip in every pose**, and `tabBarMinimizeBehavior` does nothing there.
- **A three-column split view shows two columns** on the inner display.
- **Toolbar items, prominent and secondary, move into the strip** when folded; a custom bar stays a horizontal stripe next to it.
- **In book pose the keyboard splits into two halves around the fold**, and it stays up across a fold as long as the field survives the layout change.
- **Every sheet stays in one half in book pose.** Form, page and custom sizes all land in the leading half unless placed trailing; nothing spans the fold.
- **A tab bar's minimize-on-scroll does nothing**, and when space runs out the system drops toolbar items first unless the screen says it prefers them.

## The reasoning

| | |
|---|---|
| [Principles](docs/00-principles.md) | Twelve rules for a foldable app, each tied to the lab that shows it |
| [Pose and continuity](docs/01-pose-and-continuity.md) | What must survive a fold, laptop and book pose, closing mid-task |
| [Navigation](docs/02-navigation-and-hierarchy.md) | Tab bar vs sidebar, split views, where Back goes, zoom transitions |
| [Presentations and feedback](docs/03-presentations-and-feedback.md) | Sheets, popovers, menus, and nine rules for toasts on a foldable |
| [Motion](docs/04-motion-and-animation.md) | What to animate on a fold, what not to, Reduce Motion |
| [Input and ergonomics](docs/05-input-and-ergonomics.md) | Reach, keyboard, drag between halves, pointer, camera per pose |
| [Competitor patterns](docs/06-competitor-patterns.md) | 25 Samsung, Google and Microsoft patterns and whether iOS has an equivalent |
| [Findings](docs/08-findings.md) | What the simulator taught us, with confidence levels |
| [Lab backlog](docs/07-lab-backlog.md) | What's next, ranked |
| [Facts](research/apple-foldable-facts.md) · [Tab bar facts](research/native-tabbar-liquid-glass-facts.md) · [Measurements](research/on-device-measurements.md) · [Checklist](CHECKLIST.md) | Sourced reference |

## Capturing your own

`demo/scripts/readme-shots.sh` re-takes every image above in both poses; `demo/scripts/capture.sh` shoots any topic or answer. Both fold the simulator for you. Notes on the simulator's quirks: [practices/simulator-capture.md](practices/simulator-capture.md).
