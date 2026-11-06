# Phase 1: ErgoKit

Pull the logic and translation code out of the app into a shared Swift package. Add the wire protocol and a client. Link the package back into the app so it builds exactly as before.

Read [README.md](README.md) first: ground rules, layout, decisions.

## Package

`ErgoKit/Package.swift`:
- swift-tools-version 6.2 or later
- Swift 6 language mode; fix any strict-concurrency errors properly rather than dropping to v5
- platforms `.iOS("27.0")` and `.macOS("27.0")` (use whatever spelling the 6.4 toolchain accepts); Linux needs nothing
- no dependencies
- the package's default isolation stays nonisolated, so drop the `nonisolated` keywords the app needed (redundant here)

```
ErgoKit/
  Package.swift
  Sources/
    ErgoLogic/
      Entries/      LogicKeyboardEntry.swift, LogicLetters.swift, LogicInputVocabulary.swift
      Parsing/      LogicFormula.swift, LogicParser.swift
      Checking/     LogicChecker.swift, LogicFallacyForm.swift, LogicEquivalence.swift (new)
      Feedback/     LogicFeedback.swift, LogicHighlight.swift
      Reading/      LogicEnglish.swift
    ErgoTranslation/
      Translation.swift            Translation, TranslationIssue (split out of TranslationPipeline.swift)
      EnglishValidator.swift
      LogicGrammar.swift
      Stages/       TranslationStage.swift, GateStage.swift, BreakdownStage.swift, FormalizeStage.swift, VerifyStage.swift, JSONSchema.swift (new)
      Pipeline/     TranslationPipeline.swift, TranslationBackend.swift, TranslationEvent.swift (new)
    ErgoProtocol/
      ErgoProtocol.swift   version + header names + paths
      Provider.swift       Provider, CredentialKind
      Accounts.swift       AccountCreated
      Connections.swift    ConnectionUpload, ConnectionStatus, DeviceLoginMessage
      Translate.swift      TranslateRequest, TranslateClientMessage, TranslateServerMessage
      ServiceError.swift
    ErgoClient/
      ErgoClient.swift          REST: account, connections
      TranslationSession.swift  WebSocket translate → AsyncThrowingStream
      DeviceLoginSession.swift  WebSocket Codex device login → AsyncThrowingStream
  Tests/
    ErgoLogicTests/        ported from Checks/LogicEditorChecks.swift + Checks/LogicParserChecks.swift, plus equivalence
    ErgoTranslationTests/  ported from Checks/TranslationChecks.swift, plus schema + event tests
    ErgoProtocolTests/     Codable round trips, JSON shape snapshots
```

Products, one library each: `ErgoLogic`, `ErgoTranslation` (depends on ErgoLogic), `ErgoProtocol` (depends on ErgoTranslation), `ErgoClient` (depends on ErgoProtocol).

## Moves

Move these with plain `mv`/new files and delete the originals. Never use git.

| From | To |
|---|---|
| `Ergo/Views/Check Tab/Logic Keyboard/LogicEditorModel.swift` | split into `ErgoLogic/Entries/*`. The keyboard rows stay on `LogicKeyboardEntry`, because `symbolEntries` derives from them. |
| `Ergo/Logic/*.swift` | `ErgoLogic/...` as above |
| `Ergo/Translation/*.swift` | `ErgoTranslation/...` as above. `RemoteTranslationBackend` and `TranslationBackends` are **deleted**: the app no longer runs stages itself. |
| `Checks/LogicEditorChecks.swift`, `Checks/LogicParserChecks.swift`, `Checks/TranslationChecks.swift`, `Checks/run-logic-editor-checks.py` (stale path) | Swift Testing tests, then delete the originals |

- Keep each file's header comment block.
- Make API `public` where the app, server or evals use it, and keep helpers internal.
- Use `package` access only if it really helps.
- Don't change behaviour; this is a move.

**Never change the Codable shape** of `LogicKeyboardEntry`, `Translation` or `TranslationIssue`: users' saved boards decode them. Add a test that decodes JSON in today's synthesized format:
1. Encode samples with the current app code *before* moving it.
2. Paste the strings into the test.

`EnglishValidator` uses NaturalLanguage, which doesn't exist on Linux:
- Wrap the language check in `#if canImport(NaturalLanguage)`.
- The other checks (length, letters ratio, word count) run everywhere.

`LogicFallacyForm` ids must still match `Ergo/Special/Catalog/fallacies.json`. That file stays in the app.

## FoundationModels goes away

- Remove `import FoundationModels`, `@Generable`, `@Guide` and the `Generable` constraint.
- Each stage gets a hand-written JSON schema instead. The `@Guide` descriptions move into the schema's `description` fields, and `.maximumCount` becomes `maxItems`.

```swift
public protocol TranslationStage {
	associatedtype Input: Codable & Sendable
	associatedtype Output: Codable & Sendable

	/// What the server routes on, so never rename one
	static var name: String { get }

	/// Handed to the model as its structured-output format
	static var outputSchema: JSONSchema { get }
}
```

`JSONSchema` is a small value type that encodes to standard JSON Schema. It covers only what the stages use: object, array, string (with optional `enum`), boolean, integer, each with an optional description.
- Every object is **strict**: `required` lists every property, and `additionalProperties` is false. This is what both Claude's `--json-schema` and Codex's `--output-schema` (OpenAI structured outputs) accept.
- No optional fields anywhere in an `Output`. An empty string or empty array means none, as today.
- Property order follows declaration order.
- `public func encoded() -> String`: compact JSON, for passing on a command line or writing to a file.
- **Test:** every stage's schema is strict all the way down. Also decode a sample output against each schema's property names.

## Pipeline events

```swift
public enum TranslationStep: String, Codable, Sendable, CaseIterable {
	case gate, breakdown, formalize, verify
}

/// What the pipeline is doing, sent to the app as it happens
public enum TranslationEvent: Codable, Hashable, Sendable {
	/// A model call began. `attempt` counts from 1 and only goes past 1 for formalize and verify.
	case started(step: TranslationStep, attempt: Int)

	/// Breakdown finished
	case foundClaims(premises: [String], conclusion: String, descriptors: [String])

	/// A formalize attempt compiled. Not final: verify may still send it back.
	case drafted(entries: [LogicKeyboardEntry], attempt: Int)

	/// An attempt was rejected, by the compiler or by verify, and the next one starts with these problems
	case retrying(problems: [String], attempt: Int)
}
```

Change `TranslationPipeline.translate`:

```swift
public func translate(
	_ english: String,
	events: @Sendable (TranslationEvent) async -> Void = { _ in }
) async throws -> Translation
```

- Emit `started` before every `backend.run`.
- Emit `foundClaims` after breakdown (with the sanitised descriptors), `drafted` after each successful compile, and `retrying` whenever problems feed into another attempt.
- Check `Task.checkCancellation()` before each model call.
- Otherwise the behaviour stays identical, and the existing tests keep passing.
- **Test:** the event sequence for each scripted scenario (retry, verify mismatch, give up, gate rejects).

`TranslationBackend` and `TranslationPolicy` stay as they are, minus the FoundationModels wording. `TranslationError` loses `server(status:)` and `notConfigured`, because the client has its own errors (`ServiceError`). Delete it if nothing's left.

## Equivalence (for evals and tests)

```swift
public enum LogicEquivalence {
	/// Whether two arguments say the same thing, allowing the letters to be renamed:
	/// some one-to-one mapping of `a`'s letters onto `b`'s makes every premise equivalent to exactly one premise (any order)
	/// and the conclusions equivalent. Nil when either uses something the checker can't evaluate.
	public static func mapping(from a: LogicArgument, to b: LogicArgument) -> [Int: Int]?

	public static func equivalent(_ a: LogicFormula, _ b: LogicFormula) -> Bool?
}
```

- Use the existing truth table machinery. Six letters gives at most 720 mappings × 64 rows, which is fine.
- `LogicArgument`/`LogicFormula` are the parser's types; use the real names.
- If the argument shape needs a different signature, change it, but keep the semantics.
- **Tests:**
  - `X→Y,X∴Y` ≅ `P→Q,P∴Q`
  - `X∨Y` ≅ `¬X→Y`
  - `¬(X∧Y)` ≅ `¬X∨¬Y`
  - `X→Y` ≇ `Y→X`
  - premise order doesn't matter
  - a different number of premises is not equivalent

## Wire protocol (ErgoProtocol)

Write these exactly, so phases 2a, 2b and 2c can build against them in parallel. Doc comments can be reworded to match style; names and shapes cannot change.

```swift
public enum ErgoProtocol {
	public static let version = 1
	public static let versionHeader = "Ergo-Protocol-Version"

	public enum Path {
		public static let accounts = "v1/accounts"          // POST → AccountCreated (no auth)
		public static let account = "v1/account"            // DELETE (auth)
		public static let connections = "v1/connections"    // GET → [ConnectionStatus]; PUT/DELETE v1/connections/<provider>
		public static let deviceLogin = "v1/connections/codex/device-login"   // WebSocket
		public static let translate = "v1/translate"        // WebSocket
	}
}

public enum Provider: String, Codable, Sendable, CaseIterable, Hashable {
	case claude, codex
}

public enum CredentialKind: String, Codable, Sendable, Hashable {
	/// claude: `claude setup-token` output. codex: the contents of `~/.codex/auth.json`.
	case subscription

	/// claude: an Anthropic API key. codex: an OpenAI API key.
	case apiKey
}

public struct AccountCreated: Codable, Sendable, Hashable {
	public let id: UUID
	/// Bearer token for every other request. Shown once, the server only keeps its hash.
	public let token: String
}

public struct ConnectionUpload: Codable, Sendable, Hashable {
	public let kind: CredentialKind
	public let secret: String
}

public struct ConnectionStatus: Codable, Sendable, Hashable {
	public let provider: Provider
	public let kind: CredentialKind
	/// When a test call last succeeded with this credential
	public let verified: Date?
	/// Why the last call failed, worded like a compiler error. Nil when it's working.
	public let problem: String?
}

public enum DeviceLoginMessage: Codable, Sendable, Hashable {
	/// Open `url` in a browser and enter `code`
	case code(url: URL, code: String)
	case connected(ConnectionStatus)
	case failed(ServiceError)
}

public struct TranslateRequest: Codable, Sendable, Hashable {
	public let id: UUID
	public let english: String
	public let provider: Provider
	/// `LogicLetters.resolved`, so the model writes the letters the app shows
	public let letters: [String]
	public let grammarVersion: Int
}

public enum TranslateClientMessage: Codable, Sendable, Hashable {
	case translate(TranslateRequest)
	case cancel
}

public enum TranslateServerMessage: Codable, Sendable, Hashable {
	case event(TranslationEvent)
	case finished(Translation)
	case failed(ServiceError)
}

public struct ServiceError: Error, Codable, Sendable, Hashable {
	public enum Code: String, Codable, Sendable {
		case unauthorized        // missing or unknown account token
		case outdatedApp         // protocol or grammar version mismatch
		case invalidRequest
		case notConnected        // no credential for that provider
		case credentialRejected  // provider says the credential is invalid or expired
		case usageLimit          // provider's rate or plan limit
		case providerUnavailable // CLI missing, crashed, network, provider outage
		case busy                // this account already has a translation running
		case timedOut
		case internalError
	}

	public let code: Code
	/// Compiler-style, shown to the user as is: "Claude isn't connected", "Expected Ergo 1.2 or later"
	public let message: String
}
```

- All public types need public memberwise initialisers. Write them, since synthesized ones are internal.
- Dates are ISO 8601 on both ends: give `ErgoProtocol` a shared `JSONEncoder`/`JSONDecoder` factory with `.iso8601`, and use it everywhere.
- Enums with associated values use Swift's synthesized Codable. Both ends are Swift, so that's fine.
- Snapshot the JSON of one value of each type in `ErgoProtocolTests`, so accidental shape changes fail loudly.

### Conversation rules

- **REST:**
  - Every request sends `Ergo-Protocol-Version: 1`, and `Authorization: Bearer <token>` except `POST v1/accounts`.
  - Errors return a non-2xx status with a `ServiceError` JSON body.
- **Translate socket:**
  1. The client connects with the same headers and sends exactly one `.translate`.
  2. The server sends any number of `.event`s, then exactly one `.finished` or `.failed`, then closes.
  3. The client may send `.cancel`, or just close, at any time, and the server stops the work.
- **Device login socket:** the server sends `.code` once, then `.connected` or `.failed`, then closes. The client closing cancels the login.

## ErgoClient

Foundation and URLSession only (`URLSessionWebSocketTask`). Import `FoundationNetworking` under `#if canImport(FoundationNetworking)`. Shaped for the app (Swift 6, Sendable):

```swift
public struct ErgoClient: Sendable {
	public init(server: URL, token: String?, session: URLSession = .shared)

	public func createAccount() async throws -> AccountCreated
	public func deleteAccount() async throws
	public func connections() async throws -> [ConnectionStatus]
	public func connect(_ provider: Provider, _ upload: ConnectionUpload) async throws -> ConnectionStatus
	public func disconnect(_ provider: Provider) async throws

	/// Events as they happen, finishing with the translation. Cancelling the consuming task cancels the work on the server.
	public func translate(_ request: TranslateRequest) -> AsyncThrowingStream<TranslateServerMessage, Error>

	public func codexDeviceLogin() -> AsyncThrowingStream<DeviceLoginMessage, Error>
}
```

- Errors thrown are always `ServiceError`. Transport failures map to `.providerUnavailable` with a message like "Couldn't reach the Ergo server".
- Converting `http(s)` to `ws(s)` for the socket paths happens inside the client.
- Tests cover only what's testable without a server: URL building, header presence (inspect the built `URLRequest`), and message coding.

## App changes in this phase (only enough to keep it building)

1. **Link the package.**
   - Add ErgoKit as a **local package** in `Ergo.xcodeproj/project.xcproj`. It's the new JSON-ish format, see the `"packages"` and `"package-product-members"` entries there.
   - Try `{"kind": "local", "path": "ErgoKit"}` first, and check it with `xcodebuild -list` and a build. If that's not the syntax, find the right one: search the Xcode beta app bundle for the project format schema, or use the Xcode MCP tools.
   - Link products `ErgoLogic`, `ErgoTranslation`, `ErgoProtocol` and `ErgoClient` to the Ergo target.
2. **Imports.** Add `import ErgoLogic` and the rest to each app file that needs them. `MEMBER_IMPORT_VISIBILITY` is on, so every file imports what it uses.
3. **Translate is temporarily unavailable.** `CheckTabView.translate()` just sets `translationError = "Translation isn't set up yet"`. Phase 2b wires up the client. Remove the old backend usage.
4. **Conformances stay put.** `LogicBoard: Defaults.Serializable` stays in the app. Anything else from the moved code that conformed to app-only protocols stays app-side as an extension.

## Verify

```sh
cd ErgoKit && DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer" swift test
cd .. && DEVELOPER_DIR=… xcodebuild -project Ergo.xcodeproj -scheme Ergo -destination 'generic/platform=iOS Simulator' build
```

- Both must pass with **no new warnings**. Ignore the existing `Defaults.o` linker warnings.
- Run `swift build` for ErgoKit on Linux **once**, at the end:
  `docker run --rm --cpus=4 --memory=6g -v "$PWD/ErgoKit":/src -w /src swift:6.2 swift build --target ErgoProtocol`
  Use the newest `swift:` image tag that's available, and skip this if Docker isn't running.
- That build proves ErgoLogic, ErgoTranslation and ErgoProtocol compile without Apple frameworks. ErgoClient may be skipped on Linux.

## Report back

- Final file tree.
- Public API changes compared with this doc.
- Anything you couldn't do.
- The exact `project.xcproj` package syntax that worked.
