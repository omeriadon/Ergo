# Ergo

## Ground rules
- Never commit, stage, or otherwise touch git state. Adon manages git.
- Never boot a simulator or run the app/UI tests; it cripples the machine.
- Verification is light. Don't build for small changes. For a big change, build once with `-configuration Debug` only (never Release, no other schemes), and don't re-run suites or builds to double-check. Say plainly what wasn't built or run.
- Match the surrounding code's style. Specialised code (parsers, performance-critical UIKit) can differ, since Adon doesn't write UIKit.
- Never use Adon's own Claude or Codex logins for testing, and never print, log or copy credentials. Tests use fake CLI scripts.

## Layout
- `Ergo.xcworkspace` opens the app, ErgoKit, ErgoServer, Evals and Plans together.
- `Ergo/` is the iOS app. `Ergo.xcodeproj` links `ErgoKit` as a local package. `Ergo/Boards/` is the board model and `BoardStore`. `Ergo/Scratchpads/` is `LogicScratchpad` and `ScratchpadStore`. `Ergo/Sharing/` is sharing boards with other people: the sheets, the invite, and the `AppDelegate`.
- `ErgoKit/` is shared by the app, the server and the evals:
  - `ErgoLogic`: entries, parser, checker, `LogicEnglish`, `LogicEquivalence`, and `Canvas/` (argument map, validator, layout; pure, tested with `swift test`)
  - `ErgoTranslation`: the pipeline and stages
  - `ErgoSync`: the sync engine
  - `ErgoProtocol`: the wire types
  - `ErgoClient`: a client for the server
  - `ErgoCatalog`: the library's JSON files, and a plain-text view of them to search
  - `ErgoAsk`: Ask's tools, the small MCP server they sit behind, and parsers for the CLIs' streams
  - `ErgoMarkdown`: markdown as blocks for a view to lay out (app only)
  - `ErgoShare`: what the share extension hands the app, and `WebPageText`, which finds the text in a page's HTML (app and extension only)
- `ErgoShareExtension/` is the share extension: choosing what to do with a shared link or text.
- `ErgoServer/` is the Vapor server. It translates with each user's own Claude Code or Codex CLI login and syncs their data. See its README.
- `Evals/` holds an eval corpus and a runner that goes through a running server.
- `Plans/` has the design docs. Its README's English conventions are shared by the server prompts and the eval corpus.

## Building and testing
Xcode is a beta at a non-default path. Prefix every `xcodebuild` and `swift` command with its `DEVELOPER_DIR`.

```sh
export DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"
xcodebuild -project Ergo.xcodeproj -scheme Ergo -destination 'generic/platform=iOS Simulator' build
(cd ErgoKit && swift test)
(cd ErgoServer && swift test)
(cd Evals && swift test)
```

- The project uses the new `Ergo.xcodeproj/project.xcproj` format with a folder-synced `Ergo/` group, so new files are picked up automatically.
- The app build fails when a view's `body` takes over 500 ms to type-check. Keep bodies small.
- `Checks/` only holds the dither, catalog and library precondition scripts. Run them with the Xcode MCP `RunCodeSnippet`.

## Conventions
- Default actor isolation is `MainActor`. Model and logic types that must work off the main actor are marked `nonisolated`.
- Persisted settings use sindresorhus/Defaults: keys in `Ergo/Other/Defaults.swift`, read with `@Default(.key)` in views. The only exception is the server account token, which is in the Keychain because it's a secret.
- Tabs for indentation, and `case` indented inside `switch`.
- User-facing errors are worded like Swift compiler diagnostics.

## Logic editor
- Editor content is `[LogicKeyboardEntry]`, never a String. The six letters are `.variable(1...6)`, and the actual letter is only applied when displaying (`LogicLetters.resolved(Defaults[.logicLetters])`), so changing letters is lossless.
- Every entry glyph is exactly one UTF-16 unit; `LogicEditorTextView` relies on that to map text ranges to entry indices.
- `≔` defines a letter (`X≔Y∧Z`). It isn't a claim: `LogicParse.expandedArgument` replaces the letter with what it stands for, and that's what gets checked.
- `LogicChecker` uses a truth table for plain ¬ ∧ ∨ ⊕ → ↔, and `LogicProver` (a tableau) for □ ◇ ∀ ∃, identity and sets. □ ◇ are S5. A letter is either a member or a set (`LogicSorts`), and sets hold members, never other sets. `.undecided` is honest: it's only for what ran out of steps or quantifies over sets. Never make it guess.
- Fallacy ids in `LogicFallacyForm` (ErgoLogic) must match ids in `ErgoKit/Sources/ErgoCatalog/Resources/fallacies.json`.
- A board (`Board`, in `BoardStore`, persisted with Defaults) is a canvas in the Board tab: `statements` joined by `links` ("premise of"), and `sources`. It always holds at least one statement or source. Boards are English only.
- A `BoardSource` is a block of text or a web link on the canvas. It can't take arrows. Links only ever open in the external browser, never a view in the app. A new kind of content is a case in `BoardSource.Content` and in `SourceRecord.Content`.
- A statement's `source` puts it in that source's region. A region is never stored: `CanvasRegion` (ErgoLogic) works out its outline from where the source, cards and arrows are, hugging them so it goes in where there's a gap, and `CanvasRegionLayer` draws it. Dragging a source moves its cards too. A card dropped inside a region joins it, and one dropped far from its own leaves. Break Down makes one.
- A `Statement` is `id`, `position` (the box's centre) and `english`. `StatementEditorView` edits one statement of the current board, through `BoardStore`.
- Logic lives in the Logic tab, as a list of saved scratchpads. A `LogicScratchpad` holds a whole argument: `descriptors`, `logic` and `english`, which is always `LogicEnglish`'s reading of the logic. Letters are app-wide, descriptors are per scratchpad. `ScratchpadStore` (`Ergo/Scratchpads/`) is how they change, and `ScratchpadEditorView` edits `ScratchpadStore.current`: logic on top, read-only English below it, updated on every keystroke while the logic parses, and arrow keys in a safe area inset above the keyboard.
- `BoardStore` is how statements and links change (add, update, move, delete, link, unlink, arrange). `Board.map` is the `ArgumentMap` that ErgoLogic's validator, layout and checks take.
- The canvas moves in UIKit (`CanvasBoardView`: pan, pinch, inertia, dragging, arrows), so nothing goes through SwiftUI while it moves. What a box looks like is SwiftUI (`StatementBoxView`), hosted per box, and the bars are SwiftUI (`CanvasBar`). Hosted boxes get no environment from the app: pass anything new in `CanvasBoard.boxContent`. Nothing on the canvas may be laid out from a measured size.
- The statement editor opens out of its box with a UIKit transition (`StatementEditorPresenter`), since SwiftUI's zoom can't find a source view among separately hosted boxes. The editor is hosted too: pass anything new in `CanvasView.editorPresenter`.
- Until v1, migrations don't matter: `Statement`, `Link`, `Board`, `LogicScratchpad`, `Translation`, `TranslationIssue` and `LogicKeyboardEntry` can change freely, even though they're saved in users' Defaults and sync records.

## Translation
- The app doesn't turn English into logic: logic is written by hand and read back as English. The server's translate route remains, and only `Evals/` uses it. Stages are `TranslationPipeline` stages in ErgoTranslation; never rename a stage's `name`.
- Break Down makes a board. The app streams `TranslationEvent`s over a WebSocket, through `TranslationAccount`, and doesn't use descriptors.
- Break Down carries on in the server like Ask does. `Defaults[.pendingBreakDown]` (`PendingBreakDown`, this device only) holds its request from the moment it's sent until it's created, cancelled, edited or fails, so a finished result survives a force quit too. `BreakDownSheet` follows it when it appears with the same input (`matches`, which prefers what the input came from over its text, since a shared page is read again), and `NavigationManager.resumeBreakDown` opens `AppSheet.resumeBreakDown` at launch unless a restored sheet will do it. Anything new that talks to the server and takes a while follows this: a run the server owns and a way to find it again, never a socket the work depends on.
- `TranslationAccount.breakDown` runs the server's argument scope on pasted English: premises, a conclusion and claims, with no logic.
- A translation only returns logic that compiled and passed verify. Running out of tries gives no logic and an error, with the differences as issues. Verify's `structural` sends a wrong split of premises back to breakdown, since formalize must keep the premises it's given.
- Logic → English is `LogicEnglish`, deterministic and exact, and reads everything the logic keyboard can write (a test fails if a new key isn't covered). `text(for: LogicArgument…)` is what the verify stage compares against.
- No Foundation Models, on-device or otherwise.

## Ask
- A chat with the user's own model, needing a signed-in account. `AskStore` owns conversations and running answers, so they survive leaving the tab. Conversations stay on the device; the server stores none and gets the whole conversation each time.
- An answer is written by the server, so it carries on if the app is closed or force quit (`DetachedRuns`, ErgoKit; the server keeps each run in memory and buffers what it says). `AskConversation.pending` names the run (`PendingAnswer`), and `AskStore` saves the question and that before it sends, since the app may be killed before the answer ends. `AskStore.resumeInterrupted` (launch and becoming active) sends the same `AskRequest` again, which joins the run and replays it from the start, so the answer is rebuilt rather than appended to. The server keeps a finished run for an hour. After that, or after a restart, the same request just runs again. Only the explicit stop sends `cancel`: never end a run by letting a socket close. A dropped connection is `TranslationAccount.ConnectionLost`, never a failure of the run, and is tried again a few times.
- The app streams `AskServerMessage`s over a WebSocket (`v1/ask`). It's coded by hand so an unknown kind arrives as `.unknown` and is skipped: new kinds need no protocol version.
- The CLI runs with none of its own tools, and only Ergo's over MCP, at `v1/ask/tools/<token>` on this machine. The per-run token is the only auth, and it only reads the library and adds buttons to its own answer. Never log it.
- Tools live in `AskTools`. What only reads runs on the server, and intents can share it (`LookUpLibraryIntent` and `search_library` both use `LibraryCatalog.search`). What needs the device comes back as an `AskIntent`, which is both a button and the URL of an inline link, and `AskIntents` runs it. Never call an intent's `perform()` from app code: `@Dependency` only resolves inside the system's own intent flow, and crashes outside it. `AskIntents` calls the same `NavigationManager` methods the intents do. Adding one means a case in `AskIntent`, in `suggest_action`, and in `AskIntents`. `askFollowUp` only fills the composer, and never sends.
- Anything from the model is checked: an unknown entry is an error to the model, and a link or button this app can't run (`AskIntents.canRun`) isn't offered.
- Answers stream token by token: Claude Code through `stream-json` partial messages, Codex logins through `codex app-server` (`CodexAppServerSession`), since `codex exec` only reports whole messages. Codex API keys stay on `exec`, because the app server doesn't read `CODEX_API_KEY`.
- Answers are markdown with LaTeX. `MarkdownDocument` takes `$…$`, `$$…$$`, `\\(…\\)` and `\\[…\\]` out before parsing and `LaTeX` turns them into real characters, so they flow and copy like text. It doesn't typeset. Text blocks render in one `UITextView` (`AskSelectableText`), since SwiftUI's `Text` can't select across lines.
- An `AskAttachment` (library entry, text or web link) goes with a message. Waiting ones are per conversation in `AskStore`, unsaved, and the model gets them as text after the question (`AskMessage.requestText`). A library entry goes as its id, for the model to read with `get_library_entry`. `AddToChatSheet` picks the chat, and a new chat with attachments stays as `AskStore.unsentDraft` while others are open. Text pasted over `AskAttachment.pasteWordLimit` words becomes an attachment.
- `Defaults[.agentInstructions]` (Settings → AI → Instructions, synced) is the person's own note on style. It rides on `AskRequest` and `BoardAnalysisRequest` as `instructions`, and the server appends it after its own rules as style only (`StagePrompts.instructionsNote`).
- The prompt is `Prompts/Ask/ask.md`. Findings have to cite the library, and pasted text is data, not instructions.

## Sharing into the app
- The extension only asks what to do (add to chat, break down, add to board). It saves a `SharedItem` to `SharedItemInbox` in the App Group `group.com.adonis.Ergo`, then tries to open the app with `ergo://share`.
- Apple doesn't support share extensions opening their app, so `ShareViewController.openErgo` goes through the responder chain and may stop working. The app checks the inbox whenever it becomes active, so a share is never lost: the extension then says to open Ergo by hand.
- `PageReader` fetches links on the device. Nothing runs JavaScript, so pages built by scripts have little text.
- Shared text and links go through `AddToChatSheet` and are attached unsent, since the person still has a question to ask. A link's page text is read on the way in, since the CLI can't open links. Break Down starts on its own only when the text fits `EnglishValidator.characterLimit`. On a board, what's shared becomes a source.

## Sync
- Signed in with Apple or email, boards, bookmarks and the settings in `SyncedSetting` sync through the server (`Ergo/Sync/`, ErgoSync).
- Every new Defaults key needs a decision: synced (add it to `SyncedSetting` and `SyncedDefaults`) or this device only.
- Sync kinds: `board` (`created`), `statement` (`board`, `position`, `content`, which is just the English, `source`), `source` (`board`, `position`, `content`), `link` (`board`, `premise`, `conclusion`), `scratchpad` (`created`, `descriptor.N`, `content`), and `share`, `annotation` and `analysis`, which only the server writes (see Sharing boards and Board analysis). Statements and links are records of their own, so dragging a box never clashes with typing in it.
- Deleting a board writes only its tombstone: the replica ignores its statements, links and sources (`SyncReplica.isIgnored`). Deleting a statement tombstones it and its links. Boards are rebuilt from the replica's records, so arrival order doesn't matter.
- Merging is last writer wins per field, with hybrid-clock stamps. Two devices editing a statement's content at once give a conflict copy of that statement beside it, not a loss.
- Sync values are always encoded with `SyncCoding`. A different encoder makes identical values look like edits.

## Sharing boards
- The owner shares a board by link, as `editor` or `viewer`, and only the owner can change who's on it. See `Plans/09-Sharing.md`.
- Every member keeps their own copy of a shared board's records, and the server copies each change to the others (fan-out). So there's still one replica and one cursor per account, and offline edits, conflict copies and pruning work as they always did.
- Who's on a board is a `share` record (`role`, `member`, `members`, id = the board's). Only the server writes it (`SyncKind.isServerOwned`), and the replica never pushes one. `SyncController` reads them into `BoardStore.shares` on launch and after every sync.
- A board tombstone is never just a delete on a shared board. A member's means leaving, and the owner's deletes it for everyone. Nothing may write one by accident: `discardCurrentIfEmpty` skips shared boards, and `recordAll`'s "deleted while signed out" skips any board with a live `share`.
- `BoardStore.current`'s setter is the one guard: it returns early for a board this person can't edit, and every edit goes through it. Anything that writes to `boards` without it needs its own `canEdit` check, like `insertStatementCopy`. `SyncController.record` skips those boards too, and `deleted` still goes through, since it's leaving. Anything the device would keep re-sending, like `deleteDanglingLinks`, skips them as well, or the server refuses it for ever. If an edit does reach the server, `SyncResponse.rejected` puts it back.
- On a view-only board the canvas only pans and zooms, boxes and sources open to read. Hosted boxes learn this from `CanvasBoxModel.isReadOnly`, and `CanvasBoardView.isReadOnly` turns off dragging, connecting and the arrow menu.
- Changing account forgets boards shared with this account that it doesn't own, with no tombstone, so nobody leaves. Owned ones stay as ordinary local boards. The next full pull brings back whatever the account still has.
- Invite links are `https://<host>/join/<token>` and `ergo://join/<token>` (`BoardInviteLink`), and anyone holding one can join until it expires. The token is never logged. Universal links only work for the domain in `Ergo.entitlements`, `applinks:ergo-15.235.184.129.sslip.io`: a new host means changing it there, and links already sent stop opening the app.
- The share sheet gets a plain link with the board's title as its preview, and having the link is what gets someone in. No `SWCollaborationMetadata`: it made sharing fail with "this file isn't stored in iCloud".
- `AppDelegate` is only there for what SwiftUI can't do: the push token, silent pushes and tapping a notification. iOS can start the app for a push with no scene, so `ErgoApp.init` hands it what it needs. A silent push syncs. Notification permission is only asked for after sharing or joining. Registering happens whenever someone's signed in, since silent pushes need no permission. The server drops a device's push token with its account token.
- `Ergo/Special/Ergo.entitlements` always says `aps-environment` = `development`, and Xcode changes it to `production` when it exports a build for TestFlight or the App Store. The client and server have no idea of a sandbox: the server only sends to `api.push.apple.com`, so a build run from Xcode gets no pushes.
- `sharingName` is this device only, and only ever typed in. Never fill it from the email, which other people must not see.

## Board analysis
- Analyse on the canvas hands the board to the server, which runs an agent over it in the background and writes what it finds as sync records. See `Plans/10-BoardAnalysis.md`. The app can be quit meanwhile.
- Results come only from the replica: `BoardAnalysisStore` (`Ergo/Boards/`, in the environment from `ErgoApp`) reads `annotation` and `analysis` records on launch and after every sync, like `boardStore.shares`. No Defaults key. `accountChanged` forgets every one of them, since they belong to the account that had them, and the next pull brings back the new account's.
- What's shown is worked out each time, never stored: `BoardAnalysisShown` (ErgoProtocol) keeps the newest run's annotations that are still true of the board, and an edit makes the rest stale. Stale ones are hidden and the sheet says the board changed. A `running` status older than `BoardAnalysisStatus.staleAfter` shows as interrupted.
- Starting pushes pending sync changes, reads link sources' text on the device with `PageReader` (the CLI can't open links), then POSTs through `TranslationAccount.startAnalysis`. A link that can't be read is left out and the sheet says so. Viewers don't see Analyse but do see annotations.
- Hosted boxes get no environment, so the count badge goes through `CanvasBoxModel.annotationCount` and `CanvasSourceModel.annotationCount`, and `StatementBoxView`'s hand-written `==` compares it. An arrow's line follows its assessment through `CanvasBoardView.strengths`: solid, thicker for conclusive, dashed for weak, dotted for none, and green, orange or red with it.
- The board annotates itself. A conclusion's box is coloured by its support (`CanvasBoxModel.support`). A comment box (`BoardAnalysisShown.comments`) is the first finding's first sentence, drawn by the box's own SwiftUI outside its frame at the fixed `CanvasCommentLayout`, with a `UIControl` in the cell taking the taps, since SwiftUI can't receive them out there. Arrows with something to say get a `CanvasArrowNote` halfway along.
- `AppSheet.boardAnalysis(board, focus:)` is `BoardAnalysisSheet`. Its markdown is `AskMarkdownView`, so links work as in Ask, and a library link closes the sheet through `NavigationManager`. Never call an intent's `perform()`.
- It never rules on whether a premise is true, and the sheet says so in its footer.

## Accounts
- Anonymous until signed in; sync needs Sign in with Apple or email + password. One account can hold both.
- Email addresses are not verified and there is no password reset yet. A wrong password is `invalidCredentials`, never `.unauthorized`: the app treats `.unauthorized` as a dead token and signs out.
- The server handles Apple's server-to-server notifications at `POST v1/apple/notifications`. Register `https://<host>/v1/apple/notifications` in the developer portal once there is a real host. Replay protection (`jti`) is in memory only.
- Revoking a user's Apple sign-in on account deletion is not built (needs a `.p8` key on the server and the app sending the `authorizationCode`).

## Server environment
- Release builds always use `ServerEnvironment.productionURL` (`https://ergo-15.235.184.129.sslip.io`, hosted on Dokploy).
- Debug builds can switch between Production and This Mac (Settings → AI → Server, which also has a Test Server row). For a phone, run the Mac server with `--hostname 0.0.0.0`.
