# 07 · Direction

Where the product is heading. Nothing here is built or scheduled, and no code changes come from this document yet. It's a living record of the conversation, so it changes as the thinking does.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## The tabs

**Decided:** Board, Logic, Ask, Library.

| Tab | What it is | State today |
|---|---|---|
| **Board** | A workspace for pulling arguments out of what you find and analysing them | The Check tab, renamed. Symbol `flowchart` (**Proposed**, not yet checked at tab bar size) |
| **Logic** | Writing and converting formal logic | Moves out of the canvas |
| **Ask** | An AI chat with tools over the library and your work | Replaces the Debate placeholder, which was going to be a kind of chatbot anyway |
| **Library** | The catalog | Exists, and is the most settled part of the app |

A More tab is only for the distant future, if the app ever gets past four or five tabs.

## Board

You paste in links, blocks of text and documents. They become arguments, diagrammed on the board.

- Cards are claims, and arrows show inferential strength.
- The conclusion gets extra analysis of its cogency.
- Any card or arrow shows the biases, fallacies, concepts and arguments it touches.
- It's academic and intellectual in tone, and never references the logic language.
- It's heavily AI-dependent.

## Logic

**Decided:** Logic is its own tool, separate from the Board.

- No canvas. It's a split view, English on one side and logic on the other.
- The Board does not formalise cards or use logic to back its arrows. Real-world articles argue from evidence, analogy and best explanation, so very few of them would benefit from formal logic.

**Open:**
- `Statement` holds both a claim's English and its logic today. Once logic leaves the Board, what does a Logic tab document look like, and how does it sync?
- What happens to logic already saved on existing canvas pages?

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
- Usage gets logged for analytics.

**Proposed:** the app pushes its pending sync changes before starting an AI request, so the server's tools don't read a copy that's behind the device.

**Open:** what analytics includes. Event and usage metadata is simple. Pasted documents and chat content are much more sensitive, and logging them would need clear disclosure, matching App Store privacy labels, and removal on account deletion.

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

**Proposed:**
- Library links are ordinary markdown links with a custom URL, such as `ergo://library/fallacies/a-priori-argument`. The app has no URL scheme yet.
- Buttons come from an MCP tool such as `suggest_action(intent, parameters)`, not from a block of JSON in the text. The tool's schema validates them, and the text stays pure markdown while it streams.
- The server still checks what comes back, because a capable model can still invent an ID. A link to an unknown entry becomes plain text, and an action outside the list is dropped.

## API versions

Today `ProtocolVersionMiddleware` requires an exact match with `ErgoProtocol.version`, and otherwise returns `outdatedApp`. So any bump cuts off every older app at that moment.

**Decided:** spend longer getting the API right up front, so that when a new version is needed, adding one is fine. Don't bump it for every change.

**Proposed:**
- Additions don't bump the version: new optional fields, new endpoints and new block types. Only breaking changes do.
- Old apps ignore what they don't recognise. Response blocks, button kinds and similar types decode to an `unknown` case instead of failing, so a new block type doesn't need a version.
- The server checks a minimum supported version instead of an exact match. That leaves room for one version of overlap, and retiring an old version is a deliberate choice.
- `outdatedApp` becomes the friendly "please update to keep using cloud features" message.

## Catalog versions

**Adon's starting idea, not final:** nag users to update, keep only the current and previous catalogs on the server, and show a clear update message past that.

**Proposed instead:** remove most of the mismatch, and keep the update message as the backstop.

1. **IDs are permanent.** Entries can be added and edited, but an ID is never renamed or removed. A replaced entry keeps its old ID as an alias. Bookmarks and old citations rely on this too.
2. **The app downloads the catalog.** It ships with a bundled copy, so the Library always works offline, and fetches the newest one from something like `GET /v1/catalog` when it changes.
3. **The catalog gets a schema version** that only changes when the shape of an entry changes. That's the only case that needs an app update.

Fixing a typo or adding a fallacy then never needs an App Store release, and the server only keeps one catalog. An ordinary sync of the catalog closes the window in which the model could cite an entry the app doesn't have.

**Open:**
- Are the library's views ready for content changing after release?
- `LogicFallacyForm` IDs have to match `fallacies.json`, so what happens when a downloaded catalog is newer than the app's code? Permanent IDs should cover it, but it needs checking.
