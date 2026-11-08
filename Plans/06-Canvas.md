# 06 · Canvas

> **Historical.** Built, then changed by [08-Tabs.md](08-Tabs.md): statements are English only, logic lives in scratchpads, and `ArgumentText` and the checks on the canvas are gone. "Nothing here is built yet" below dates from before any of it.

The canvas replaces the single English-over-logic screen. A board becomes a map of **statements** joined by arrows. You pinch into a statement to edit it (the screen the Check tab has today, for one statement) and pinch out to see the whole argument. Nothing here is built yet.

No migrations: nothing is shipped and the server doesn't exist yet, so `LogicBoard`, the sync records and the server change freely. Boards already saved in Defaults on Adon's devices will fail to decode and be dropped.

## The shape

- A **board** is a canvas. It keeps its `id`, dates and `descriptors`. It no longer has `english`, `logic`, `source` or `translation`; those move onto statements.
- A **statement** is one claim: `english`, `logic`, `source`, `translation` (all exactly what the board has today, but for one claim) and a `position`.
- A **link** is an arrow from one statement to another, meaning "this is a premise of that". One kind only. Objections, "implies" and other kinds are dropped: logic already has `→`, and the checker only understands premises and a conclusion.
- There is no stored "conclusion" flag. A statement with incoming links is the conclusion of those premises; a statement with no outgoing links is a final conclusion. Drawing the arrows is how you mark it.
- **Descriptors and letters stay per board**, shared by every statement. That is what makes links meaningful: `P` in one box is the same claim as `P` in another, so premises can actually entail a conclusion. It also means the six letters and the checker's 12-atom limit are board-wide.

```swift
struct LogicBoard {          // Ergo/Boards
	var id, created, modified, descriptors
	var statements: [Statement]
	var links: [Link]
}
struct Statement: Identifiable {
	var id: UUID
	var position: CGPoint        // canvas coordinates
	var english: String
	var logic: [LogicKeyboardEntry]
	var source: Source           // .english or .logic, as the board had it
	var translation: Translation?
}
struct Link: Identifiable { var id: UUID; var premise: UUID; var conclusion: UUID }
```

The pure parts live in `ErgoKit/ErgoLogic` (a `Canvas/` folder) so `swift test` covers them: the model and a validator (no dangling, duplicate or self links; no cycles), auto-layout, arrow geometry, and the text conversions below.

## Zooming between canvas and statement

- The canvas is boxes on a dot grid, panned with one finger and zoomed by pinch. Each box shows the English, or the logic when there is no English, and a small status.
- Tap a box, or pinch in on it, to open the **statement editor**: today's CheckTabView, pointed at one statement instead of the board (English box, logic box, keyboard, translate, issues, analysis). Pinch out, or tap back, returns to the canvas.
- Try the system zoom transition first (`matchedTransitionSource` with `.navigationTransition(.zoom)`) so the box visibly grows into the editor, plus a `MagnifyGesture` on the editor that dismisses on a pinch-out. If the pinch feels wrong on a device, fall back to a button and the transition alone. This is the main thing I can't verify without a device, so it is a spike at the start of the app phase.
- The statement editor is extracted from `CheckTabView` rather than rewritten, so the focus handling, dither background, keyboard, translation and Stop all carry over. `CheckTabView` becomes the canvas and owns navigation to it.

## Text, and my recommendation: yes, as a sheet, not a mode

Letting people type a whole argument is worth keeping, but not as a permanent third mode. The board already fought over which of English and logic is the source; a text mode for the whole board would add a third thing to keep in step. So **the statements are the only source of truth**, and text is a way to edit all of them at once:

- **Edit as text** (toolbar): one block, a statement per line, with a final `∴` or "therefore" line for the conclusion, in English or in logic (the parser's own format: commas or new lines, then `∴`). Applying it matches lines to existing statements in order, so unchanged lines keep their position and links, new lines become new boxes placed next to the conclusion and linked to it, and removed lines delete their box. The canvas to text direction is the same format, written out.
- **Type to add:** a field at the bottom of the canvas. Return adds a statement beside the selected one and links it as a premise if the selection is a conclusion. This is the quick way to build a map from the keyboard.
- **Break down an argument:** paste English into a sheet and run the server's breakdown stage, which already returns premises, conclusion and claims. The result becomes statements plus links (every premise to the conclusion) and fills the descriptors. No local guessing about where sentences end.

## Translating and checking

- **Translate** is per statement, with the existing gate, formalize and verify stages. One server change: formalize must be told the board's existing descriptors ("these letters already mean this") so a new statement reuses `P` for the claim already called `P` instead of inventing its own. The `TranslationRequest` gets a `descriptors` field (check the current shape in ErgoProtocol first).
- **Break down** is a new request kind that runs only the breakdown stage and returns its output (plus claims as descriptors). The WebSocket protocol gains a scope, `statement` or `argument`. Stage names stay as they are.
- **Checking** reuses `LogicChecker.analyze` unchanged. For each statement with incoming links, build entries as `premise₁, premise₂ ∴ conclusion` from the linked statements' logic and show the verdict as a badge on the box (valid, invalid with the matched fallacy, can't tell, or "doesn't parse"). Tapping the badge opens the same analysis view as today. Chains work naturally: `A → B` and `B → C` check as two small arguments.

## Sync

Two statements edited on two devices must not conflict, and dragging a box must never clash with typing in it. So statements and links are their own records, not fields of the board:

| kind | id | fields |
|---|---|---|
| `board` | board UUID | `created`, `descriptor.N`, `deleted` (no more `content`) |
| `statement` | statement UUID | `board`, `position`, `content` (`english`, `logic`, `source`, `translation`), `deleted` |
| `link` | link UUID | `board`, `premise`, `conclusion`, `deleted` |

- Per-field last-writer-wins as now. A simultaneous edit of one statement's `content` gives a conflict copy of that statement only, placed beside it.
- Deleting a board tombstones it; its statements and links are then ignored on read and pruned. A link whose statement is gone is ignored.
- Server: add `statement` and `link` to `SyncKind.known`, with `fieldNames` and `isValid(id:)`; drop `content` from `board`; raise `recordsPerAccount` (10 000 is too tight when every box is a record; 50 000). Size limits stay per field. Update pruning, the tests, and `05-Sync.md`.
- Position is written when a drag ends, encoded with `SyncCoding`.

## Rendering

SwiftUI's `Canvas` can't take gestures, accessibility or text per element, so: boxes are normal views inside one container carrying the pan offset and zoom scale, arrows are drawn behind them in a single `Canvas`, and the grid behind both. `body`s stay small (the 500 ms type-check limit): `CanvasView`, `StatementBoxView`, `LinkLayer`, `CanvasGrid`, `CanvasToolbar`. Arrows are made by selecting a box, tapping **Connect**, and tapping the target; dragging from a handle can come later. A floating bar offers Connect, Delete and the statement's checks. One undo step per drag or edit.

Accessibility: each box is an element reading its text, whether it is a conclusion and what it connects to, with custom actions Edit, Connect to, Delete; arrows are described from the boxes. Reduce Motion is honoured for layout animation.

## Files

```
ErgoKit/ErgoLogic/Canvas/    Statement.swift, Link.swift (or LogicMap.swift), CanvasLayout.swift, CanvasGeometry.swift,
                             ArgumentText.swift (text <-> statements), ArgumentEntries.swift (links -> checker entries)
ErgoKit/ErgoSync, ErgoProtocol   new kinds, request scope, descriptors on the translation request
ErgoServer                       kinds, limits, breakdown scope, prompt change for descriptors, tests
Ergo/Boards/                      LogicBoard restructured; BoardStore edits statements and links
Ergo/Sync/                       BoardRecord split into board, statement and link records
Ergo/Views/Check Tab/            CheckTabView = canvas; StatementEditorView (extracted); Canvas/ views; EditAsTextSheet; BreakDownSheet
Ergo/Other/Defaults.swift        no new key needed for v1 (the canvas is the board; no mode to remember)
```

CLAUDE.md changes with it: the "never rename" rule moves from `LogicBoard` to `Statement` once this ships, and the Logic editor and Sync sections describe statements.

## Phases

1. **ErgoKit model and logic**, all testable with `swift test`: statements, links, validator, layout, geometry, `ArgumentText` round trip (including keeping identity when lines are unchanged), `ArgumentEntries`.
2. **Sync and server**, testable with `swift test` and needing no deployment: new kinds, split board record, limits, pruning, conflict copy per statement, then the protocol scope and the descriptors change with prompt updates. Update the eval corpus runner for the new request shape.
3. **App, local first:** restructure `LogicBoard` and `BoardStore`, extract `StatementEditorView`, build the canvas, run the zoom spike, then Edit as text and Type to add. Debug and Release builds only; Adon tries the gestures on a device.
4. **Checking on the canvas** (badges and analysis) and **Break down** from the app.
5. Later: drag from a handle to link, image export, a library fallacy drawn onto the canvas as a template.

## Still genuinely open

- Whether pinch-out-to-dismiss feels right on a device. That's the spike, not a decision to make now.
- How big a board can get. Suggested cap: 60 statements, enforced when adding.
- Whether a statement may be a whole `P ∴ Q` argument or must be a single formula. Plan assumes a single formula (links carry the structure), and the box shows "doesn't parse as one statement" otherwise.

## As built (phase 1)

`ErgoKit/Sources/ErgoLogic/Canvas/`, tested by `ErgoLogicTests` (`ArgumentMapTests`, `ArgumentEntriesTests`, `ArgumentTextTests`, `CanvasLayoutTests`, `CanvasGeometryTests`).

| file | contents |
|---|---|
| `CanvasTypes.swift` | `CanvasPoint`, `CanvasSize`, `CanvasRect` (no CoreGraphics: the server builds ErgoLogic on Linux) |
| `ArgumentNode.swift` | `ArgumentNode` and `ArgumentLink` protocols, plus plain `ArgumentStatement` and `ArgumentLinkValue` |
| `ArgumentMap.swift` | `ArgumentMap<Node, Link>`: `premises(of:)`, `conclusions(of:)`, `isConclusion`, `isFinalConclusion`, `roots`, `finalConclusions`, `reaches`, `topologicalOrder` |
| `ArgumentMapValidator.swift` | `validate(_:maximumStatements:)` (default 60), `problem(adding:to:)`, `ArgumentMapProblem` with `message` |
| `ArgumentEntries.swift` | `build(for:in:)` and `check(statement:in:)`; `ArgumentEntriesProblem` |
| `ArgumentText.swift`, `ArgumentTextApply.swift`, `ArgumentContent.swift` | `order`, `entries(for:)`, `text(of:kind:letters:)`, `apply(text:kind:letters:to:)`, `apply(entries:to:)`, `ArgumentTextChange`, `ArgumentTextProblem` |
| `CanvasLayout.swift` | `positions(for:)`, `arranged(_:)`, `place(newNodeNear:in:side:)`, box size and spacing constants |
| `CanvasGeometry.swift` | `exit(of:toward:)`, `arrow(from:to:)`, `distance(from:to:)`, curve control point and distance |

Decisions where the plan was open:

- **Generic over protocols.** ErgoLogic can't see `Translation`, so the app's `Statement` and `Link` conform to `ArgumentNode` and `ArgumentLink` (both `Sendable`, so the app's types must be `nonisolated`). `ArgumentNode` needs `init(id:position:english:logic:)` so text can create statements; the app fills in `source` and `translation` afterwards.
- **`position` is the centre of the box**, so arrows run centre to centre. `CanvasLayout.boxSize` (220 × 96) is what layout and free-space search assume; the app should draw boxes that size.
- **Order for text and matching:** topological, ties by position (top to bottom, then left to right, then listing order). The map's last final conclusion moves to the end and is the `∴` line. Statements with no content for the chosen kind are left out of the text and left alone by `apply`.
- **Matching is not purely positional.** `apply` first anchors lines that equal an existing statement exactly (longest common subsequence), so deleting a line in the middle doesn't rewrite everything below it; leftover lines and statements between anchors are paired in order (edits). A conclusion line is paired with the map's conclusion directly. Moving a line counts as delete plus add.
- **New statements** are placed around the conclusion (above it, below the lowest statement when the conclusion itself is new) and linked to it. When the conclusion had no premises yet, every line above it is linked. With no `∴` line nothing is linked. On an empty map the whole result is auto laid out. A link that would form a cycle is skipped.
- **English conclusion lines** start with `∴`, `Therefore`, `Hence` or `Thus` (any case, comma optional). The text after the marker is stored as written, with no case change, so `Therefore, The ground is wet.` round trips. Limits: a premise whose English starts with one of those words, and logic holding its own comma, new line or `∴`, read back as something else.
- **Logic text** splits like `LogicParser` but keeps lines that don't parse, so a typo never deletes a box. `∵` is refused (`ArgumentTextProblem.unsupportedMarker`).
- **`apply` returns `ArgumentTextChange`** (`map`, `edited`, `added`, `removed`) rather than a bare map, so the app can mark the other field of an edited statement stale and drop its translation.
- **Checking** (`ArgumentEntries`) lists premises in the same reading order as `ArgumentText`, and returns their ids so `LogicFallacyMatch.premises` indices map back to boxes. A statement must be exactly one parsing formula, else `doesNotParse` or `notOneStatement`; empty logic anywhere gives nil rather than an error.
- **Layout** ignores current positions (tie-break is listing order), so it is deterministic and idempotent. Premises are in layers by longest path, running top to bottom; each row is centred on the average of its premises, and a layer wider than three boxes wraps onto more rows. Each box then sits a little off its spot, by an amount hashed from its id, so it looks organic but comes out the same every time and on every device.

## As built (phase 2): sync, server and protocol

Done in `ErgoKit/ErgoSync`, `ErgoProtocol`, `ErgoTranslation`, `ErgoClient`, `ErgoServer` and `Evals`. Nothing under `Ergo/` or `ErgoLogic` changed, so the app still compiles against the old shapes and doesn't use any of this yet. The detail is in `05-Sync.md` (records, cascade, limits) and `02-Server.md` (the translate socket).

**Sync**
- `statement` and `link` are in `SyncKind.known`, with the fields in the table above. `board` lost `content` on the server (`SyncFieldName.content` stays: statements reuse it). `SyncFieldName` gained `board`, `position`, `premise`, `conclusion`. Statement and link ids are uppercase UUIDs, like boards.
- `SyncLimit.recordsPerAccount` is 50,000. Per-field limits are unchanged.
- The conflict copy needed no new protocol: `SupersededField` already names a kind, id and field. `SyncApplied.superseded(.statement, field: SyncFieldName.content)` is the "lost content of this statement" the app asks for. A move and an edit of one statement never conflict, since they are different fields.
- Cascade, as designed: a statement or link whose board is deleted or missing, or a link whose statement is, is ignored on read (`SyncReplica.isIgnored(_:)`, `ignored`). The server prunes them with the board's tombstone, and prunes statements and links with no board record after 90 days. Deviations and additions:
  - The server keeps the owning board's id in a new clear `board_id` column on `sync_records` (migration `AddSyncRecordBoard`), so pruning needn't open sealed rows. It is the same kind of metadata as the record id.
  - Pruned leftovers don't move `Account.prunedThrough`; only tombstones do.
  - `SyncReplica` also drops a pruned board's statements and links, and stops pushing ignored records after a reset, so a pruned orphan can't come back.
  - **Behaviour change:** typing in a statement no longer revives a deleted board, because the text isn't the board's own field any more. Editing a statement while the board is deleted elsewhere loses the edit (the undo is a newer `deleted: false`, which brings the statements back too). Accepted for the simpler records; if it hurts, the app can write a board field when it edits a statement.
  - A link whose statement was deleted but whose board lives is ignored, not pruned. The app is expected to delete a statement's links with it.

**Translation protocol**
- `TranslateRequest` gained `descriptors: [String]?` and `scope: TranslateScope` (`statement`, `argument`), both defaulted and optional on the wire, so the old app's requests decode as before.
- **Deviation: the argument scope has its own answer type.** The plan said "a new TranslationEvent case (or a result payload)". An extra case on `TranslateServerMessage` or `TranslationEvent` would stop the app's exhaustive switches compiling, so `.argument` answers with `BreakDownServerMessage` (`event`, `finished(ArgumentBreakdown)`, `failed`), which codes like `TranslateServerMessage` for the two shared cases. `ErgoClient.breakDown(_:)` is the argument client; `translate(_:)` always runs the statement scope.
- `ArgumentBreakdown` (ErgoTranslation): `kind` (`argument` or `statements`, or `neither` with an error issue), `premises`, `conclusion` (empty when none), `claims`, `descriptors` (six, the board's own plus the new claims in free slots) and `issues`.
- **Descriptors are assigned in code, not by the model.** After breakdown the pipeline matches each claim's descriptor to an existing one (case-insensitive) to keep its slot, and gives new claims the free slots in order; more new claims than free slots is an error issue. Breakdown is told the existing descriptors and asked to reuse them as labels; formalize is told each claim's letter and the letters the board already names, and a formula using any other letter is a compile error sent back for a retry. With no descriptors the behaviour is exactly what it was.
- Stage names are untouched. `TranslationPipeline` gained `descriptors` and `breakDown(_:events:)`; its `events` parameters are now `@escaping`, which is source compatible.
- Input limits for both scopes: `EnglishValidator` (1,500 characters) answers with an issue and no model call, descriptors are at most six of at most 32 characters (`.invalidRequest`), and the grammar must match.

**Evals:** the runner sends `scope: .statement` and, per case, an optional `descriptors` (absent in the whole corpus). Corpus validation checks the descriptors' count and length.

**What the app now has to change** is listed in the phase 2 report: `BoardRecord` split into board, statement and link records (the server now refuses `content` on a board), the conflict copy per statement, ignoring orphans, and the new request fields once the canvas sends them.
