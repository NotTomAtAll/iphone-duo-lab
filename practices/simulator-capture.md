# Simulator practices: capturing and driving the foldable

Measured on Xcode 27.1 / iOS 27.1 "iPhone Duo" simulator.

## Changing the pose
- Xcode's Device Hub exposes Closed / Partially Open / Open (and an angle slider). There is no
  `simctl` pose verb; third-party CLIs that wrap the Device Hub work, but verify the result by reading the
  window size rather than a reported hinge angle (the reported angle can be stale).
- `xcrun devicectl device orientation set --device <udid> landscapeLeft|portrait` works, but a
  portrait-only app does not rotate on the inner display (the system already presents it landscape).

## Screenshots: which display is which
| Pose | Display to capture | Command |
|---|---|---|
| Closed | outer | `xcrun simctl io <udid> screenshot out.png` (default display) |
| Book / Open | inner | `xcrun simctl io <udid> screenshot --display=primary-1 out.png` |

The default `screenshot` returns an all-black image for the inner display while the device is open;
`--display=primary-1` (the inner panel, 2853 × 2007 px @ 3x) is the reliable capture. Xcode's
device-interaction screenshot also returns black for the inner display.

## Accessibility tree / automation
- The simulator's accessibility tree (used by UI automation and AX-based navigators) is only populated
  while an Xcode device-interaction (automation-mode) session is attached. Sessions drop after roughly a
  minute idle; keep one alive with a trivial action every ~60 s, and restart it when "Session not found".
- On the inner display, **coordinate taps and swipes from external tools do not land** (the window is
  landscape-shaped while the device reports a portrait canvas). Activating elements through the
  accessibility action (AXPress) works. Scrolling by gesture does not work on the inner display from
  external tools; design automated tours around tap-reachable screens or use XCUITest, whose gestures go
  through the test harness.
- Run short capture batches (≤ 8 screens) and verify each capture is non-black and the expected size.

## Measuring what your app receives
Log `UIWindowScene.effectiveGeometry`, the key window's `traitCollection` size classes and
`safeAreaInsets` from `sceneDidBecomeActive` and `windowScene(_:didUpdateEffectiveGeometry:)`.
Expect: outer = compact × regular, inner = regular × regular, trailing safe-area inset ≈ 84 pt on both.

## Deep links instead of navigation (and the alert trap)
`xcrun simctl openurl <udid> "<scheme>://path"` is the most reliable way to reach deep screens on the
inner display, because it needs no taps. Two gotchas:
- A custom URL scheme opened from outside the app shows a system confirmation ("Open in <App>?").
  That alert is SpringBoard-level: it survives app relaunches and **stacks** — every `openurl` you
  fire while one is pending queues another. Nine calls meant nine Cancel taps. Confirm (or cancel) each
  one before firing the next, and prefer universal links (https) where the app handles them.
- The alert sits on whichever display is active; taps on the outer display reach it, taps on the inner
  display (from external tools) often do not. Fold closed, dismiss, unfold.

## Navigate folded, capture unfolded
Taps from automation tools land on the outer display but not on the inner one. Navigation state
survives the fold, so: fold closed → navigate → screenshot the outer display → unfold → screenshot the
inner display (`--display=primary-1`). The app re-lays out for the new size class without relaunching.

## Live audio/video on the simulator
Joining a real-time stream (Agora in our case) can abort the app on the simulator with
`AudioToolboxCore _ReportRPCTimeout → AURemoteIO::Start()` on a background thread. It is a CoreAudio
RPC timeout in the simulator's audio stack, not app code: it reproduced on two different simulators and
on two different app builds on the same day, and the same flow had worked the day before. If a stream
join dies with that stack, verify the media screen's *layout* by build + code review (or on a device) and
move on; retrying, muting host audio, or restarting the simulator's audio daemon are the only levers.

## SwiftUI gotcha: scroll views and a trailing system region
A horizontal `ScrollView` extends into the safe area along its scroll axis even when its parent is
already inset: `GeometryProxy.safeAreaInsets.trailing` still reports the inset to descendants. On a
foldable with a trailing rail (and a vertical tab bar inside it) every carousel therefore bleeds under
the bar. Re-padding/ignoring the inset nets out to the same frame; clip the hosted content at its inset
frame when a trailing inset exists. Verify with a temporary `NSLog` of the proxy's size/insets per pose.

## Generated-project gotcha (Tuist)
After rebasing onto a main that added or removed Swift packages, the previously generated `.xcodeproj`
is stale ("Missing package product …"). Regenerate before building. If generation fails with
"Trying to add a file … to a build phase that hasn't been added to the project", a source file is listed
explicitly in one target while another target's glob already includes it; newer Tuist versions reject
that. Fix the manifest (don't list the file twice) or, locally, drop the explicit entry just to
generate and restore the manifest afterwards.
