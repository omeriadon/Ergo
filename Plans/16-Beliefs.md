# 16 · Beliefs

A list of what you believe, how sure you are, the boards for and against, and a record of when you changed your mind. Sets of questions to answer on a scale start it off and show the change over time.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## Why

Boards are about arguments, and arguments are about something someone believes. Nothing in the app holds that belief, or remembers that a board changed it. A ledger of beliefs turns boards from one-off maps into a record of how your thinking moved, which no canvas or chat app keeps. It's 12-Identity's "testing what you believe".

**Decided:** no automatic consistency checking. Adon tried turning free conversational English into logic, and it's too unreliable to build on. Beliefs stay English, like boards.

## A belief

**Proposed:**

```swift
nonisolated struct Belief: Codable, Hashable, Identifiable, Sendable {
	var id = UUID()
	var created = Date.now

	/// One claim, in the person's own words
	var statement: String

	/// How sure they are that it's true, 0...100. Nil is "No view".
	var confidence: Int?

	/// Boards that bear on it, and which way
	var evidence: [Evidence] = []

	/// Every time the confidence changed, oldest first
	var changes: [Change] = []

	/// The bank question it answers, when it came from one (see Question sets)
	var question: String?

	var isArchived = false

	struct Evidence: Codable, Hashable, Sendable {
		enum Side: String, Codable, Sendable { case supports, against, about }
		var board: UUID
		var side: Side
	}

	struct Change: Codable, Hashable, Identifiable, Sendable {
		var id = UUID()
		var date: Date
		var from: Int?
		var to: Int?

		/// Why, in their words. Optional.
		var note: String?

		/// The board that changed their mind, if one did
		var board: UUID?
	}
}
```

- **Confidence is a slider that snaps** to steps of 10 and shows a word for where it sits: "Very unlikely", "Unlikely", "Unsure", "Likely", "Very likely". People aren't good at exact percentages, but a number makes changes over time easy to compare.
- **A change is recorded** whenever the slider settles somewhere new, not on every step. The note and the board are asked for after, and can be skipped. Changing the statement itself isn't a change of mind: a rewording keeps the history.
- Persisted with Defaults. Its key goes in `TestDefaults.keys`.

## Where it lives

**Decided:** in the Library.

**Proposed:** on the Library stack next to Practice, as a card on the grid and a row in the wide sidebar (`LibraryRoute.beliefs`, `SidebarItem.beliefs`). Practice already put your own progress there, and the four tabs stay as they are.

## Question sets

**Decided:** beliefs also come from sets of questions. You answer each on a scale, and every answer is logged.

**Decided:**
- About 10 sets of about 15 questions, covering a wide range: existentialism and meaning, nihilism, morality, the mind and the self, religion, knowledge and truth, liberalism and freedom, politics and power, society and culture, and life and death.
- The questions are somewhat in depth and quite provocative: claims a thoughtful person could hold either way, put sharply enough that rating them takes a moment's thought.
- The pages look like the app's other pages. Taking a set follows Practice: a start page, one question at a time, then a summary.
- No searching for sets or questions. `PersonalSearch` finds beliefs, not the bank.

**Proposed:** a question is a ready-written belief. Answering it makes or updates the `Belief` for it, so the ledger, the history and the chart are the same whether you wrote the statement or it came from a set. That's how the ledger starts out full on day one, instead of asking someone to write down what they believe from nothing.

- **The bank** is `beliefQuestions.json` in ErgoCatalog, written by hand like the puzzles. Sets in order, each with an `id`, a `title` ("Meaning", "Nihilism", "Liberalism"), a `color` of its own as `#RRGGBB` (**Decided:** fully custom colours, not the library's category palette), a one-sentence `summary` for its card, and its questions. A question has an `id`, a `statement` written as a claim to rate ("We have free will", not "Do we have free will?"), and optional `entries`: library entries for the positions on it (compatibilism, hard determinism), shown after answering, so the questions teach the library like the puzzles do. Ids never change and the file only grows at the end. A test checks every set and question, as with the puzzles.
- **The scale** is the belief's own confidence slider, with its words, so an answer is a confidence like any other. "No view" skips the question, and is logged as a skip rather than as a confidence.
- **Taking a set** walks through its questions one at a time, with the slider in the middle of the screen and nothing else to read. It can be left part way and picked up later. At the end, a summary shows each answer, and the library entries the answers lean towards.
- **Taking it again.** Any set can be retaken whenever. Your last answer shows as a mark on the slider, so you're rating again rather than remembering, and any answer that moved is logged as a `Change`. The summary then shows what moved since last time. A set last taken over six months ago says so on its card. That's the "how your thinking moved" view, with no AI.
- **Where.** The Beliefs page lists the sets above the beliefs, each with how much of it is answered and when it was last taken. A belief that came from a question is marked with its set.
- **One belief per question,** even when two devices answer it offline: the belief's id is a uuid made from the question's id (a name-based hash), so both devices write the same record and the stamps settle it.
- **Never compared with other people.** No averages, no "most people think". Answers stay the person's own, as in Privacy below.


## The screens

**Proposed:**
- **The list.** Each belief with its confidence as a small bar, and an arrow when it moved recently. Sorted by when each was last looked at, so old ones come up to revisit. Swipe to archive. A plus button writes a new one: a statement and a starting confidence.
- **A belief.** The statement, the slider, a Swift Charts line of its confidence over time with a point per change (tap one for its note and board), and the boards as two lists, "For" and "Against", with "About" below. Adding a board picks from the board list.
- **From a board.** The board's ⋯ menu gets "This bears on a belief…", which picks a belief (or writes a new one from a card's English) and a side. Afterwards the belief's slider is offered right there, so "this changed my mind" is one step, with the board already filled in.
- **Search.** `PersonalSearch` finds beliefs by statement and notes.
- **The Mac.** The belief editor and the board picker are sheets with `.sheetDismissal` and `.sheetConfirmation`.

## AI

**Proposed:** nothing new on the server for the first version.
- "Argue with me" on a belief opens Ask in debate mode with the belief and its confidence as the first message, so it reuses debate as it is.
- "Make a board" makes a board with the belief as its one conclusion card, ready to break things down into.
- Ask's tools don't read beliefs yet, the same as boards and scratchpads (07's "Ask's tools over the person's own boards and scratchpads"). When those tools come, beliefs should come with them.

The model never judges whether a belief is true or what the confidence ought to be.

## Sync

**Decided:** beliefs sync.

A `belief` kind (id: the belief's uuid), with `created`, `content` (the statement), `question`, `archived` and `deleted`, last writer wins per field. A change is a `beliefChange` record of its own (`belief`, `date`, `previous`, `confidence`, `content` for the note, where a null `confidence` is "No view"), so two devices adding changes offline never lose one. How sure the person is isn't a field of the belief: it's the newest change's rating, so it always agrees with the history. A question's belief has an id made from the question's id, so answering it on two devices before either syncs makes one belief. Deleting a belief tombstones it and its changes.

**Proposed**, with boards: `evidence` as a field of the belief, and `board` on a change. A board that's deleted leaves a gap in both, which the screens just skip.

## Privacy

Beliefs are the most personal thing in the app: politics, religion, people. They're never logged, never in analytics (07), never in a report, and never shared in this version. They sync like boards, under the account. The privacy policy's description of synced content should name them.

## Not in this

- Checking beliefs against each other, by logic or by model.
- Sharing a belief, or comparing beliefs or answers with other people.
- Questions written by the model. The sets are written by hand.
- Reminders to revisit. The list's order does that quietly for now.
- Linking a belief to one card instead of a whole board.
