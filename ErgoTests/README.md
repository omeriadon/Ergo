# ErgoTests

Unit tests for the app: the stores, navigation, the sync mapping and Ask's bookkeeping. They use Swift Testing (`import Testing`, `@Test`, `#expect`), like `ErgoKit/Tests`. The logic checker, parser and layout are tested in `ErgoKit`, with `swift test`.

The tests run inside the app on a simulator (that's what lets them say `@testable import Ergo`), so they need a simulator and can't be run from the command line without one.

## Running them

- **All of them:** pick the `Ergo` scheme and an iPhone simulator, then press **⌘U** (Product > Test).
- **One suite or one test:** open any file in `ErgoTests/` and click the diamond in the gutter beside `@Suite` or `@Test`. Or open the Test navigator (**⌘6**) and click the play button beside a name.
- **Results:** a green tick or a red cross appears in the gutter beside each test after a run. The Test navigator lists everything with the same marks, and the Report navigator (**⌘9**) keeps each run, with the failure messages. A failed `#expect` shows what each side of the `==` was.
- **Rerun what failed:** right-click the red cross in the gutter.

## Why tests don't leak into each other

The app saves everything with Defaults, which writes to the simulator's `UserDefaults`. Left alone, a test would read the boards you made last time you ran the app, and leave its own behind.

Put `.cleanDefaults` on a suite:

```swift
@Suite(.cleanDefaults)
struct MyStoreTests { ... }
```

Before each test it sets aside whatever is saved under the keys in `TestDefaults.keys` (`Support/CleanDefaults.swift`), and afterwards it puts it back, so the simulator ends up exactly as it was. In between, the app looks freshly installed. Tests that use it also wait for each other, since the keys are shared. A suite that never touches a store or Defaults (like `BoardTests`) doesn't need it.

Two more things to know:

- If a store starts using a new Defaults key, add the key to `TestDefaults.keys`.
- Make stores with the helpers in `Support/Fixtures.swift` (`BoardStore.test(board)`, `ScratchpadStore.test()`, `AskStore.test(chat)`). They also stop the store's delayed save, which would otherwise write a second after the test ended.

Nothing here talks to a server. `AskStore.send` and `resumeInterrupted` would reach the real one, so they aren't tested past their first checks.

## Adding a test

Find the suite for what you're testing, or add a file in the matching folder. Then:

```swift
@Test func deletingACardTakesItsArrows() {
	let rain = card("Rain")
	let wet = card("Wet", y: 200)
	let store = BoardStore.test(Board([rain, wet], links: [arrow(rain, wet)]))

	store.deleteStatement(id: rain.id)

	#expect(store.current.links.isEmpty)
}
```

Name the test as a sentence about what should happen. Arrange, act, then check with `#expect`. Use `try #require(x)` to unwrap an optional (the test stops there if it's nil). New files are picked up by the target automatically.

## Folders

- `Support/` holds `.cleanDefaults` and the builders (`card`, `arrow`, `Board([...])`, `scratchpad`), and `SeededRandom`.
- `Boards/` holds `BoardStore`, `Board`, sources and regions, sharing roles, chat edits, and Break Down.
- `Scratchpads/` holds `ScratchpadStore` and `LogicScratchpad`.
- `Navigation/` holds `NavigationManager`.
- `Sync/` holds records to boards and back, what `SyncController` records, and who is on a shared board.
- `Ask/` holds `AskStore`, the answer events, `AskIntents`, and the values a chat is made of.

## Stress tests

`BoardStoreStressTests` and `ScratchpadStressTests` make hundreds of edits in a random order, some with ids that don't exist, and check after each that the board is still one the canvas can draw and sync can send. Each test runs once per seed, and the seed decides every choice, so a failure happens again on the next run. To look at one, find its seed in the failure and run the test with just that number in `arguments:`.
