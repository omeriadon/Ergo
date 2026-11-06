# 07 · Direction

Where the product is heading. The tabs and scratchpads are built (see [08-Tabs.md](08-Tabs.md)); the rest isn't built or scheduled. It's a living record of the conversation, so it changes as the thinking does.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

**Decided:** until v1, migrations and existing data are not a constraint. Don't let them limit any idea here.

## The tabs

**Decided:** Board, Logic, Ask, Library. **Built:** the four tabs, with Ask as a placeholder.

| Tab | What it is | State today |
|---|---|---|
| **Board** | A workspace for pulling arguments out of what you find and analysing them | The Check tab, renamed. Symbol `flowchart` (**Proposed**, not yet checked at tab bar size) |
| **Logic** | Writing and converting formal logic | Moves out of the canvas |
| **Ask** | An AI chat with tools over the library and your work | Replaces the Debate placeholder, which was going to be a kind of chatbot anyway |
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

- No canvas. It's a split view, English on one side and logic on the other.
- The Board does not formalise cards or use logic to back its arrows. Real-world articles argue from evidence, analogy and best explanation, so very few of them would benefit from formal logic.

**Decided:** the Logic tab is a list of saved scratchpads, each holding a whole argument. **Built:** statements on the Board are English only, and logic lives in scratchpads.

## Text into cards

**Decided:** Edit as Text goes away. Turning a block of text into cards is Break Down's job, and writing logic is the Logic tab's. The sheet is removed from the app.

`ArgumentText` and its related types in ErgoKit are still there, with no callers outside ErgoKit and its tests. The argument checks don't depend on them.

**Proposed:** Break Down also adds to an existing board, not only a new one, because pasting more material into a board is the core of the Board's future. `ArgumentBreakdown.applied(to:replacing:)` already takes a `replacing` flag, though every caller passes `true` today. Adding never edits or deletes existing cards.

Accepted cost: pasting a whole argument into cards now needs AI, and without it cards are added one at a time.

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

## API versions

Today `ProtocolVersionMiddleware` requires an exact match with `ErgoProtocol.version`, and otherwise returns `outdatedApp`. So any bump cuts off every older app at that moment.

**Decided:**
- Spend longer getting the API right up front, so that when a new version is needed, adding one is fine. Don't bump it for every change.
- Old apps ignore what they don't recognise. Response blocks, button kinds and similar types decode to an `unknown` case instead of failing, so a new block type doesn't need a version.
- The server checks a minimum supported version instead of an exact match. That leaves room for one version of overlap, and retiring an old version is a deliberate choice.

**Proposed:**
- Additions don't bump the version: new optional fields, new endpoints and new block types. Only breaking changes do.
- `outdatedApp` becomes the friendly "please update to keep using cloud features" message.

## Catalog versions

**Decided:** the catalog ships inside the app, and a new catalog goes out as an app update. There is no download from the server.

**Adon's leaning, not final:** the server keeps the newest catalog plus the previous one, and older apps get the "please update" message.

**Proposed:**
- IDs are permanent. Entries can be added and edited, but an ID is never renamed or removed, so an older app only ever lacks new entries. Bookmarks rely on this too.
- The app sends its catalog version with AI requests, and the server only offers the model entries that version has. Then the model can't cite something the app can't open.
- The server's catalog updates only once the matching app release is live, not before.
