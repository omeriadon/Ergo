# Phase 2b: App integration

> **Historical.** Built. Its README is now [00-Translation.md](00-Translation.md). Where this differs from the code or `CLAUDE.md`, they win.

The Check tab translates through the server, with live progress and a way to stop it. Settings connects Claude or ChatGPT.

Read these first:
- [README.md](README.md)
- [01-ErgoKit.md](01-ErgoKit.md) and the real ErgoKit sources (`ErgoProtocol`, `ErgoClient` especially)
- the existing views you touch, so new code matches their style. Adon writes SwiftUI, not UIKit; keep it plain SwiftUI.

You own `Ergo/` and `Ergo.xcodeproj/`. Verify with `xcodebuild … build` only: **never boot a simulator or run the app.**

Recent changes you'll see:
- `NavigationManager.openLibraryEntry`/`showLibraryList` now dismiss any sheet and never truncate the library path.
- There's a new `Ergo/Siri/Open Entity Intent/`.

Leave both as they are.

## Pieces

```
Ergo/Translation/                 (app side; the old files moved to ErgoKit in phase 1)
  TranslationAccount.swift        @MainActor @Observable: server, account token, connections, translate()
  AccountKeychain.swift           tiny Keychain wrapper for the account token
  TranslationProgress.swift       what the Check tab shows while translating, built from TranslationEvent
Ergo/Views/Sheets/Translation/
  TranslationSettingsView.swift   server, provider, connections
  ConnectClaudeView.swift
  ConnectChatGPTView.swift        device login, or paste auth.json / API key
Ergo/Views/Check Tab/EnglishStatusView.swift   (update)
Ergo/Views/Check Tab/CheckTabView.swift        (update)
```

### Storage

- **Defaults** (in `Ergo/Other/Defaults.swift`):
  - `translationServer: String`, default `""`. Empty means not set up.
  - `translationProvider: Provider`, default `.claude`. Add `extension Provider: Defaults.Serializable {}` app-side; it's a String raw value.
- **Keychain:** the account token, one item per server host.
  - Service `com.omeriadon.Ergo.translation`, account = server URL host + port.
  - `kSecAttrAccessibleAfterFirstUnlock`.
  - Only this is in the Keychain. Everything else uses Defaults, which is Adon's rule. Put one comment at the Keychain helper saying why it's the exception: it's a secret.

### TranslationAccount

`@MainActor @Observable final class`, in the environment like `BoardStore` (created in `ErgoApp`).
- **`server: URL?`** is read from Defaults. Accept `http://` too, for local development against a Mac.
- **`connections: [Provider: ConnectionStatus]`** and **`refresh()`**:
  - Called when Settings appears, and after connect/disconnect.
  - Errors go into a `problem: String?` shown in Settings.
- **The account is made lazily.** The first call that needs a token creates one (`createAccount`) and stores it. If a later call gets `.unauthorized` (for example the server was reset), drop the token, create a new account once, and retry once. The user has to reconnect providers then; Settings will show them as not connected.
- **Thin wrappers** over `ErgoClient`: `connect(_:_:)`, `disconnect(_:)`, `codexDeviceLogin()`, `translate(english:letters:)`.
  - Build the `TranslateRequest` with `LogicGrammar.version` and `Defaults[.translationProvider]`.

### Check tab

`CheckTabView.translate()`:
1. **Not set up:**
   - No server: show "Translation isn't set up" with a **Set Up** button that opens Settings (`navigation.presentSheet(.settings(id:))`, matching how it's opened elsewhere).
   - Provider not connected (`.notConnected`): show the server's message with the same button.
2. **Starting:**
   - Validate locally first with `EnglishValidator.problem(with:)`, so obviously bad input never hits the network. Show it the way the pipeline's issues are shown.
   - Keep the running `Task` in `@State`. The **Translate** button becomes **Stop** (`stop.fill`) while it runs; Stop cancels the task, which closes the socket and makes the server kill the CLI.
3. **Progress:**
   - Map each `TranslationEvent` into `TranslationProgress` and show one live row in `EnglishStatusView` instead of just a spinner.

     | Event | Row |
     |---|---|
     | `started(.gate, _)` | "Reading the English" |
     | `started(.breakdown, _)` | "Finding premises and claims" |
     | `foundClaims` | detail "2 premises, 3 claims, conclusion found" (or "no conclusion") |
     | `started(.formalize, 1)` | "Writing the logic" |
     | `started(.formalize, n)` | "Writing the logic, try \(n)" |
     | `retrying(problems, _)` | detail = first problem, in secondary colour, so the user sees *why* it's retrying |
     | `started(.verify, _)` | "Checking it means the same" |

   - Animate row changes the way the file already does (`.animation(.smooth, value:)`).
   - **Live descriptors:** on `foundClaims`, if the board's descriptors are all empty, show them straight away. That is the visible streaming, the keyboard labels fill in as the model finds them. If the translation fails, put back what was there before.
4. **Finished:**
   - Apply exactly as today: the stale guard, `translation`, `source = .english`, entries, descriptors.
   - Re-parse the entries first: if `LogicParser.parse(entries).diagnostics` isn't empty, don't apply them, and show "Server sent logic that doesn't parse".
5. **Errors:** a `ServiceError.message` goes in `translationError` as it is. Cancelling shows nothing.
6. **Leaving the board** (`board.id` changes) or the view disappearing cancels the task.

### Settings

- Add a section to `SettingsView` with a `NavigationLink` to `TranslationSettingsView`. Its label is `LabeledContent("Translation")`, valued "Claude"/"ChatGPT"/"Not set up".
- `TranslationSettingsView` is a `Form`:
  - **Server:**
    - URL `TextField` (`.URL` keyboard, no autocorrect), committed on submit.
    - The footer says it's Ergo's translation server, and that your own Claude or ChatGPT account does the work.
  - **Model:** a `Picker` between Claude and ChatGPT (`Provider.claude`/`.codex`). The footer says which subscriptions work: Claude Pro or Max, or ChatGPT Plus or Pro, or an API key for either.
  - **Connections:** one row per provider:
    - status: Connected · verified relative date / the problem in red / Not connected
    - push to the connect view
    - swipe or a button to Disconnect, destructive, with a confirmation
- **ConnectClaudeView:**
  - A segmented control: Subscription / API key.
  - Subscription instructions: "On a computer with Claude Code, run `claude setup-token`, then paste the token here." Show the command monospaced with a copy button.
  - A `SecureField`.
  - A **Connect** button with progress. On success, pop; on failure, show the server's message inline.
- **ConnectChatGPTView:**
  - The primary option is **Sign in with ChatGPT** (the device login stream):
    - Show the code large and monospaced, with Copy.
    - An **Open ChatGPT** button opens the URL with `openURL`.
    - A waiting indicator, then success → pop.
    - Footnote: device code sign-in has to be turned on in ChatGPT's security settings.
    - Leaving the view cancels the stream.
  - Secondary: "Paste auth.json" (multiline `TextField`; the footer says it's in `~/.codex/auth.json` after `codex login`) and "API key" (`SecureField`).
- **Wording** is compiler-style for errors, plain and short for everything else. No exclamation marks, no "Oops".
- **Accessibility identifiers:**
  - `check.translateButton` (keep it, including when it shows Stop)
  - `check.translationProgress`
  - `settings.translation`
  - `translation.server`
  - `translation.provider`
  - `translation.connect.claude`
  - `translation.connect.codex`

## Don'ts

- No polling. The streams push.
- Don't store provider secrets anywhere on the device after uploading them. Clear the fields once connected.
- Don't touch `ErgoKit/`, `ErgoServer/` or `Evals/`, apart from minimal additive ErgoKit fixes you report.

## Verify

- App build: `DEVELOPER_DIR=… xcodebuild -project Ergo.xcodeproj -scheme Ergo -destination 'generic/platform=iOS Simulator' build`. It must succeed with no new warnings.
- `#Preview`s for the new views, matching how existing previews inject the environment. Don't render them; just make sure they compile.

## Report back

- Screens and flows built.
- Anything you'd want Adon to try first on a device.
- Any ErgoKit changes.
