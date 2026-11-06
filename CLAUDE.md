# Ergo

## Ground rules
- Never commit, stage, or otherwise touch git state. Adon manages git.
- Never boot a simulator or run the app/UI tests; it cripples the machine.
- Verification is light. Don't build for small changes. For a big change, build once with `-configuration Debug` only (never Release, no other schemes), and don't re-run suites or builds to double-check. Say plainly what wasn't built or run.
- Match the surrounding code's style. Specialised code (parsers, performance-critical UIKit) can differ, since Adon doesn't write UIKit.
- Never use Adon's own Claude or Codex logins for testing, and never print, log or copy credentials. Tests use fake CLI scripts.

## Layout
- `Ergo.xcworkspace` opens the app, ErgoKit, ErgoServer, Evals and Plans together.
- `Ergo/` is the iOS app. `Ergo.xcodeproj` links `ErgoKit` as a local package. `Ergo/Boards/` is the board model and `BoardStore`. `Ergo/Scratchpads/` is `LogicScratchpad` and `ScratchpadStore`.
- `ErgoKit/` is shared by the app, the server and the evals:
  - `ErgoLogic`: entries, parser, checker, `LogicEnglish`, `LogicEquivalence`, and `Canvas/` (argument map, validator, layout; pure, tested with `swift test`)
  - `ErgoTranslation`: the pipeline and stages
  - `ErgoSync`: the sync engine
  - `ErgoProtocol`: the wire types
  - `ErgoClient`: a client for the server
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
- Fallacy ids in `LogicFallacyForm` (ErgoLogic) must match ids in `Ergo/Special/Catalog/fallacies.json`.
- A board (`Board`, in `BoardStore`, persisted with Defaults) is a canvas in the Board tab: `statements` joined by `links` ("premise of"). It always holds at least one statement. Boards are English only.
- A `Statement` is `id`, `position` (the box's centre) and `english`. `StatementEditorView` edits one statement of the current board, through `BoardStore`.
- Logic lives in the Logic tab, as a list of saved scratchpads. A `LogicScratchpad` holds a whole argument: `descriptors`, `english`, `logic`, `source` and `translation`. Letters are app-wide, descriptors are per scratchpad. `ScratchpadStore` (`Ergo/Scratchpads/`) is how they change, and `ScratchpadEditorView` edits `ScratchpadStore.current`.
- `BoardStore` is how statements and links change (add, update, move, delete, link, unlink, arrange). `Board.map` is the `ArgumentMap` that ErgoLogic's validator, layout and checks take.
- The canvas moves in UIKit (`CanvasBoardView`: pan, pinch, inertia, dragging, arrows), so nothing goes through SwiftUI while it moves. What a box looks like is SwiftUI (`StatementBoxView`), hosted per box, and the bars are SwiftUI (`CanvasBar`). Hosted boxes get no environment from the app: pass anything new in `CanvasBoard.boxContent`. Nothing on the canvas may be laid out from a measured size.
- Until v1, migrations don't matter: `Statement`, `Link`, `Board`, `LogicScratchpad`, `Translation`, `TranslationIssue` and `LogicKeyboardEntry` can change freely, even though they're saved in users' Defaults and sync records.

## Translation
- English → logic runs on the server: the app streams `TranslationEvent`s over a WebSocket, through `TranslationAccount`. Stages are `TranslationPipeline` stages in ErgoTranslation; never rename a stage's `name`.
- Translating is per scratchpad, and sends the scratchpad's six descriptors (`""` for a free slot) so the server reuses a letter for a claim it already names. The result updates that scratchpad, and its descriptors only fill slots still free. Break Down makes a board, and doesn't use descriptors.
- `TranslationAccount.breakDown` runs the server's argument scope on pasted English: premises, a conclusion and claims, with no logic.
- The app checks English with `EnglishValidator` before sending it, and re-parses the returned entries before applying them.
- Logic → English is `LogicEnglish`, deterministic and exact. It's also what the verify stage compares against.
- No Foundation Models, on-device or otherwise.

## Sync
- Signed in with Apple or email, boards, bookmarks and the settings in `SyncedSetting` sync through the server (`Ergo/Sync/`, ErgoSync).
- Every new Defaults key needs a decision: synced (add it to `SyncedSetting` and `SyncedDefaults`) or this device only.
- Sync kinds: `board` (`created`), `statement` (`board`, `position`, `content`, which is just the English), `link` (`board`, `premise`, `conclusion`) and `scratchpad` (`created`, `descriptor.N`, `content`). Statements and links are records of their own, so dragging a box never clashes with typing in it.
- Deleting a board writes only its tombstone: the replica ignores its statements and links (`SyncReplica.isIgnored`). Deleting a statement tombstones it and its links. Boards are rebuilt from the replica's records, so arrival order doesn't matter.
- Merging is last writer wins per field, with hybrid-clock stamps. Two devices editing a statement's content at once give a conflict copy of that statement beside it, not a loss.
- Sync values are always encoded with `SyncCoding`. A different encoder makes identical values look like edits.

## Accounts
- Anonymous until signed in; sync needs Sign in with Apple or email + password. One account can hold both.
- Email addresses are not verified and there is no password reset yet. A wrong password is `invalidCredentials`, never `.unauthorized`: the app treats `.unauthorized` as a dead token and signs out.
- The server handles Apple's server-to-server notifications at `POST v1/apple/notifications`. Register `https://<host>/v1/apple/notifications` in the developer portal once there is a real host. Replay protection (`jti`) is in memory only.
- Revoking a user's Apple sign-in on account deletion is not built (needs a `.p8` key on the server and the app sending the `authorizationCode`).

## Server environment
- Release builds always use `ServerEnvironment.productionURL` (`https://ergo-15.235.184.129.sslip.io`, hosted on Dokploy).
- Debug builds can switch between Production and This Mac (Settings → Translation → Server, which also has a Test Server row). For a phone, run the Mac server with `--hostname 0.0.0.0`.
