# ErgoSiriEvaluations

Measures how well Siri selects and fills in Ergo's App Intents, using Apple's `SiriEvaluations` framework (OS 27.3+). Each scenario is something a user says to Siri ("In Ergo, open Plato") plus the intent calls, parameters and entities Siri should produce. Running the suite drives the real Siri UI and produces a graded report.

## What it covers

Names are strings (the test bundle can't link the app): Swift type names from `Ergo/Siri/`, bundle id `com.adonis.Ergo`.

| Test | Intents | Asserts |
|---|---|---|
| `opensTabs` | `OpenTabIntent` (`tab`: board, logic, ask, library) | `.intentsAllPass` |
| `showsCategories` | `ShowLibraryListIntent` (`category`) | `.intentsAllPass` |
| `opensEntries` | `OpenLibraryEntryIntent` for a fallacy, bias, razor or philosopher, with `Finds` + `expectIdentifier` and `Calls(.disallowed)` for `SetBookmarkIntent` | `.intentsAllPass`, `.foundEntitiesAllPass` |
| `opensOtherEntries` | `OpenLibraryEntryIntent` for a concept, paradox, argument or symbol, same checks | `.intentsAllPass`, `.foundEntitiesAllPass` |
| `editsBookmarks` | `SetBookmarkIntent` (`action`: add, remove), plus `Finds` for the named entity | `.intentsAllPass`, `.foundEntitiesAllPass` |
| `opensBookmarks` | `OpenBookmarksIntent` | `.intentsAllPass` |
| `searchesLibrary` | `SearchLibraryIntent` (system search-in-app, the only search intent) | `.intentsAllPass` |
| `ignoresUnsupportedRequests` | no Ergo intent may run for an unsupported request | `.intentsAllPass` |

Ergo ships no App Skills (`*.skillsbundle`), so there are no `Loads` expectations.

Notes:

- The eight typed `Open<X>EntityIntent`s (`OpenIntent`s for Spotlight) are not covered: they are not tools and `isDiscoverable` is false, so Siri never calls them and `IntentDefinitions` has nothing to name. Opening an entry by name goes through `OpenLibraryEntryIntent`, and `Finds` checks that Siri resolved the right entity.
- `AppEnum` parameters (`tab`, `category`, `action`) are matched with `.equals("<raw value>")`. There is no enum-specific matcher, so this is unverified until it runs on a device.
- `OpenLibraryEntryIntent` and `SetBookmarkIntent` take a `LibraryEntry` union, so the entry itself can't be constrained; `Finds` checks the named entry was resolved.
- `SearchLibraryIntent`'s `criteria` can't be constrained either, so `searchesLibrary` only measures that Siri picks the search intent, not that it passes the right text.
- `editsBookmarks` really bookmarks and un-bookmarks "Ad hominem" on the device. Both scenarios use the same entry, so a full run leaves your bookmarks as they were; if only one ran, fix them by hand.

## What you need

- A physical iPhone on OS 27.3+ (no simulator support), connected and set up for development in Xcode, with Developer Mode on.
- Siri on, Apple Intelligence on, and its models finished downloading (Settings → Siri).
- Ergo (the `Ergo` scheme, Debug) installed on the device and launched once since install, so its App Intents are registered and its entities are indexed in Spotlight. Reinstalling resets this.
- The device unlocked and untouched for the whole run. It will ask for the passcode to turn on Automation Mode. Each turn can take up to a minute.

The test target is not hosted in the app (no `TEST_HOST`), is iPhone-only (`SUPPORTED_PLATFORMS = iphoneos`) and has a 27.3 deployment target.

## Running

1. Choose the `ErgoSiriEvaluations` scheme and the physical device.
2. Run one test at a time (the diamond next to a `@Test`, or Test navigator → right-click → Run). The suite is `.serialized` and must never run in parallel: the device handles one Siri conversation at a time.
3. Open the Report navigator (⌘9) → the test run → the evaluation for the summary cards (Overview, App Entities, Siri Response) and one row per scenario.

A build-only check (no device, no tests):

```sh
export DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"
xcodebuild -project Ergo.xcodeproj -scheme ErgoSiriEvaluations -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build-for-testing
```

From a result bundle: `xcrun xcresulttool export attachments --path <bundle>.xcresult --output-path <dir>` writes one `.xcevalresult` (JSON) per evaluation.

## Reading a failure

The test's `#expect` is only a summary; the per-scenario rows explain a failure. Each scenario opens to:

- **Diagnostics**: how many turns completed, anything Siri did that couldn't be decoded, and how many entities Spotlight had indexed. If every scenario fails the same way, turns are missing, or the Spotlight index is empty, the environment is the problem (device not ready, app not launched). Fix that and rerun; don't change expectations or intents for it.
- **Scenario**: whole-conversation expectations, if any.
- **Turn 1, …**: the utterance, one group of rows per expectation, then Siri's response.

Each table has **Key** (what is checked), **Subject** (what Siri did), **Expected** and **Issues** (rows where Subject and Expected differ). The first failure in a turn usually explains the rest: an intent that wasn't called leaves its parameter rows unchecked, and a row that couldn't be checked is neither a pass nor a failure.

Decide first whether a failure is the **environment**, the **app** or the **test**:

- Wrong intent, wrong parameter, or a disallowed intent called → usually the app: titles, descriptions, parameter descriptions, entity properties. Don't rename an intent, entity, parameter or `AppEnum` case to fix it; that breaks integrations and these scenarios.
- Expectation doesn't match what the utterance asks for → the test.
- Siri is nondeterministic. One failure among several paraphrases is a signal to investigate; a failure that repeats across reruns and paraphrases is probably systematic.
- After changing App Intents code, rebuild, reinstall and launch Ergo before rerunning.
