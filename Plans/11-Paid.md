# 11 · Paid

What's free and what's paid. Nothing here is built or priced. **Proposed** means it's on the table but not agreed. Monetisation comes after users, so this doc is a record of the thinking, not a schedule.

**Decided:** the Scratchpad is free. Its logic checker, English reading and saved scratchpads stay free, because they're the reason someone tries the app.

**Decided:** the Library is what sets Ask apart from a general chatbot, so it stays free and is never gated.

## Free

- All four tabs, with the Library and widgets.
- Scratchpads: the logic checker, `LogicEnglish` readings and saved scratchpads.
- Ask on the person's own Claude or Codex account.
- Break Down on a short block of text (up to `EnglishValidator.characterLimit`).

## Paid, in order

Each one is a separate reason to pay. The first is the most valuable, but it's also the one that changes the cost model, so it comes last to build.

1. **Shared boards.** Sharing a board as an editor or viewer, through the sharing already in [09-Sharing.md](09-Sharing.md). Teachers and teams are the clearest buyers, since one payment covers a class or a group. Built, but not yet checked on devices, so this waits for that.
2. **The logic course.** A guided course on the logic language and its fallacies, built on the Logic tab. It's the Scratchpad made into a lesson, with the free checker staying free. Direction's "Teach the user the logic language" is the starting point.
3. **A better model in Ask.** Better answers from a model the person doesn't pay for directly. **Proposed, with a catch:** today Ask runs on each person's own account, so Ergo pays nothing for AI. A paid model means Ergo pays for the model, so the price has to cover usage. Settle the budget before this is built.

## Open

- **Board analysis.** Free for now. Whether it's free, or limited by runs, depends on what it costs once a better model exists.
- **Long text into Break Down.** See below. It's free up to the current limit, and the tier for longer text isn't decided.

## Long text into Break Down

Break Down stops at 1,500 characters, and most real articles are longer. A pad would let someone paste more text and send it in parts, so one board comes out of a longer piece.

**Proposed:**
- The pad takes text of any length and shows how many parts it will become.
- Parts split at paragraph breaks, so no claim is cut in half, each under the limit.
- Each part is broken down in its own run, and the cards from every part go onto one board. Duplicate claims that repeat across parts are merged.
- Each run is its own server run, so a part that fails doesn't lose the others. This follows the rule for anything that talks to the server and takes a while: a run the server owns, found again by id.

**Open:**
- Whether the pad belongs to the free tier or the paid one. It's the most useful part of the paid tier to people who read a lot, but it also takes the most AI calls.
- How many parts are allowed before it asks first.
