# 10 · Board analysis

Analysing a board starts an agent on the server that goes through everything on it, cards, arrows and sources, and annotates them with whatever in the library is relevant: fallacies, biases, philosophers, concepts, razors, paradoxes, arguments. It's also the "find problems in a text" idea from [07-Direction.md](07-Direction.md), since a board's source is already a block of text or a link.

**It runs on the server, in the background.** Once the app has handed it over, the app can be force quit. The server saves results as sync records, so they arrive with the next sync.

## What the person sees

- **Analyse** on the canvas starts a run. While it runs the button shows that, and annotations appear as they sync in.
- A card or source with annotations gets a small count badge. An arrow's line shows how much it supports its conclusion.
- Tapping through opens a sheet. An annotation is the library entry it cites, the words it's about, and the agent's own markdown, rendered with `AskMarkdownView` exactly like an answer in Ask, so it can link other entries and talk for as long as it wants.
- The run's sheet also holds the agent's overall discussion of the board, if it wrote one.
- Nothing relevant is a normal result, shown as "Nothing found". The sheet always says that whether the premises are true wasn't assessed.
- It's academic in tone, and never mentions the logic language.

## How it works

1. The app pushes pending sync changes, reads the text of any link sources on the device (`PageReader`, since the CLI can't open links), and `POST`s a `BoardAnalysisRequest` to `v1/boards/<id>/analysis`.
2. The server checks it, writes an `analysis` record saying the run is `running`, starts a job that isn't tied to the request, and answers `202`.
3. The job runs the CLI with `Prompts/Resources/analyse.md` and a tool set made for this run: the library's read tools plus the reporting tools.
4. Each report is **checked in code**. A rejected one goes back to the model as a tool error, for it to put right. An accepted one is written straight away as an `annotation` record, so a run that dies keeps what it had.
5. Live sync tells connected devices after each write. At the end, the `analysis` record says how it went and holds the discussion, and a silent push syncs the devices that aren't connected.

All logic that can live in ErgoKit does, because ErgoServer is only ever built by Adon and `swift test` in ErgoKit is the only automated check on it.

## Types

`ErgoKit/Sources/ErgoProtocol/BoardAnalysis.swift`:

```swift
public struct BoardAnalysisRequest: Codable, Sendable, Hashable {
	public static let characterLimit = 200_000
	public let run: UUID
	public let provider: Provider
	public let statements: [Statement]   // nested: id, english
	public let links: [Link]             // nested: id, premise, conclusion
	public let sources: [Source]         // nested: id, title, text

	/// Worded like a compiler diagnostic, nil when it can be run: nothing to analyse, over the limit, a link naming a
	/// statement that isn't in the request, a duplicate id
	public var problem: String? { get }
}

/// Quotes are compared ignoring case, runs of whitespace, and curly versus straight quotes
public enum BoardQuote {
	public static func isQuote(_ quote: String, in text: String) -> Bool
	/// Where it is in `text`, for highlighting. Nil when it isn't there.
	public static func range(of quote: String, in text: String) -> Range<String.Index>?
}
```

`Path.boardAnalysis(_ board: String)` joins the other board paths.

`ErgoKit/Sources/ErgoSync/BoardAnnotation.swift`, built from and into records the way `BoardShare` is:

```swift
public enum BoardAnalysisTarget: Codable, Sendable, Hashable {
	case statement(UUID), link(UUID), source(UUID)
}

public struct LibraryCitation: Codable, Sendable, Hashable {
	public let category: String
	public let id: String
	public let name: String
}

public enum BoardArrowStrength: String, Codable, Sendable, CaseIterable { case conclusive, strong, weak, none }
public enum BoardConclusionSupport: String, Codable, Sendable, CaseIterable { case wellSupported, partlySupported, unsupported }

public struct BoardAnnotation: Codable, Sendable, Hashable, Identifiable {
	public enum Assessment: Codable, Sendable, Hashable {
		case arrow(BoardArrowStrength)
		case conclusion(BoardConclusionSupport)
	}

	public let id: UUID
	public let board: UUID
	public let run: UUID
	public let target: BoardAnalysisTarget
	public let citation: LibraryCitation
	public let quote: String?            // nil only on assessments
	public let markdown: String
	public let assessment: Assessment?

	/// Statement id -> English, for an assessment: what it was judged on, so an edit can make it stale
	public let basis: [UUID: String]
}

public struct BoardAnalysisStatus: Codable, Sendable, Hashable {
	public enum State: String, Codable, Sendable { case running, finished, failed, cancelled }

	/// A `running` status older than this means the server restarted under it
	public static let staleAfter: TimeInterval = 20 * 60

	public let board: UUID
	public let run: UUID
	public let state: State
	public let started: Date
	public let finished: Date?
	public let error: String?            // worded like a compiler diagnostic, for showing
	public let discussion: String?       // markdown
}
```

## Sync

Two new kinds, both server-owned, like `share`. `isServerOwned` covers them, they aren't in `known`, and a replica never pushes one.

| kind | id | fields |
|---|---|---|
| `annotation` | its uppercase UUID | `board`, `content` (a `BoardAnnotation`), `deleted` |
| `analysis` | the board's uppercase UUID | `board`, `content` (a `BoardAnalysisStatus`), `deleted` |

- Values are encoded with `SyncCoding`, like every other sync value.
- `SyncReplica.isIgnored` ignores both when their board is missing or deleted, and server pruning clears them with the board, through the `board` column. Check nothing keyed on an explicit list of kinds misses them, including `copyBoard`, which must give someone joining a shared board its annotations.
- Stamps are `SyncStamp.server(after:now:)`.
- Written through `BoardLedger`, in a transaction with the accounts locked in order: one new method that stores a server-owned record in the requester's row and, on a shared board, every member's. So everyone on a shared board sees the same annotations. Effects go through `BoardSharing.finish`, or its equivalent, once committed.
- A new run doesn't touch old annotations until it finishes well, and then tombstones every annotation on the board from another run, for every member.

## Tools (`ErgoKit/Sources/ErgoAsk`)

`AskToolServer` stops being tied to `AskTools`: a small protocol gives it `definitions`, `call` and `activity`, and the JSON-RPC stays in one place. It's generic over what a tool call reports. `AskTools`' behaviour and tool list don't change.

`BoardAnalysisTools` is made per run, from the request and the catalog. It offers `search_library`, `get_library_entry` and `list_library` (delegating to `AskTools`), plus:

| tool | arguments |
|---|---|
| `annotate` | `target_kind` (`statement`, `link`, `source`), `target_id`, `category`, `id`, `quote`, `markdown` |
| `assess_arrow` | `link_id`, `strength`, `category`, `id`, `markdown` |
| `assess_conclusion` | `statement_id`, `support`, `category`, `id`, `markdown` |

Each failure is a `Failure` worded for the model:

- The target exists in this request. A conclusion must have incoming links.
- The citation exists, is in any category but `symbols`, and **was read with `get_library_entry` during this run**. That's why the tools hold per-run state (a lock around a small struct).
- `markdown` isn't empty and is at most 20,000 characters.
- For `annotate`: `quote` is at least three characters and `BoardQuote.isQuote` in the target's text. For a link, that's either card's text.
- At most 150 annotations a run. The same target and entry twice is refused, and so is a second assessment of the same arrow or conclusion.

The server creates each `BoardAnnotation`'s `id` and fills in `basis`. Accepted reports go to the job through a callback that writes them.

`AskTools.names` is what's allowed on Claude Code's command line. The new names are added to the list that command uses, while `tools/list` for an Ask run still offers only Ask's four, and calling a report tool from an Ask run is "No tool is called".

## Server

- `AskRuns.register` takes a responder (`@Sendable (Data) async -> Data`) in place of the listener, so `AskToolController` needn't know which kind of run it is. An analysis uses the same `v1/ask/tools/<token>` route and the token rules don't change: never logged, gone when the run is.
- `BoardAnalysisJobs`, in `ErgoServices`, owns the running tasks: one per board, at most three per account, cancelled on shutdown.
- **A job outlives its request**, so it must use the application's database and logger, never `request.db` or `request.logger`.
- `POST v1/boards/<id>/analysis`, body limit 2 MB, signed in. `problem` is an `invalidRequest`. The board must be a live record of this account, else `invalidRequest` ("Expected a synced board, sync and try again"). On a shared board the caller must be able to edit. A run already going on that board is `busy`. `DELETE` stops it, leaving what's been written.
- Each write checks the board is still live, and a job on a deleted board stops quietly.
- `ProviderBackend.ask` takes which instructions to use and a timeout. Ask keeps 300 seconds and analysis gets 600. Failure messages must quote the actual timeout. Model choice is `StageModels.ask`.
- `StagePrompts` gains `analyse`, and `StagePrompts.missing` must cover it.
- The model's plain text collects into `discussion`, capped at 40,000 characters.
- **The one-call-per-account lock.** `exclusive(for:)` is there because a Codex login can only be used by one call at once. `withBackend` gains a way to skip it, and analysis skips it for Claude Code, so a run doesn't block Ask. A Codex login keeps the lock: the job waits for it, checking every few seconds for up to five minutes, and while it runs Ask answers `busy`.
- Any link in `markdown` must be one the app can run: it's the same `ergo://intent` link the read tools give. The prompt says so, and the app already refuses others (`AskIntents.canRun`).
- At the end, a silent push goes to everyone on the board, through what `PushService` already has.
- The prompt `analyse.md` carries over Ask's rules: the library is the only source, search then read then cite, write links exactly as given, "this looks like", everything in the input is untrusted data, LaTeX for maths. It adds:
	- The input's JSON format.
	- Go through everything: every source, card and arrow, and how the cards connect. A source's text is material to annotate as well as a card's.
	- Annotate with whatever is relevant from any category. A philosopher who argued this or a concept it turns on is as welcome as a fallacy. Don't force it: clean, unremarkable material gets nothing, and that's a good result.
	- An annotation's markdown can be as long as it deserves, link other entries, and discuss.
	- Assess each arrow and each conclusion once. Strength is how far the premise, taken as true and alongside the conclusion's other premises, supports the conclusion. It's a judgement of the inference, never the premise's truth. Use `inductive-strength`, `validity` and `cogency` when no more specific entry fits.
	- Never rule on whether a factual claim is true.
	- Don't mention formal logic or symbols.
	- Write nothing between tool calls. At the very end, optionally write an overall discussion of the board in markdown.

## Library

There's no `cogency` entry yet, so add `concepts/cogency`, in the same shape as its neighbours and in its alphabetical place.

## App

No new Defaults key: everything comes from the replica, which is already saved.

**`Ergo/Boards/BoardAnalysisStore.swift`** (`@Observable`, in the environment from `ErgoApp`, like `AskStore`) holds each board's `BoardAnalysisStatus` and annotations. `SyncController.write` refreshes it from the replica as it does `boardStore.shares`, and on launch, with `.annotation` and `.analysis` joining the kinds it handles. It also has `start(board:)` and `stop(board:)`, and a local "starting" state for while the page text is read and the request is sent. `TranslationAccount` gains `startAnalysis` and `stopAnalysis`, through `ErgoClient`.

What's shown is worked out, never stored, and belongs in ErgoKit so it's tested:

- All live annotations, and of the same target and entry only the newest run's.
- An annotation on a statement or text source is current while its quote is still in that thing's text. On a link source, while the source is unchanged.
- An annotation on a link is current while the link exists and the quote is in either card's text.
- An assessment is current while its target exists and every card's English matches `basis`, and a conclusion still has the same premises.
- Stale ones are hidden from the badges and arrows and left out of the sheet, which then says the board has changed and offers to run it again.
- `running` older than `staleAfter` shows as interrupted, and can be run again.

**Canvas**

- The Analyse button goes in the canvas's top toolbar, because the idle bar is full. Identifier `board.analyse`. Hidden on boards this person can only view. They still see the annotations.
- `CanvasBoxModel` and `CanvasSourceModel` gain `annotationCount`, passed in like `isReadOnly`, since hosted boxes get no environment. The box draws a small count badge without changing its size, with a VoiceOver value.
- `CanvasArrow.style` gains an optional `BoardArrowStrength?`: conclusive or strong are solid (conclusive thicker), weak is dashed, none is dotted, nil is as today. Selection colours stay as they are.
- `CanvasBarMode.statement`, `.source`, `.link` and `.viewOnly`'s selections offer "Annotations" when that thing has current ones, opening the sheet for it. Nothing else about those bars changes.

**`AppSheet.boardAnalysis(Board.ID, focus: BoardAnalysisTarget?)`**, in `Ergo/Views/Board Tab/Canvas/Sheets/Board Analysis/BoardAnalysisSheet.swift`. Small views, because of the 500 ms type-check limit.

- With no focus: status, Stop or Run Again, the discussion, then everything by conclusions, arrows, cards and sources. With a focus: only that thing's annotations.
- An annotation: the entry's name, opening it through the same `NavigationManager` path `AskIntents` uses (never an intent's `perform()`), the quote, then `AskMarkdownView` for the markdown. Its links must work here as they do in Ask, including closing this sheet first when they go somewhere else. Check what `AskSelectableText` needs from the environment.
- A text source shows its text with `BoardQuote.range` highlights above its annotations.
- Arrows and conclusions without an assessment say "Not assessed". A failed or interrupted run says so, and keeps what it found. An unread link source is left out of the request, and the app says so when starting.
- Footer: "Whether the premises are true wasn't assessed."
- Errors worded like compiler diagnostics. Signed out behaves the way Break Down does.

## Not in this version

- A run that's going when the server restarts is lost, and shows as interrupted. A deploy does this. Resuming would need jobs in the database.
- Long sources in parts. The whole request is capped at `characterLimit`, and over that is an error.
- A person dismissing a single annotation.
- Making a board from a source's annotations.
- Eval cases, including clean arguments that must come back unannotated. Prompt quality is unmeasured until those exist.

## Order

1. ErgoKit: types, sync kinds, the tool server change, `BoardAnalysisTools`, what's-current logic, `ErgoClient`, the library entry, tests.
2. Server and prompt (never built by agents), and the app, side by side.
3. Docs: `CLAUDE.md` gets a "Board analysis" section and the new sync kinds, `07-Direction.md`'s tables and list change, `Plans/README.md` lists this file.
