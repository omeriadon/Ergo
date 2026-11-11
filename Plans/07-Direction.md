# 07 · Direction

Where the product is heading. It's a living record of the conversation, so it changes as the thinking does. [What's left](#whats-left) is the list of what's still to do.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

**Decided:** until v1, migrations and existing data are not a constraint. Don't let them limit any idea here.

## What's left

A list of what's still to do, with no status. The code says what's built.

Adon's working list:
- iPad, and iPhone Duo.
- More tests, and trying to break the UI by hand.
- Bug fixes.

Before strangers use it:
- **A first run.** An intro, the privacy statement and AI consent, and a short tutorial for what isn't obvious, like tapping a tab again. The legal screens name every provider that gets what's sent. The rest of the app never names OpenRouter.
- **A privacy policy and terms**, linked from the app and the paywall. The server hosts them at `/policy` and `/terms`.
- **Password reset and verified email.** Waits on a mail provider.
- **Reports reach Adon by email.** They're saved on the server, and wait on the same mail provider.
- **The App Store products** and prices.

It can wait:
- An eval for Ask and deep research.
- Accessibility on the canvas.
- Checking that a finding's quote is really in the source.
- Ask's tools over the person's own boards and scratchpads.
- Making a board from a source's annotations. See [Finding problems in a text](#finding-problems-in-a-text).
- Merging repeated claims across the parts of a long Break Down.
- Making deep research faster.
- More widgets, a Watch app, and other languages.
- More than one server instance.
- Analytics: events, never content.

## The tabs

**Decided:** Board, Logic, Ask, Library. **Built:** all four.

| Tab | What it is | State today |
|---|---|---|
| **Board** | A workspace for pulling arguments out of what you find and analysing them | Built: a canvas of cards, arrows and sources, with Break Down and an analysis that annotates them from the library |
| **Logic** | Writing and converting formal logic | Built: saved scratchpads |
| **Ask** | An AI chat with tools over the library and your work | Built: tools over the library, modes, and a board chat that edits its board. Nothing over the rest of your work yet |
| **Library** | The catalog | Exists, and is the most settled part of the app |

A More tab is only for the distant future, if the app ever gets past four or five tabs.

## Board

You paste in links, blocks of text and documents. They become arguments, diagrammed on the board. Those pieces of material sit on the board themselves, and the model or the user turns them into premises and analyses them.

- Cards are claims, and arrows show inferential strength.
- The conclusion gets extra analysis of its cogency.
- Any card or arrow shows the biases, fallacies, concepts and arguments it touches.
- It's academic and intellectual in tone, and never references the logic language.
- It's heavily AI-dependent.

## Logic

**Decided:** Logic is its own tool, separate from the Board.

- No canvas. As built, logic is on top with its English reading below it, rather than side by side.
- The Board does not formalise cards or use logic to back its arrows. Real-world articles argue from evidence, analogy and best explanation, so very few of them would benefit from formal logic.

**Decided:** the Logic tab is a list of saved scratchpads, each holding a whole argument. **Built:** statements on the Board are English only, and logic lives in scratchpads.

## Text into cards

**Decided:** Edit as Text goes away. Turning a block of text into cards is Break Down's job, and writing logic is the Logic tab's. The sheet is removed from the app.

**Built:** Break Down also adds to an existing board, and breaks down a source already on it, because pasting more material into a board is the core of the Board's future. Adding never edits, moves or deletes existing cards.

Accepted cost: pasting a whole argument into cards now needs AI, and without it cards are added one at a time.

## Finding problems in a text

Adon's idea: paste text or a web page, and the model finds the fallacies and other problems in it. It could share chat's backend with a different front end. Two shapes are open: an AI version of Break Down that makes a new board taking it apart, or the text kept whole with comments and annotations on it.

**Proposed:** both, as two views of one result, with annotations first.
- One analysis returns findings, each with a library entry and an exact quote, as in AI grounding below. Annotations are those quotes highlighted in the text, so every finding can be checked against its words.
- Most of a real article isn't premises or a conclusion, so the text keeps everything a board would leave out.
- It isn't a separate mode. A board's source is already a block of text or a link, so annotating a source is the Board's analysis. A board can then be made from it, with each card keeping the findings whose quotes fall in its claim.
- Size matters. Break Down stops at 50,000 characters, while a page can be much longer, so long texts need to be analysed in parts.

## AI grounding

**Decided:** the AI only makes claims it can cite from our own library, so its analysis is more accurate and neutral.

**Proposed:** each finding carries two anchors, a library entry and an exact quote from the source. Both can be checked by machine: the entry exists, and the quote is really in the source. This is the same idea as the app re-parsing translated logic before applying it.

Limits to design around:
- **A citation doesn't prove the finding.** The library defines ad hominem, but deciding that this passage commits it is still the model's judgement. The UI shouldn't present that as fact.
- **A fixed list encourages forced matches.** "Nothing found" has to be a normal result, and the eval corpus should include clean arguments that must come back unflagged.
- **Some things have nothing to cite.** The library can't say whether a factual premise is true. That should show as "not assessed", not fall back on the model's own knowledge.
- **The library has to grow with this.** Inferential strength and cogency need their own entries to cite.

## Accounts and analytics

**Decided:**
- AI features, Ask included, need an account, even though the user brings their own model login. Anonymous use is at most the non-AI parts of the app.
- The model never gets fewer tools or less data because someone hasn't signed in, since everyone reaching it has an account.
- The app pushes its pending sync changes before starting an AI request, so the server's tools don't read a copy that's behind the device.
- Analytics logs events, not content. It answers how much each feature is used, which capabilities get used, and the spread from heavy to light users, and it can tie logged errors back to what happened.

**Proposed:**
- Events and errors share a random analytics ID rather than the account's identity, and it's removed on account deletion.
- Error logs get checked for content, since an error message or CLI output could quote what the user pasted. Otherwise content reaches analytics through the back door.

## Tools

**Decided:** one implementation shared by App Intents and the model.

- The body of each intent's `perform()` moves into a shared package. The app's intent calls it, and so does the server, which has its own copy of the catalog.
- Each intent only needs a couple of lines to call through.
- The server exposes the functions to the Claude Code and Codex CLIs over MCP.
- Intents that need `NavigationManager` can't run on the server. The model returns them as a button, and they run on the device when tapped.

**Proposed:**
- Shared functions use plain types. App Intents won't compile on the Linux server, so converting to `AppEntity` stays on the app's side.
- Tools run from a fixed list in a sandbox with nothing else available, because pasted articles can contain instructions aimed at the model. Anything destructive never becomes a one-tap button.

## Response format

**Decided:** responses are nicely structured markdown by default, with inline links to library items and buttons at the end. Both CLIs' models are capable of following this.

**Decided:** an inline library link is not a separate system. It's the same invocation as `OpenLibraryEntryIntent`, an intent and its parameters. Links and buttons are one concept with two appearances.

**Proposed:**
- Markdown has to carry a link as a URL, so that URL only encodes the intent and its parameters. The chat view intercepts it with an `OpenURLAction` and runs the intent. No registered URL scheme or deep link handling is needed.
- Buttons come from an MCP tool such as `suggest_action(intent, parameters)`, not from a block of JSON in the text. The tool's schema validates them, and the text stays pure markdown while it streams.
- The server still checks what comes back, because a capable model can still invent an ID. A link to an unknown entry becomes plain text, and an action outside the list is dropped.

## Versions

See [13-Versions.md](13-Versions.md), which covers the protocol and the catalog.

## Built so far: Ask

See `CLAUDE.md`'s Ask section for how it works.

**Decided along the way:**
- Translation never returns logic that verify rejected. A wrong split of premises goes back to breakdown instead of failing every retry.
- The library moved into ErgoKit (`ErgoCatalog`), since the server needs it too.
- Markdown is a small renderer of our own over Foundation's parser, not a package. It needs no dependency, handles text still arriving, and leaves links to the app.
- Conversations stay on the device, for now.

**Not built yet:**
- Tools over the user's own boards and scratchpads. A board chat sees and edits its own board only.
- Rich answers beyond markdown and buttons, like entity cards.
- `Find text` as a tool, and any intent beyond the library and navigation ones.
- Enforcing that findings quote the source. It's in the prompt, not checked.

## Built so far: Sharing boards

Boards can be shared with other people by link, who can edit or only view, through the system share sheet, and pushes when something changes. See [09-Sharing.md](09-Sharing.md) for the design and what's left, and `CLAUDE.md`'s Sharing boards section for how it works.
