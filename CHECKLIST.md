# iPhone Duo adaptation checklist

App-agnostic. Each item is a thing to check, decide, or build. Nested points are the detail.

## 1. Know the device
- Two screens: phone-sized outer, wide inner about twice as wide.
  - Outer: compact width, portrait, like a wide phone.
  - Inner: regular width AND regular height, landscape-shaped.
- Portrait lock is ignored on the inner screen.
- Three poses: closed, book (half open), flat open.
  - Book pose adds a fold region down the middle.
  - Flat pose has no fold region.
- An 84 pt system strip sits on the right edge, both screens.
  - Clock, status and the tab bar live there.
  - It is a plain trailing safe-area inset.
- Folding is a live geometry change, not a relaunch.

## 2. Layout
- Branch on size class, never on device model or pose.
- Size from the container, never from the screen bounds.
- Never cache insets, widths or bounds at launch.
- Do not clamp the whole app to a phone column.
  - Grids reflow by width; cards size from their cell.
  - Master–detail pairs become split views in regular width.
  - Full-screen media gets a side panel instead of overlays.
  - Only reading screens get a centred readable column, opt in.
- Carousels may run under the strip; end them with a soft fade.
  - Solid buttons and cards must stop before the fade.
- Test every screen in all three poses, not just open.

## 3. Safe area and the strip
- Default layouts respect the strip; custom ones often do not.
- Audit anything that ignores the safe area.
  - Re-add the trailing inset for controls on full-screen views.
  - Keep video and backgrounds edge to edge.
- Scroll views extend under the strip along the scroll axis only.
- Nothing tappable under the strip, ever.

## 4. Navigation chrome
- Use the native tab bar; the system moves it to the strip.
  - Custom bars stay at the bottom and stretch.
  - Keep your icons and tints; skip appearance hacks.
  - Re-tap to root, badges, hidden tabs: rebuild with native APIs.
- One navigation bar for all pushed screens.
  - Same back button, same position, same size, same height.
  - Header spans the full width even over a centred column.
  - Title in one position; avatar titles must match it.
  - Leave the brand header alone if it is a product choice.
- Hiding the tab bar must not change orientation behaviour.

## 5. Orientation
- Check what the app allows when the tab bar is hidden.
  - Portrait-only masks can rotate the whole scene on the inner screen.
  - Allow landscape in regular width; keep phones portrait-locked.
- Watch for full-screen covers and hosting controllers with their own masks.

## 6. State across folds
- Fold and unfold must keep navigation state and selection.
- Typed text, drafts and scroll position must survive.
  - Hoist view models above any size-class branch.
  - Do not key view identity on size class.
- Media keeps playing across a fold.
- Sheets either follow the fold or dismiss cleanly, never half-size.

## 7. Sheets, dialogs, toasts
- Centre dialogs on the safe area, not the window.
- Cap dialog width; 320 pt reads well on both screens.
- Toasts size from live safe-area width at show time.
- Bottom sheets inset their content from the strip.
- Detents compute from the sheet container, never screen height.
- Dim layers must resize with the window.
- Every popover needs an anchor or it crashes in regular width.
  - Share sheets, action sheets, presented web views.
- Dismiss the keyboard before showing an exit confirmation.
- Test each dialog kind: alert, action sheet, card, sheet, toast, share.

## 8. Fold region and cameras (iOS 27.1)
- Floating elements avoid the fold in book pose.
  - Mini player, floating buttons, side panels.
- Re-snap on hinge or geometry changes.
- System split views avoid the fold on their own; expect a seam.
  - Paint a background across it so it reads as intended.
- Nothing changes when flat or on older iOS.

## 9. Design and UX
- Decide the inner-screen model per screen type.
  - Feed: full-width rows or grid, not a wide phone.
  - Lists: full width or readable column, pick one rule.
  - Chat: inbox beside conversation.
  - Forms and settings: centred readable column.
- Hard edges next to the strip look cut; prefer a soft fade.
- Keep tap targets at least 44 pt; wide screens tempt small controls.
- Chevrons and trailing actions must not drift a screen away from labels.
- Decide tab labels, badge style, disabled vs hidden tabs.
- Decide video fit: letterbox or crop, and panel order.
- Give product owners before and after images per pose, dated.

## 10. Testing on the simulator
- Fold with Device Hub or a scripted pose; verify by window size.
- Inner-screen screenshots need the inner display selected.
- External taps and scrolls do not land on the inner screen.
  - Navigate while closed, then unfold and capture.
  - Deep links reach deep screens; dismiss the "Open in" alert.
- Keep an Xcode device session open for accessibility trees.
- Capture closed, book and open for every screen and dialog.
- Measure positions from the accessibility tree, not by eye.
- Check once on a normal phone: nothing moved.
- Verify video and audio paths on a real device.

## 11. Process
- Audit first: capture everything broken before any fix.
- Fix root causes: tab bar, size classes, safe area, cached geometry.
- Review each round strictly; small gaps show on a wide screen.
- Gate risky changes behind a flag on older iOS.
- Keep an app-agnostic write-up so the next app starts faster.

## 12. Useful references

### Apple, read in this order
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo): the SDK opt-in, what changes.
- [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo): poses, controls, the strip.
- [Tech Talk: Prepare your app for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111461/): full-screen opt-in, Device Hub.
- [Tech Talk: Design for iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111466/): size classes over poses, sheets, fold avoidance.
- [Tech Talk: Strike a pose with adaptive layouts](https://developer.apple.com/videos/play/tech-talks/111463/): reserved regions, split and overlay arrangements.
- [Tech Talks 111462](https://developer.apple.com/videos/play/tech-talks/111462/) and [111464](https://developer.apple.com/videos/play/tech-talks/111464/): the rest of the series.
- [ReservedRegion](https://developer.apple.com/documentation/swiftui/reservedregion): fold `.division`, camera `.occlusion`.
- [Interacting with your app in Device Hub](https://developer.apple.com/documentation/xcode/interacting-with-your-app-in-device-hub): posing the simulator.
- [TN3192: migrating from UIRequiresFullScreen](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key): why portrait lock is ignored.
- [UIDesignRequiresCompatibility](https://developer.apple.com/documentation/bundleresources/information-property-list/uidesignrequirescompatibility): the escape hatch, not recommended.
- [iPhone Duo prepare page](https://developer.apple.com/iphone-duo/prepare/) and [developer news, Oct 2026](https://developer.apple.com/news/?id=kkphp5qo).

### Apple, tab bar and Liquid Glass
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass).
- [HIG: Tab bars](https://developer.apple.com/design/human-interface-guidelines/tab-bars).
- [Tab](https://developer.apple.com/documentation/swiftui/tab), [TabView init(selection:)](https://developer.apple.com/documentation/swiftui/tabview/init(selection:content:)), [TabContent.badge](https://developer.apple.com/documentation/swiftui/tabcontent/badge(_:)), [TabContent.hidden](https://developer.apple.com/documentation/swiftui/tabcontent/hidden(_:)).
- [TabRole.search](https://developer.apple.com/documentation/swiftui/tabrole/search), [TabViewCustomization](https://developer.apple.com/documentation/swiftui/tabviewcustomization), [SidebarAdaptableTabViewStyle](https://developer.apple.com/documentation/swiftui/sidebaradaptabletabviewstyle).
- [defaultTabBarPlacement](https://developer.apple.com/documentation/swiftui/view/defaulttabbarplacement(_:)), [TabBarMinimizeBehavior](https://developer.apple.com/documentation/swiftui/tabbarminimizebehavior), [tabViewBottomAccessory](https://developer.apple.com/documentation/swiftui/view/tabviewbottomaccessory(content:)).
- [safeAreaBar](https://developer.apple.com/documentation/swiftui/view/safeareabar(edge:alignment:spacing:content:)), [scrollEdgeEffectStyle](https://developer.apple.com/documentation/swiftui/view/scrolledgeeffectstyle(_:for:)).
- UIKit: [UITab](https://developer.apple.com/documentation/uikit/uitab), [UITabBarController.Mode](https://developer.apple.com/documentation/uikit/uitabbarcontroller/mode-swift.enum), [Elevating your iPad app with a tab bar and sidebar](https://developer.apple.com/documentation/uikit/elevating-your-ipad-app-with-a-tab-bar-and-sidebar), [TN3106 navigation bar appearance](https://developer.apple.com/documentation/technotes/tn3106-customizing-uinavigationbar-appearance).
- WWDC25: [284 Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/), [323 Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/).

### Community, useful but verify
- [adapty.io: adapt your iOS app to iPhone Duo](https://adapty.io/blog/adapt-your-ios-app-to-iphone-duo/).
- [dev.to: what actually changes in your Swift code](https://dev.to/arshtechpro/iphone-duo-for-ios-developers-what-actually-changes-in-your-swift-code-5gc5).
- [blakecrosley.com: the Xcode 27.1 Duo simulator](https://blakecrosley.com/blog/xcode-27-1-beta-iphone-duo-simulator).
- [Donny Wals: tab bars on iOS 26](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/), [fatbobman: Liquid Glass UIKit pitfalls](https://fatbobman.com/en/posts/liquid-glass-a-field-guide-to-uikit-compatibility-pitfalls/), [Swift with Majid: WWDC26 SwiftUI](https://swiftwithmajid.com/2026/06/08/what-is-new-in-swiftui-after-wwdc26/).
- Apple forums: [848598](https://developer.apple.com/forums/thread/848598), [789660](https://developer.apple.com/forums/thread/789660), [802302](https://developer.apple.com/forums/thread/802302), [825708](https://developer.apple.com/forums/thread/825708).
- Automation limits: [Maestro #3617](https://github.com/mobile-dev-inc/maestro/issues/3617), [iphone-duo-simulator-skill](https://github.com/WhitenWhiten/iphone-duo-simulator-skill).

### In this folder, what we wrote
- `research/apple-foldable-facts.md`: 29 sourced facts on poses, size classes, SDK behaviour.
- `research/native-tabbar-liquid-glass-facts.md`: 33 facts plus a migration checklist.
- `research/on-device-measurements.md`: what the simulator hands the app, per pose.
- `practices/simulator-capture.md`: poses, displays, taps, deep links, measuring.
- `demo/`: DuoLab, the app that lets you try every option live.

### Numbers worth memorising
- Outer window 466 × 678 pt, compact × regular.
- Inner window 951 × 669 pt, regular × regular.
- Trailing strip 84 pt on both; bottom inset 34 pt.
- Fold region in book pose about 20 pt wide, centred.
- Poses: closed 0°, book about 90°, open 180°.
