# iPhone Duo Lab

Practical notes and a demo app for making an iPhone app feel at home on **iPhone Duo**, Apple's foldable: a compact outer display and a large inner display.

## DuoLab, the demo app

`demo/DuoLab` is a SwiftUI app for iOS 27.1 that turns ten layout questions into options you can try live on the iPhone Duo simulator:

| | |
|---|---|
| **Explore** | One gallery. Each topic (tab bar, toolbars, list and detail, grids, reading width, media, floating overlays, presentations, hinge effects, pitfalls) is a row of options with real thumbnails, open or folded. |
| **Preview** | Tap an option to run it full screen. Page through the alternatives, read what each one is good at, and tap **Use this**. |
| **Playbook** | Your choices with a reason each, shareable as text. |
| **Device** | Live window size, safe area, hinge angle and fold position. |

Open `demo/DuoLab/DuoLab.xcodeproj` in Xcode 27.1 and run it on an iPhone Duo simulator. Details, deep links and the capture script are in [`demo/README.md`](demo/README.md). Screenshots from every pose are in `demo/captures`.

## What we measured

From the iOS 27.1 simulator:

- The **inner display is regular × regular**, like an iPad, and ignores a portrait-only orientation lock.
- The status bar and cameras sit in an **84 pt strip on the trailing edge** on both displays. The window's top inset is 0.
- The **fold is active only when partly open.** Fully open still reports it, but as inactive.
- The **native tab bar stands upright in that trailing strip** in every pose, and **minimize-on-scroll does nothing** there.
- A **three-column split view shows two columns** on the open display.

## The rest of the folder

| Folder | What's in it |
|---|---|
| `research/` | Sourced facts about the device and the SDK, plus on-device measurements |
| `practices/` | Driving and capturing the simulator: poses, displays, deep links |
| `CHECKLIST.md` | A step-by-step adoption checklist with sources |

Some notes cite IDs such as `D1` or `R-§1` from private design notes that aren't part of this repo.
