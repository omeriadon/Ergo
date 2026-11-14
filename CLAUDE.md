# Ergo

## Ground rules
- Never commit, stage, or otherwise touch git state. Adon manages git.
- Never boot a simulator or run the app/UI tests; it cripples the machine.
- Never build or test ErgoServer (`swift build`, `swift test`, `xcodebuild`). Adon builds it. Diagnose from its manifests and sources, and say plainly that it wasn't built.
- Verification is light. Don't build for small changes. For a big change, build once with `-configuration Debug` only (never Release, no other schemes), and don't re-run suites or builds to double-check. Say plainly what wasn't built or run.
- Match the surrounding code's style. Specialised code (parsers, performance-critical UIKit) can differ, since Adon doesn't write UIKit.
- Never use Adon's own Claude or Codex logins for testing, and never print, log or copy credentials. Tests use fake CLI scripts.
- Tokens (account, per-run, invite, push) and what anyone wrote are never logged, in the app or the server.

## Layout
- `Ergo.xcworkspace` opens the app, ErgoKit, ErgoServer and Plans together.
- `Ergo/` is the iOS app. `Ergo.xcodeproj` links `ErgoKit` as a local package. `Ergo/Boards/` is the board model and `BoardStore`. `Ergo/Scratchpads/` is `LogicScratchpad` and `ScratchpadStore`. `Ergo/Sharing/` is sharing boards with other people: the sheets, the invite, and the `AppDelegate`.
- `ErgoKit/` is shared by the app and the server:
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
- `Plans/` has the design docs: plans and the reasons for them, never progress or how something was built. Its README's English conventions are what the server's formalize prompt follows.
- `Notes/` says how each area works now (below).

## Notes
This file is only what every agent needs. How one area works, and what must not be broken there, is in `Notes/`. Read the file for an area before changing it, and correct it when a change makes it wrong. Something new goes there, and only here if it applies whatever is being worked on.

| File | Read it before touching |
|---|---|
| `Notes/Logic.md` | The logic keyboard and editor, the parser and its limits, `LogicChecker`, `LogicEnglish`, scratchpads, the course |
| `Notes/Boards.md` | `Board`, `BoardStore`, sources and regions, the UIKit canvas and its hosted SwiftUI boxes, the statement editor |
| `Notes/BreakDown.md` | Break Down, `PendingBreakDown`, the translation pipeline and its stages |
| `Notes/Ask.md` | Ask, Quick AI, detached runs, `AskTools` and intents, modes, attachments, markdown and LaTeX |
| `Notes/SharingIn.md` | The share extension, `SharedItemInbox`, `PageReader` |
| `Notes/Sync.md` | Sync kinds, tombstones, merging, `SyncCoding` |
| `Notes/SharingBoards.md` | Anything that writes to `boards`, roles and view-only boards, invites, pushes, the entitlements, reports |
| `Notes/BoardAnalysis.md` | Deep Research, annotations on the canvas, its Live Activity |
| `Notes/Accounts.md` | Signing in, deleting an account, allowances, purchases |
| `Notes/Versions.md` | Any wire type in `ErgoProtocol`, protocol versions, the update warning |
| `Notes/Server.md` | Which server a build talks to, and how the server logs |

## Building and testing
Xcode is a beta at a non-default path. Prefix every `xcodebuild` and `swift` command with its `DEVELOPER_DIR`.

```sh
export DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"
xcodebuild -project Ergo.xcodeproj -scheme Ergo -configuration Debug -destination 'generic/platform=iOS Simulator' build
(cd ErgoKit && swift test)
```

- The project uses the new `Ergo.xcodeproj/project.xcproj` format with a folder-synced `Ergo/` group, so new files are picked up automatically.
- The app build fails when a view's `body` takes over 500 ms to type-check. Keep bodies small.
- `ErgoTests/` is the app's unit test target (Swift Testing, hosted by the app so `@testable import Ergo` works). Read `ErgoTests/README.md` before adding to it. Agents compile it with `build-for-testing` in place of `build` above, and never run it: running needs a simulator. Adon runs the tests.
- Tests that touch Defaults go in a suite marked `.cleanDefaults`, and a store that starts using a new Defaults key adds it to `TestDefaults.keys`.
- Stress tests take a seed (`SeededRandom`) so a failure repeats. Keep what they build small: a test that expands or nests without a bound can take the machine's memory with it.
- `Checks/` only holds the dither, catalog and library precondition scripts. Run them with the Xcode MCP `RunCodeSnippet`.

## Conventions
- Default actor isolation is `MainActor`. Model and logic types that must work off the main actor are marked `nonisolated`.
- Tabs for indentation, and `case` indented inside `switch`.
- Persisted settings use sindresorhus/Defaults: keys in `Ergo/Other/Defaults.swift`, read with `@Default(.key)` in views. The only exception is the server account token, which is in the Keychain because it's a secret.
- Every new Defaults key needs a decision: synced (add it to `SyncedSetting` and `SyncedDefaults`) or this device only.
- Until v1, migrations don't matter: `Statement`, `Link`, `Board`, `LogicScratchpad`, `Translation`, `TranslationIssue` and `LogicKeyboardEntry` can change freely, even though they're saved in users' Defaults and sync records.
- Wire types are different, since older apps are in use: a new field is optional, a new case has to decode as unknown in an older app, and a field is never renamed or given a new meaning. See `Notes/Versions.md`.
- User-facing errors are worded like Swift compiler diagnostics. Anything worth interrupting for goes to `StatusBadgeManager.shared` (`addBadge`, or `present(error:title:)`), which draws over sheets.
- Users never see the word "OpenRouter": the server's own model is "Ergo's model" (`Provider.openrouter.displayName`). Legal text is the exception, since it has to name every provider.
- No Foundation Models, on-device or otherwise.
- Anything that talks to the server and takes a while is a run the server owns, with a way to find it again (as Ask and Break Down do), never a socket the work depends on.
- Never call an App Intent's `perform()` from app code: `@Dependency` only resolves inside the system's own intent flow, and crashes outside it. Call the `NavigationManager` method the intent calls.
- `PrivacyInfo.xcprivacy` (the app's in `Ergo/Special/`, the widgets' in `Ergo Widgets/`) needs a new entry when the app starts collecting something new or calls another required-reason API. The privacy policy and terms are markdown in `ErgoServer/Sources/ErgoServer/Legal/`, and the server serves them at `/policy` and `/terms` (`LegalController`, which only reads headings, lists, bold and links).

## Navigation
- There are two layouts, chosen by width alone (`horizontalSizeClass`, never the device): `AppTabs` when compact, `WideLayout` (`Ergo/Views/Wide/`: a sidebar, the open item, an inspector) when regular. Both only draw `NavigationManager` and the stores, so a resize switches without losing anything. Pushed pages come from `.logicDestinations()` and `.libraryDestinations()`, shared by both.
- In wide, a board sheet that's a panel (`BoardSheet.isPanel`) shows in the inspector beside the board instead of a sheet (`visibleSheet(isWide:)`, `boardPanel`).
- A sheet belongs to a tab or to the whole app. `BoardSheet`, `LogicSheet` and `LibrarySheet` live with their tabs, each with its own slot on `NavigationManager` (this device only), and only show while that tab is selected: leaving hides it and coming back restores it. `AppSheet` (settings, what's shared in, invites) shows over any tab.
- `ContentView` presents them all from `visibleSheet`, so a swap is SwiftUI replacing one sheet. `dismissSheet()` closes what's on screen, so call it before changing tab. `reveal(tab)` goes to a tab with nothing over it.
