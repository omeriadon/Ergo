# 08 · Board, Logic, Ask, Library

The first slice of [07-Direction.md](07-Direction.md): the four tabs, with logic moved off the Board and into saved scratchpads. The AI research features, MCP, shared intent functions, analytics, API version changes and account gating are not part of this.

No migrations: nothing has reached v1. Saved logic on boards is dropped. This overrides the "never rename" rules on `Statement` and its neighbours in CLAUDE.md for this work.

## Rules for every phase

- Read `CLAUDE.md` first and follow it. Never touch git state. Never boot a simulator or run the app or UI tests.
- **Never build ErgoServer.** Adon builds it.
- Everyone works in the same checkout, one phase at a time. Adon may have uncommitted edits, currently in `CanvasBox.swift` and `CanvasDropLens.swift`. Read a file right before editing it and keep what's there. Never revert or overwrite anything that isn't part of the phase.
- The app won't compile between phases. That's expected until phase 4.
- Match the surrounding style: tabs, `case` indented in `switch`, small view bodies (500 ms type-check limit).
- When a phase finishes, tick it under Status with a line on anything the next phase must know.

## The shape

**Tabs:** `AppTab` becomes `board`, `logic`, `ask`, `library`, in that order, with Library keeping `role: .prominent`.

| Tab | Label | Symbol |
|---|---|---|
| Board | Board | `flowchart` |
| Logic | Logic | `function` |
| Ask | Ask | `bubble.left.and.text.bubble.right` |
| Library | Library | unchanged |

**Board:** cards and arrows holding English only.
- `Statement` is `id`, `position`, `english`. `logic`, `source` and `translation` go.
- `LogicBoard` is renamed `Board`, and loses `descriptors` and `merge(descriptors:)`. Its title is the first English in reading order, else "Untitled".
- Tapping into a card opens a plain English editor, keeping the zoom and pinch out in `StatementEditorScreen`.
- Verdict badges, the argument check sheet and the letters menu item leave the canvas.
- New Board → Break Down stays and ignores the descriptors that come back.

**Logic:** the old English-over-logic screen, as a list of saved scratchpads.
- The tab's root is a list, newest first, with a New button and swipe to delete. An empty list shows a `ContentUnavailableView`.
- A scratchpad holds a whole argument: `id`, `created`, `modified`, `descriptors`, `english`, `logic`, `source`, `translation`. Its title is the first line of English, else the first line of logic, else "Untitled".
- A new scratchpad stays out of the list until something's written on it, and an emptied one is discarded on leaving, like boards do.
- Its editor is today's `StatementEditorView`, moved over: translate, `LogicAnalysisView`, fixes, the keyboard, English following logic.
- `ScratchpadStore` is modelled on `BoardStore`: `current`, a draft, a paused save, `didSave`, `applyRemote`. The letters sheet edits `scratchpadStore.current.descriptors`.

**Ask:** a placeholder view, replacing Debate. `DebateRoute`, `debatePath` and `.createDebate` go.

**Sync:** a new kind `scratchpad`, with fields `created`, `descriptor.N`, `content` and `deleted`, where `content` carries `english`, `logic`, `source` and `translation`. Two devices editing at once give a conflict copy beside it, like statements. `board` records lose the descriptor fields, and statement `content` becomes just the English.

## Phases

### 1. ErgoKit
- Remove `logic` from `ArgumentNode`, `ArgumentNodeValue` and its `init`. Update `ArgumentMap` and `ArgumentBreakdownApply`.
- Delete `ArgumentText.swift`, `ArgumentTextApply.swift`, `ArgumentContent.swift`, `ArgumentEntries.swift` and their tests. Anything else only they used goes too. `LogicChecker`, `LogicParser`, `LogicEnglish` and `LogicFallacyForm` stay.
- Add `SyncKind.scratchpad` to `known`, `fieldNames` and `isValid(id:)`. Remove the descriptor fields from `.board`.
- Check `ErgoServer/Sources` and `Evals/Sources` by reading only, and fix any use of what was removed. `SyncLimits.swift` validates against `known` and `fieldNames`, so it should pick the new kind up by itself. Check `SyncService.childKinds` too.
- Run `(cd ErgoKit && swift test)` once, with the `DEVELOPER_DIR` from CLAUDE.md.

### 2. Board and tabs (app)
- `AppTab`, `ContentView`, `NavigationManager`, `Defaults`, `AppSheet`, `OpenTabIntent`, `Donations`, and the phrases in `ErgoSiriEvaluationTests`.
- Ask placeholder in `Ergo/Views/Ask Tab/AskTabView.swift`.
- `Statement`, `Board`, `BoardStore`, `BoardRecord`, `StatementRecord`, and `SyncController`'s board parts.
- Strip logic from `StatementBoxView`, `CanvasBox`, `CanvasBoard`, `CanvasView` (including the verdict task and the snapshot near line 723), and `BreakDownSheet`. Delete `BoxVerdict.swift` and `ArgumentCheckSheet.swift`.
- Rewrite `StatementEditorView` as English only. Before doing so, copy the current version to `Ergo/Views/Logic Tab/ScratchpadEditorView.swift` unchanged for phase 3 to adapt.
- Avoid `CanvasBoardView.swift` unless it needs a change for this.

### 3. Logic tab and sync (app)
- `Ergo/Scratchpads/LogicScratchpad.swift`, `ScratchpadStore.swift`. Inject the store in `ErgoApp`, and save it where `boardStore.save()` runs.
- `Ergo/Views/Logic Tab/`: `LogicTabView` (the list) and `ScratchpadEditorView` (adapted from the copy). Add `LogicRoute`, a persisted `logicPath` on `NavigationManager`, and `reset(.logic)`.
- Move `LogicTextEditor`, `LogicKeyboard`, the rest of `Logic Keyboard/`, `LogicAnalysisView` and `EnglishStatusView` to `Ergo/Views/Logic Tab/`, with plain `mv`. The `Ergo/` group is folder-synced, so the project file needs no edit.
- `LogicLettersSheet` uses `ScratchpadStore`.
- `Ergo/Sync/ScratchpadRecord.swift`, and `SyncController` wiring: record, rebuild, conflict copies, deleted while signed out, oversized.

### 4. Finish
- Rename `Ergo/Views/Check Tab/` to `Board Tab/` and `CheckTabView` to `BoardTabView` with plain `mv`. Reword remaining "Check tab" comments and accessibility identifiers that say `check.` to fit.
- Update `CLAUDE.md`: layout, Logic editor, Translation and Sync sections. The "never rename" rule for these types is relaxed until v1. Mark the tabs and scratchpads as built in `07-Direction.md`.
- Build the app once and fix what it finds: `xcodebuild -project Ergo.xcodeproj -scheme Ergo -configuration Debug -destination 'generic/platform=iOS Simulator' build`, with the `DEVELOPER_DIR` from CLAUDE.md. Rebuild only as needed to get to green.

## After this ships

Adon has to rebuild and redeploy ErgoServer, because it validates records against `SyncKind.known`. Until then, scratchpad records get rejected on sync.

## Status

- [x] 1. ErgoKit: `ArgumentNode.init` is now `(id:position:english:)`, and `SyncFieldName.content` is documented as the statement's English or a scratchpad's `{ english, logic, source, translation }`. ErgoServer's `SyncLimits.check(kind:id:)` got `.scratchpad` added to its UUID-message case. `ErgoKit` tests: 273 pass.
- [x] 2. Board and tabs: `LogicBoard` is now `Board` (`Ergo/Boards/Board.swift`, `title` is a property), `Statement` is `id/position/english`, and the canvas, editor, sync records and Break Down are English only. Nothing was built. Phase 3 must know: (a) `ContentView` uses `LogicTabView()`, and `LogicLettersSheet` uses `@Environment(ScratchpadStore.self)` with `current.descriptors`, so `ErgoApp` must inject the store; (b) `Ergo/Views/Logic Tab/ScratchpadEditorView.swift` is a byte copy of the old editor, still `struct StatementEditorView` and still using `LogicBoard`, `boardStore.applyTranslation`, `statement.logic`/`source`/`translation`, so rename it and rewrite it onto `Scratchpad` (a duplicate type name until then); (c) `NavigationManager.reset(.logic)` is a `break` and there is no `logicPath` yet; (d) `EnglishStatusView`, `LogicAnalysisView` and the keyboard are still in `Check Tab/` for the `mv`; (e) `TranslationAccount.translate` is unchanged and still takes `descriptors`; (f) `SyncController` has no scratchpad handling yet.
- [x] 3. Logic tab and sync: `LogicScratchpad` and `ScratchpadStore` are in `Ergo/Scratchpads/`, `ScratchpadRecord` in `Ergo/Sync/`, and `SyncController.init` now takes `scratchpadStore:`. Nothing was built. Phase 4 must know: (a) `LogicRoute.scratchpad` has no id, since the editor follows `ScratchpadStore.current`; `Defaults[.logicPath]` persists it, and `LogicTabView` discards an empty current scratchpad on appearing with an empty path; (b) `ScratchpadEditorView` is the renamed copy, now on `ScratchpadStore`, with `logic.` identifiers (as are the moved keyboard, `LogicAnalysisView` and `EnglishStatusView`); (c) `Ergo/Views/Check Tab/StatementEditorView.swift` still has `check.` identifiers; (d) `SyncController.oversizedBoards` now also lists oversized scratchpads' titles, name kept; (e) `ContentView`'s preview now injects `BoardStore`, `ScratchpadStore` and `TranslationAccount`; (f) the `scratchpads` key is synced by records, `currentScratchpadID` and `logicPath` are this device only; (g) the first build is likely to find type errors, since nothing here was compiled.
- [x] 4. Finish: renamed `Check Tab` to `Board Tab` and `CheckTabView` to `BoardTabView` (identifiers now `board.`), docs updated, and the Debug build of the `Ergo` scheme succeeded with no errors to fix. The app and ErgoServer were not run.
