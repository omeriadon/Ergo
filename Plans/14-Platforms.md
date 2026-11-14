# 14 · Platforms

iPad, Mac and one day the Watch: how one app draws itself on every size of screen.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## Two layouts, chosen by width

**Decided:**
- The app has a narrow layout and a wide one, and the window's width alone chooses: `horizontalSizeClass`. Narrow is today's tab bar, stacks and sheets. Wide is a sidebar, the open item beside it, and an inspector.
- No device checks. An iPhone Pro Max in landscape and a foldable iPhone follow width like an iPad does. An iPad in Slide Over or a small window gets the narrow layout. A Mac window is always wide.
- So there's no separate Mac shell. The Mac is a device that's always wide.

Why: an iPad resizes live in Stage Manager and split view, so a layout per device would be wrong half the time, and a foldable iPhone is both.

## One model, two drawings

**Decided:** navigation state belongs to neither layout. Each layout is only a way of drawing it, so a window that's resized mid-task keeps the same board, chat or panel.

| State | Narrow | Wide |
|---|---|---|
| The section (Board, Logic, Ask, Library) | the selected tab | the sidebar section |
| The open item (a board, a scratchpad, a chat, a library page) | pushed on the tab's stack | selected in the sidebar |
| The side panel (findings, Ask about this board, people) | a sheet | the inspector |
| Settings | a sheet | the open item, from a button pinned under the sidebar |
| Editing a card | the box zooms to fill the screen | the box grows into a bigger card over the canvas |

- The sidebar's selection is worked out from that state, never kept apart from it, so intents, links and the narrow layout moving things keep it right.
- Real tasks (Break Down, sharing in) stay sheets in both. Settings isn't one in wide: a separate window or a sheet over the board feels like leaving the app to change something in it.
- Editing a card isn't a sheet in wide either. A sheet would take the window for one sentence; the card keeps the board in view behind it.
- Views are reused, never forked per layout. Where one has to differ, it reads the width itself.

## The sidebar

**Decided:** the wide layout's sidebar is a `NavigationSplitView` with the app's own `List`, not a `TabView` sidebar.

Why: a `TabView` sidebar's rows are a label and a badge, select one thing at a time, nest no deeper than a section, and give each row a whole destination. That suits a handful of places, not a list of boards that wants renaming in place, context menus and selecting several. Mac sidebars are lists of your documents, like Notes and Mail.

Rows are one line, a symbol and a name, as sidebar rows are on the Mac and iPad. Dates and second lines belong to the narrow lists, which have the width for them.

## The Mac

**Proposed:**
- A native macOS target with the same bundle ID, for universal purchase, rather than Catalyst or Designed for iPad. Those would carry the iOS chrome in `Obliterations/` that makes a port look like an iPad app.
- The canvas moves to AppKit. Its layout is already ErgoKit and its cards are already SwiftUI, so the port is mostly input: hover, right-click, trackpad, keyboard.
- Logic is typed on a real keyboard, with a symbol palette in place of the logic keyboard.
- Mac-only: a board in its own window, and maybe a Quick Ask panel. Menu commands, shortcuts, several windows and drag and drop are shared with iPad.
- The toolbar holds only what's used all the time. Undo and redo are the Edit menu's, and the board's other commands are in a Board menu with their shortcuts, so the toolbar never needs its own overflow beside the system's.
- Later: typing straight into the box on the canvas, with no card at all.

## The Watch

**Proposed:** small. The library item of the day as a complication, flashcard review, and Deep Research finishing as a notification. No canvas.
