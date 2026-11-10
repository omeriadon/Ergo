# 12 · Identity and the board's AI

Built, apart from the tagline. Web search is only on deep research on Ergo's model, as a few results the server fetches once at the start of a run, so the model can't choose to search and a person's own Claude or ChatGPT login doesn't get it.

What Ergo is, who it's for first, and how its AI should work. Nothing here is built yet.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## What Ergo is

**Decided:**
- The working slogan is "Think better." The line under it waits until the app is built.
- The first person it's for is someone like Adon: curious, into philosophy, and in no hurry. Students have a curriculum, though the library and chat still help them.
- After five minutes someone has a stronger argument or a clearer map.
- It does several things, but not too many: boards, debate, finding fallacies, testing what you believe, and the library.
- **The board leads.** It's the first App Store screenshot.
- The value isn't the model. It's how the model is used: seeing the board, working from the library, and leaving something on the canvas.

## What was wrong with the analysis

Adon tried breaking down a document and analysing what came out. It was slow, and the result was a plain list that was hard to get anything out of, with no colour.

Reading the code, there are two causes:
- `analyse.md` asks for anything in the library that's relevant to each part of the board, so the result is a scatter of "this resembles X" notes. Nothing ranks them, and nothing has to add up to where the argument breaks.
- It's one agent loop of up to 400 turns and 10 minutes. Each note takes a search, a read and a report, and every turn resends everything so far.

## Reasoning and the library

**Decided:**
- The model reasons for itself about structure, gaps and objections.
- It never invents a concept. A fallacy, bias, thinker or concept it names must be a library entry, linked. An objection that claims a named fault must use the entry for it.
- Web search is optional, for boards about a specific topic, and the model is told that abstract topics often don't need it. Anything from the web is cited, with a syntax for the model to mark citations.

**Built** in `analyse.md`, without web search: the model works out where the argument's weight rests before it reports, keeps to findings that matter, and works in batches. Every report still cites an entry, since the tools require one, and a finding with no special name cites a general entry like `premise`. Not yet run on a real board. Ask's prompt is unchanged.

It still never rules on whether a premise is true. **Open:** whether web search changes that for a checkable fact.

## The board annotates itself

**Decided:**
- Results appear on the canvas: colour coding, dotted lines and comment boxes.
- When it finds a weak spot, it points it out and can add the objection to the board.

**Built:** arrows and conclusions are green, orange or red, weak arrows stay dashed and unsupported ones dotted, a card or source shows its first finding in a comment box, and an arrow with something to say gets a label. Tapping any of them opens that finding. Not yet checked on a device.

**Proposed:** the two or three findings that matter most are marked as such, so the board has a clear point. Objections as cards need a new report tool.

## Two speeds

**Decided:**
- **Quick AI.** A normal chat shown next to the canvas, and it can have its own row in the Ask list. A toolbar button opens it in a sheet with full and half detents, in the same view as chat. You start by talking to it. It sees the board in a form it can reason about, and it can edit the board. It runs at Ask's speed.
- **Deep research.** An item in the ⋯ menu that takes minutes, with a Live Activity, and tells you when it's done.

To make deep research faster and cheaper, the prompt now tells the model to batch its searches, reads and reports. That hasn't been measured. Not done:
- One tool call reports many findings, rather than one each.
- Give it the names of the library's entries up front, so it searches less.
- A first pass decides what matters, then the parts run at the same time.

## Modes in Ask

**Decided:**
- Debate is a mode in Ask. You ask the model to debate, it calls a tool (`requestChangeMode` or similar), and you accept or deny. The mode then changes the system prompt.
- More modes will come, so the tool and prompts are general.
- In the Ask list, tapping plus starts a normal chat and a long press lists the modes (a `Menu` with a `primaryAction`).
- A toolbar button sends the board to chat.

**Decided:** a fallacy finder is a feature, partly because it teaches the library.

## Open

- The Logic tab's place, and whether the course makes it worth keeping up front.
