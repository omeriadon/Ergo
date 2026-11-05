# Ergo

## Ground rules
- Never commit, stage, or otherwise touch git state. Adon manages git.
- Never boot a simulator or run the app/UI tests; it cripples the machine. Verify with a build only.
- Match the surrounding code's style. Specialised code (parsers, performance-critical UIKit) can differ, since Adon doesn't write UIKit.
- Never use Adon's own Claude or Codex logins for testing, and never print, log or copy credentials. Tests use fake CLI scripts.

## Layout
- `Ergo/` is the iOS app. `Ergo.xcodeproj` links `ErgoKit` as a local package.
- `ErgoKit/` is shared by the app, the server and the evals:
  - `ErgoLogic`: entries, parser, checker, `LogicEnglish`, `LogicEquivalence`
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
- Each Check tab page (`LogicPage`, in `PageStore`, persisted with Defaults) owns its English, logic and descriptors. Letters are app-wide, descriptors are per page.
- `LogicPage`, `Translation`, `TranslationIssue` and `LogicKeyboardEntry` are saved in users' Defaults as synthesized Codable. Never rename their cases or stored properties.

## Translation
- English → logic runs on the server: the app streams `TranslationEvent`s over a WebSocket, through `TranslationAccount`. Stages are `TranslationPipeline` stages in ErgoTranslation; never rename a stage's `name`.
- The app checks English with `EnglishValidator` before sending it, and re-parses the returned entries before applying them.
- Logic → English is `LogicEnglish`, deterministic and exact. It's also what the verify stage compares against.
- No Foundation Models, on-device or otherwise.

## Sync
- Signed in with Apple, pages, bookmarks and the settings in `SyncedSetting` sync through the server (`Ergo/Sync/`, ErgoSync).
- Every new Defaults key needs a decision: synced (add it to `SyncedSetting` and `SyncedDefaults`) or this device only.
- Merging is last writer wins per field, with hybrid-clock stamps. Two devices editing a page's content at once give a conflict copy, not a loss.
- Sync values are always encoded with `SyncCoding`. A different encoder makes identical values look like edits.
