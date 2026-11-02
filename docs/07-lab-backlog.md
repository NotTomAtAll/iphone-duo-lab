# 07 · Lab backlog

Written 2026-11-02 from docs 00–06. Each item is a new DuoLab topic, or new options for an existing
one, in the current shape: a plain question, 3–6 curated options each with a verdict
(Recommended / Consider / Avoid / System / Effect), and "what to look for". Effort: **S** ≈ one lab
file plus thumbnails, **M** ≈ a lab with state or a pose-specific layout, **L** ≈ needs new shell
support (e.g. a scripted fold, a measurement overlay).

## What we do in DuoLab and why

The ten existing topics answer "what goes where on each display". The backlog adds "what happens when
the display changes under you", plus the two gaps every team hits: laptop pose and toasts. Priority
is by (a) how often apps get it wrong, (b) how little Apple shows, (c) how well a simulator demo can
show it. Camera and pointer items sit low because the simulator can't show them honestly.

Verification note for the build team: every option below can be checked by **navigating folded, then
changing pose, then capturing** (`practices/simulator-capture.md`). Items that need a portrait inner
display (B2, B14) first need one measurement we don't have: the window size, size class and bar axis
on the inner display **rotated to portrait**. Capture that before building them.

## Top 5

| Rank | Item | Why it's top 5 |
|---|---|---|
| 1 | **B1 Fold mid-task** | The #1 failure on every foldable (Google makes it Tier 3 pass/fail). Apple states the rule, shows nothing. |
| 2 | **B2 Laptop pose** | The one pattern every platform shares; Apple endorses it and ships `ArrangementView(.overlay)`, with no complete example. |
| 3 | **B5 Toasts and banners** | Every app builds one; Apple has none; the rail and fold break naive ones. |
| 4 | **B4 Motion on fold** | Apple is silent; Samsung says "strongly recommended"; naive implicit animation looks broken on transient geometry. |
| 5 | **B6 Bar compression** | New Duo-only API (`toolbarVerticalCompressionBehavior`, visibility priority, overflow) that decides what survives when space runs out; lab 02 doesn't cover it. |

---

## B1 · Fold mid-task ★ top 5
- **Question.** "I was in the middle of something and opened the phone. Did anything get lost?"
- **Setup.** One screen with a tab, a list with a selected row, a pushed detail, a half-typed text field
  with focus, a playing (fake) progress bar, a scrolled list, and an optional open sheet. A checklist
  overlay ticks each item that survived the last resize (compare state before/after a size-class change).
- **Options.**
  - *State above the layout switch* — **Recommended.** Everything survives.
  - *State inside each layout branch* — **Avoid.** Selection, text and scroll reset on fold.
  - *View identity keyed on size class* (`.id(sizeClass)`) — **Avoid.** Everything resets, including the sheet.
  - *Restore from storage after rebuild* — **Consider.** Survives, but flickers and loses focus.
- **Look for.** Selected row, scroll offset, cursor and keyboard, sheet still up and re-placed,
  progress continuing, Back chain identical after closing.
- **Also capture** (open questions from doc 01): does the keyboard stay up across a fold; what happens
  to an open popover when you close the device; do custom detents re-resolve.
- **Justified by.** 00 P2; 01 §2, §6; 06 row 14.
- **Effort.** M.

## B2 · Laptop pose: view up, controls down ★ top 5
- **Question.** "On a table, half open, what goes in the top half and what in the bottom?"
- **Setup.** A generic media screen (gradient "video", transport, scrubber, an up-next list, an alert
  trigger). Works in every pose; the laptop pose is where options differ.
- **Options.**
  - *Overlay arrangement* (controls primary, media secondary; controls expand in the bottom half using
    the arrangement's z-index) — **Recommended.**
  - *Split arrangement, horizontal only* (Apple's Podcasts-style: panes side by side, single pane when
    tall) — **Consider.** Good in book pose, ignores laptop pose.
  - *Same layout in every pose* — **Consider** for lists and settings (Samsung: not every screen needs it).
  - *Laptop-only layout that drops controls* — **Avoid.** Breaks "same controls in every pose".
  - *Controls in the top half* — **Avoid.** Hard to reach, wobbles.
- **Look for.** Media fully in the top region, nothing tappable in the fold, all controls present, the
  alert landing in the top region (system), a smooth change when you lay the device flat.
- **Justified by.** 00 P9; 01 §4; 06 rows 1, 3, 5.
- **Effort.** M (needs the portrait-inner measurement first).

## B3 · Collapse and expand rules for list-detail
- **Question.** "When it closes, do I see the list or the thing I was reading? When it opens, is the list in sync?"
- **Options.**
  - *Detail wins if selected, list highlights on expand, hint in empty detail* — **Recommended** (Google's rules).
  - *Always back to the list on close* — **Avoid.** Loses the reader's place.
  - *Auto-select the first item on open* — **Consider.** No empty pane, but changes state just by opening.
  - *Blank detail when nothing selected* — **Avoid.**
- **Look for.** What shows after close; selection highlight after open; Back from the detail on the outer display.
- **Justified by.** 02 §2; 06 row 7. Could be new options in lab 03 rather than a new topic.
- **Effort.** S.

## B4 · Motion on fold ★ top 5
- **Question.** "Should the layout animate when I open the phone, and how much?"
- **Setup.** One layout that changes mode on fold (list → split, a floating button that moves off the
  fold, a grid that gains columns), with four motion options.
- **Options.**
  - *Animate the mode only* (spring keyed on a derived mode; grid reflows without animation; moved
    element follows with matched geometry) — **Recommended.**
  - *No animation* — **Consider.** Honest and fast; the moved element is hard to track.
  - *Animate everything* (implicit animation on geometry) — **Avoid.** Animates through transient frames, cells fly.
  - *Reduce Motion* (crossfade only) — **System**: what the Recommended option becomes with the setting on.
- **Look for.** Any frame with a wrong size, cells flying, the moved element's path, scroll position kept,
  a second fold interrupting the first.
- **Also log.** Whether `viewWillTransition(to:with:)` fires on fold in a UIKit host; what zoom
  transitions degrade to under Reduce Motion.
- **Justified by.** 00 P11; 04 §3, §5, §6; 06 row 3.
- **Effort.** M.

## B5 · Toasts and banners ★ top 5
- **Question.** "Where should a 'Saved' message appear on each display and pose?"
- **Options.**
  - *Inline status* (the change itself, or a status line in the bar) — **Recommended** where possible.
  - *Bottom pill in the source pane, safe-area aware, fold-aware* — **Recommended** for transient confirmations.
  - *Top banner pushing content (safe-area inset)* — **Consider** for persistent state like offline.
  - *Bottom pill centred on the window* — **Avoid.** Off-centre by 42 pt, can tuck under the rail.
  - *Full-width bottom bar* — **Avoid.** Spans 867 pt and the fold.
  - *Alert as toast* — **Avoid.** Interrupts.
- **Look for.** Centring against the content area, never across the fold in book pose (trailing side
  for global messages), top region in laptop pose, above the keyboard, re-placed or dismissed on fold,
  VoiceOver announcement.
- **Justified by.** 00 P12; 03 §4; 06 row 16.
- **Effort.** M.

## B6 · Bar compression and overflow ★ top 5
- **Question.** "When the side bar runs out of room, what disappears first: tabs or toolbar buttons?"
- **Setup.** A tab view with a screen carrying 6–8 toolbar items, one badged. Space pressure from
  landscape on the outer display, or by showing the keyboard.
- **Options.**
  - *Navigation screen, default compression (toolbar items overflow first)* — **Recommended** for browse screens.
  - *Task screen, `.prefersToolbarItems` (tab bar compresses)* — **Recommended** for editors.
  - *Visibility priorities set (frequent and badged items last to overflow)* — **Recommended** add-on.
  - *Own "more" menu next to the system overflow* — **Avoid.** Two overflow menus.
  - *Text-only items* — **Avoid.** They stay horizontal and break the vertical bar.
- **Look for.** Which items survive, order (Back/Close top, prominent next), the badge staying visible,
  everything reachable in the overflow menu with title + symbol.
- **Justified by.** 00 P6; HIG "When space is limited, preserve either the toolbar or tab bar"
  ([HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)); 02 §1. Could be new options in lab 02.
- **Effort.** S–M.

## B7 · Zoom transitions on Duo
- **Question.** "Where does the zoom transition help, and where does it confuse?"
- **Options.** *Grid → full-screen item* — **Recommended.** · *List → detail in the other pane* —
  **Avoid** (use the plain push). · *Sheet morphing from its toolbar button* — **Recommended**.
  · *Fold while zoomed in, then dismiss* — **Effect** (shows what happens when the source moved).
- **Look for.** Whether the system animates a zoom across columns at all; the dismiss target after a fold.
- **Justified by.** 02 §5; 04 §1. **Effort.** S.

## B8 · Deep hierarchy on the inner display
- **Question.** "Level 3, 4, 5: where do they go when list and detail are both on screen?"
- **Options.** *Push inside the detail column* — **Recommended.** · *Shift columns left* — **Avoid.**
  · *Three columns* — **Avoid** (only two show, measured). · *Sheet for a self-contained task* — **Consider.**
- **Look for.** List stays put; Back pops the detail; after closing, same depth and Back chain.
- **Justified by.** 02 §4. **Effort.** S.

## B9 · Hinge effect hygiene (extend lab 09)
- **Question.** "How do I make a hinge effect feel good and not jittery?"
- **Options.** *Direct angle mapping, smoothed, thresholds with hysteresis* — **Recommended.**
  · *`withAnimation` on every angle change* — **Avoid** (lags the hand). · *Light haptic on a threshold* — **Consider.**
  · *Reduce Motion: state only, no motion* — **System.**
- **Justified by.** 00 P10; 03 §5; 04 §4. **Effort.** S.

## B10 · Dual view and drag between panes
- **Question.** "Can two panes show the same data two ways and stay in sync?"
- **Options.** *Shared model, two representations (a grid of tiles + a list), selection mirrored* —
  **Consider.** · *Drag a row into the detail pane* — **Consider.** · *Drop target in the fold* — **Avoid.**
- **Justified by.** 05 §3; 06 row 18. **Effort.** M.

## B11 · Sheet placement and sizing on the inner display (extend lab 08)
- **Question.** "Centre, leading or trailing? Form or page? Vertical bar or not?"
- **Options.** *Automatic/centre form sheet* — **Recommended** default. · *Trailing sheet for detail edits*
  — **Recommended** (gets a vertical bar). · *Leading sheet for list filters* — **Consider.**
  · *Disable vertical bar on a one-button sheet (outer display)* — **Consider.**
  · *Sheet covering the whole window* — **Avoid.**
- **Justified by.** 03 §2; 06 row 13. **Effort.** S.

## B12 · Short and narrow windows (Split View, pinned PiP, compatibility)
- **Question.** "What does my screen look like at half width, or shortened by a pinned video?"
- **Options.** *Size-class adaptive* — **Recommended.** · *Fixed heights* — **Avoid** (clips when PiP pins).
  · *Scaled compatibility preview (as `UIRequiresFullScreen` would look)* — **Avoid**, shown for contrast.
- **Note.** The shell can only fake these sizes with a framed preview; mark captures as simulated.
- **Justified by.** 01 §7; 06 row 25; HIG Split View notes. **Effort.** M–L.

## B13 · Reach zones overlay (Device tab or HUD)
- **Question.** "Is this button where a thumb can reach it in this pose?"
- **Options.** Overlay only, no verdicts: closed one-hand, open two-hand, book, laptop. Label it "our model, not measured".
- **Justified by.** 05 §1. **Effort.** S.

## B14 · Keyboard and composer per pose
- **Question.** "Where does my text field end up when the keyboard is up, in each pose?"
- **Options.** *Keyboard safe area (default)* — **Recommended.** · *Fixed keyboard height guess* — **Avoid.**
  · *Composer with fold margin in laptop pose* — **Consider** (only if capture shows it in the curve).
- **Needs.** A capture of the keyboard in book (split) and laptop (bottom half) poses first.
- **Justified by.** 05 §2; 06 row 21. **Effort.** S–M.

## B15 · Camera screen layout per pose (placeholder preview)
- **Question.** "Where do preview and shutter go, closed, open, book and laptop?"
- **Options.** *Overlay arrangement: preview up, controls down in laptop; controls trailing in book* —
  **Recommended.** · *Same full-screen preview with floating controls* — **Consider.**
  · *Shutter in the inner camera area* — **Avoid.**
- **Note.** Gradient placeholder; camera APIs (virtual front camera, direction coordinator, capture
  accessory) go in BuildNotes only.
- **Justified by.** 05 §5; 06 rows 4, 22. **Effort.** M.

## Not in the backlog, on purpose

- Pointer/hover lab: standard controls cover it, and the Duo needs AssistiveTouch for a pointer (05 §4).
- Two-page reading as a default: kept as an effect only (06 row 6).
- Spanning "extended canvas": nothing Duo-specific to show (06 row 20).
- Haptic on every fold: we recommend against it (03 §5).

## Sources

All rationale is in docs 00–06; each item names its section. Apple quotes used directly here:
[HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).
Option verdicts are **our view** built on those sections.
