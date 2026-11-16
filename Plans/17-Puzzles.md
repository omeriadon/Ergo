# 17 · Daily puzzles

One short puzzle a day, from a bank Adon writes, taken in order.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## Why

A small reason to open the app each day that teaches the library on the way, and something to share. No AI: every puzzle is written by hand, so it's always right.

## The bank

**Decided:**
- A bank of puzzles Adon writes, as an ordered list.
- Each day, the person gets the earliest puzzle in the list they haven't finished.
- One kind of puzzle for now: a quote, a question, a list of choices, which one is correct, and a colour for the question.
- `answer` counts from 1, since the bank is written by hand.
- One puzzle a day, and no more even if someone wants another. A day runs from midnight to midnight on the device's clock, not 24 hours from the last answer.
- The answers sync. There's no separate progress: which puzzle is next comes from the answers.
- Finished puzzles go into the Library, in a Puzzles section with each day's puzzle in its own `Section`.

**Proposed:** `puzzles.json` in ErgoCatalog's resources, read like the library's files.

```json
{
	"puzzles": [
		{
			"id": "slippery-school-uniforms",
			"kind": "choice",
			"quote": "If we let students skip uniforms on Fridays, soon they'll want to skip them every day, and then there'll be no rules at all.",
			"question": "What's wrong with this argument?",
			"choices": ["Slippery slope", "Straw man", "Ad hominem", "Nothing, it's sound"],
			"answer": 1,
			"color": "blue",
			"source": "A school newsletter",
			"explanation": "Each step is assumed to follow from the last, with no reason given that it would.",
			"entry": "fallacies/slippery-slope-fallacy"
		}
	]
}
```

| Field | | |
|---|---|---|
| `id` | required | What an answer is saved under. Never changes once shipped. |
| `kind` | required | `choice` for now. An app skips a kind it doesn't know, so new kinds can be added later without breaking older apps. |
| `quote` | required | The passage. |
| `question` | required | What to work out about it. |
| `choices` | required | 2 to 6 answers. |
| `answer` | required | Which choice is correct, counting from 1. |
| `color` | required | A `CategoryTheme` name (`red`, `green`, `blue`, `orange`, `mint`, `purple`, `yellow`, `teal`), so puzzles share the library's colours. An unknown name is blue. |
| `source` | optional | Who said it or where it's from, shown under the quote. |
| `explanation` | optional | Shown after answering. |
| `entry` | optional | A library entry, `category/id`, linked after answering, so every puzzle can lead into the library. |

The `explanation` and `entry` fields are suggestions on top of what's decided. They make an answer teach something rather than just mark it.

**Proposed** rules for the file, like `itemOfTheDay.json`'s:
- **It only grows at the end.** Never reorder or remove a puzzle, since order is what people walk through and ids are what their answers are saved under. Fixing a puzzle's wording is fine.
- **Checks.** A test in `ErgoAskTests` (next to `PracticeTests`, since ErgoCatalog has no test target) checks every puzzle: ids unique and non-empty, a known kind, 2 to 6 non-empty choices with no repeats, `answer` from 1 to the number of choices, a known colour, and an `entry` that exists in the library. Keep it passing as the bank grows.
- The choices are shown in the order written, never shuffled, so a shared result means the same thing to everyone.

## Today's puzzle

**Proposed:** ErgoCatalog `Puzzles/`, Foundation only so the widget and a Watch app can reuse it, the way Practice is.
- `PuzzleBank` loads the file and skips puzzles it can't read.
- `PuzzleAnswer` is one answered puzzle: its id, when, and the choice made (counting from 1, like the file). Never puzzle text.
- `today(bank:answers:date:calendar:)`: the puzzle finished today if there is one, so it stays on screen with its result, otherwise the first puzzle in the bank not yet finished. Nil when every one is done.
- **One a day.** Once today's is answered, the next waits until the next midnight on the device's clock, whenever in the day it was answered. That's what makes it a daily habit rather than a quiz.
- **One try.** The first choice is the answer, right or wrong, and it's finished either way. A puzzle you got wrong doesn't come back.
- **A streak** is the number of days in a row with a puzzle finished, worked out from the dates, never stored.
- **The end of the bank** says so ("That's every puzzle for now"), and the next one appears when an update adds more.

## Where it shows

**Proposed:**
- A card on the Library grid beside Practice, in the puzzle's colour, saying "Today's puzzle" or, once done, the result and the streak. A row in the wide sidebar (`LibraryRoute.puzzle`, `SidebarItem.puzzle`).
- **Past puzzles.** The Puzzles page lists every finished puzzle, newest first, each day in its own `Section` headed by its date: the quote, the question, the choices with the one picked and the correct one marked, and the explanation and library link. Today's sits at the top, or a "Today's puzzle" row when it hasn't been done. Unfinished puzzles never show, so nothing is spoiled.
- The puzzle page reuses Practice's pieces where they fit (`PracticeChoices` and `PracticeFeedback`, private to `PracticeQuestionView` today, and the haptic), with the quote set larger and the question in its colour.
- **Sharing a result** puts text through the share sheet, with no spoiler: "Ergo puzzle 12 ✓ · 5 day streak".
- **Later:** a widget for today's puzzle, a Watch complication (14), and an optional reminder notification.

## Sync

**Proposed:** each answer is a sync record of its own, kind `puzzleAnswer`, with the puzzle's id as its id and `date` and `choice` as fields, and `isValid(id:)` accepting a puzzle id the way `bookmark` accepts a catalog reference. An answer is never edited, so devices can't disagree about one. If two devices answer the same puzzle before syncing, the later stamp wins and the other answer is replaced. It's still one puzzle on one day. Like `bookmarks`, the answers are a Defaults key (in `TestDefaults.keys`) for signed-out use, synced one record per answer and never as a whole value.
