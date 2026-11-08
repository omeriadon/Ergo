# Plans

Ergo's design docs. Most of them are plans that have since been built, kept for the reasoning behind decisions. Where a doc and the code disagree, the code and `CLAUDE.md` win.

| Doc | What it is | State |
|---|---|---|
| [07-Direction.md](07-Direction.md) | Where the product is heading, and the checklist of what's next | Current |
| [HANDOFF.md](HANDOFF.md) | What a new agent needs beyond `CLAUDE.md` | Current |
| [09-Sharing.md](09-Sharing.md) | Sharing boards by link, and pushes | Built and deployed, not yet checked on devices |
| [10-BoardAnalysis.md](10-BoardAnalysis.md) | A server-side agent that annotates a board with library entries | Built, not yet checked on devices |
| [00-Translation.md](00-Translation.md) | The original plan: the server, ErgoKit and translation | Built, historical |
| [01-ErgoKit.md](01-ErgoKit.md) · [02-Server.md](02-Server.md) · [03-App.md](03-App.md) · [04-Evals.md](04-Evals.md) | The phases of that plan | Built, historical |
| [05-Sync.md](05-Sync.md) | Sync | Built, historical |
| [06-Canvas.md](06-Canvas.md) | The canvas, when boards still held logic | Built, then changed by 08 |
| [08-Tabs.md](08-Tabs.md) | Board, Logic, Ask, Library | Built, historical |
| [dither-device-corners.md](dither-device-corners.md) | A change note on the dither grid | Built, historical |
| `Fixtures/` | Output captured from the real CLIs | Reference |

The English conventions below are live: the server's formalize prompt and the eval corpus both follow them, and `formalizeHasTheEnglishConventions` in ErgoServer checks every line of the table is in `formalize.md`. Keep the heading as it is, and change the prompt with the table.

## English conventions (shared by the server prompts and the eval corpus)

The formalize prompt (02) and the corpus (04) must agree on these:

| English | Logic |
|---|---|
| if A, B / B if A / A only if B / whenever A, B | A→B, A→B, A→B, A→B |
| A means B / A implies B / A entails B | A→B |
| A if and only if B / A exactly when B | A↔B |
| A unless B | ¬B→A (≡ A∨B) |
| either A or B | A∨B (inclusive) |
| either A or B but not both / exactly one of | A⊕B |
| neither A nor B | ¬A∧¬B |
| not both A and B | ¬(A∧B) |
| A but B / A, yet B / A although B | A∧B |
| A because B / since B, A / B, so A / B; therefore A | premise B, conclusion A |

- Claims are positive and atomic. "The ground is not wet" is ¬(the ground is wet).
- Opposite words ("off", "dry") are their own claim. If an argument uses both words of a pair ("on" and "off"), one becomes the negation of the other, so the logic connects.
- One letter per distinct claim; the same claim reworded gets the same letter.
- Letters are assigned in order of first appearance in the English, even when the conclusion comes first.
- On a board that already names letters, a claim that matches a name keeps that letter, and new claims only take unnamed ones.
- "Unless" is the inclusive reading above. Plain "or" without "either" is inclusive too.
- Everyday "must", "can't", generic "you" and "whenever" are not □, ◇ or ∀. Use plain propositional logic unless the English is explicitly about necessity or about all/some things.
- "Exactly one of A, B, C" is not A⊕B⊕C (that means an odd number are true). Spell it out.
- A single "because" sentence is an argument with one premise. Never add the unstated premise.
- How premises are split doesn't matter. Scoring compares all the premises joined with ∧, and the conclusion separately.
