# Ergo translation server: plan

> **Historical.** The plan the server, ErgoKit and translation were built from. The app no longer turns English into logic, and only `Evals/` uses the translate route. The English conventions moved to [README.md](README.md). Where this differs from the code or `CLAUDE.md`, they win.

English → logic runs on a server Adon hosts. Each user connects their **own** Claude or ChatGPT account. The server runs the official `claude` and `codex` CLIs with the user's credentials. Ergo provides no model access of its own.

No Foundation Models, on-device or PCC. That's a firm decision; don't add hooks for it.

## Repository layout

One repo, three Swift packages plus the app. Packages reference each other by relative path.

```
Ergo/                 iOS app (existing, folder-synced)
Ergo.xcodeproj/       links ../ErgoKit as a local package
ErgoKit/              shared package: logic, translation contract, wire protocol, client
ErgoServer/           Vapor server, depends on ../ErgoKit
Evals/                eval runner + corpus, depends on ../ErgoKit, talks to a running server
Plans/                these documents, plus Fixtures/ captured from the real CLIs
Checks/               only the dither/catalog/library checks remain here
```

| Package | Products / targets | Builds on |
|---|---|---|
| ErgoKit | `ErgoLogic`, `ErgoTranslation`, `ErgoProtocol`, `ErgoClient` | iOS, macOS, Linux (ErgoClient: Apple platforms, Linux only if it happens to compile) |
| ErgoServer | `ErgoServer` executable, `ErgoServerTests` | macOS for dev, Linux (Docker) for production |
| Evals | `ErgoEval` executable, `EvalCorpusTests` | macOS |

## How a translation flows

```
App ──WS /v1/translate──▶ Vapor ──▶ TranslationPipeline (ErgoTranslation, same code as the app's checker)
 ▲                         │            │ run(stage, input)
 │  TranslationEvent ...   │            ▼
 └──── finished(Translation)◀── ProviderBackend ──▶ claude -p … / codex exec …  (per-request sandboxed run dir,
                                                         user's own token)
```

1. The app validates the English locally (`EnglishValidator`), then opens a WebSocket and sends `translate`.
2. The server looks up the user's connection for the chosen provider, decrypts it, and runs `TranslationPipeline` with a `ProviderBackend`.
3. Every pipeline step emits a `TranslationEvent`. The server forwards each one straight away, which is the streaming.
4. The server finishes with `finished(Translation)` or `failed(ServiceError)`. Closing the socket or sending `cancel` kills the running CLI process. (Break Down, scope `argument`, is the exception: it is a detached run that survives its socket, and only `cancel` stops it. See `ErgoServer/README.md`.)
5. The app re-parses the returned entries before applying them. It never trusts the server blindly.

## Phases

| Phase | Owner | Doc | Depends on |
|---|---|---|---|
| 1 | Agent "ErgoKit" | [01-ErgoKit.md](01-ErgoKit.md) | none |
| 2a | Agent "Server" | [02-Server.md](02-Server.md) | phase 1 |
| 2b | Agent "App" | [03-App.md](03-App.md) | phase 1 |
| 2c | Agent "Evals" | [04-Evals.md](04-Evals.md) | phase 1 (runs against 2a once it exists) |
| 3 | Lead | this file | everything |
| 5a | Agent "ErgoSync" | [05-Sync.md](05-Sync.md) | phase 1 |
| 5b / 5c | Agents "Server sync" / "App sync" | [05-Sync.md](05-Sync.md) | 2a / 2b and 5a |

The phase 2 agents run in parallel and own disjoint directories:
- Server: `ErgoServer/`
- App: `Ergo/` and `Ergo.xcodeproj/`
- Evals: `Evals/`

ErgoKit is frozen after phase 1. If a phase 2 agent truly needs a change there:
- keep it additive and minimal
- run `swift test` in ErgoKit
- list it in the final report

## Ground rules (all agents)

- **Git:** never touch it. No commit, add, stash, mv or checkout. Adon manages git. Use plain `mv`/`rm`.
- **Simulators:** never boot one, run the app, or run UI tests; it cripples the machine. Verify the app with `xcodebuild … build` only.
- **Docker:** only if a doc says so, and capped: `--cpus=4 --memory=6g`.
- **Style:** match the existing code (read a few files first):
  - tabs, with `case` indented inside `switch`
  - short `///` doc comments that say *why*, and few inline comments
  - `// MARK: - name` sections
  - small, plain types with no protocols-for-everything
  - user-facing errors worded like Swift compiler diagnostics ("Expected …, found …", glyphs in straight single quotes, no full stop)
- **Toolchain:** Xcode is a beta at a non-default path. Prefix every `swift`/`xcodebuild` command:
  `DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"` (Swift 6.4.2)
- **Network:** the current network **can't reach OpenAI** (TLS fails). Codex works fine elsewhere, but it can't be called live during this work. Anthropic works.
  - Never use Adon's own Claude/Codex logins for anything but the documented smoke tests.
  - Never print, log or copy credentials.
- **Persisted formats:** `LogicBoard`, `Translation`, `TranslationIssue` and `LogicKeyboardEntry` are already saved in users' Defaults as synthesized Codable. Never rename their types' cases or stored properties.
- **Stage names:** never rename a stage's `name` (`gate`, `breakdown`, `formalize`, `verify`).

## Decisions

- **Accounts:** anonymous, one per install.
  - The server issues a random bearer token. The app keeps it in the Keychain, the only non-Defaults storage, because it's a secret.
  - Sign in with Apple can come later without changing anything else.
- **Connections:** per account, per provider. At most one credential per provider.

  | Provider | `subscription` | `apiKey` |
  |---|---|---|
  | `claude` | token from `claude setup-token` (Pro/Max/Team/Enterprise), passed as `CLAUDE_CODE_OAUTH_TOKEN` | `ANTHROPIC_API_KEY` |
  | `codex` | contents of `~/.codex/auth.json` after `codex login`, **or** the in-app device login (server runs `codex login --device-auth`) | `CODEX_API_KEY` |

  - API keys still go through the same CLIs. There are no raw HTTP API clients, so "raw API" is only a connection option, not a third architecture.
  - Never set both the OAuth token and the API key for Claude: the API key wins.
- **Models:** the server picks a model per stage per provider, using aliases (`haiku`/`sonnet`/`opus` for Claude) so the server tracks new releases. Users pick only the provider. Defaults are in 02-Server.md and can be overridden by config.
- **Protocol:** WebSocket for translation and device login, JSON REST for everything else. The `Ergo-Protocol-Version` header goes on every request.
- **Grammar:** the client sends `LogicGrammar.version`. The server refuses a mismatch with `outdatedApp`. Both are built from the same ErgoKit, so they only diverge across releases.
- **Boards:** stay in Defaults (Adon's call).
- **Provider terms (risk, not a blocker):** hosting other people's subscription tokens is the user's own credential used through the official CLI, but provider terms on third-party/hosted use can change.
  - Keep the `apiKey` option working so there's always a compliant path.
  - Don't build anything that depends on one provider's subscription.

## Phase 3 (lead): after all agents report

- Read every diff. Build the app. Run `swift test` in all three packages and a server smoke test with Claude.
- Update `CLAUDE.md` (and with it `AGENTS.md`, which is a symlink).
- Report to Adon, honestly, what's verified and what isn't (Codex can't be exercised from this machine).
