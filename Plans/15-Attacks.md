# 15 · Attacks

Arrows that count against something, next to the arrows that support it.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## Why

Today every arrow means "premise of". An objection or a rebuttal can only sit beside what it's against, unlinked: the templates say so, and Quick AI's `add_card` tells the model to leave objections without an arrow. So the board can show why someone believes something, but not the disagreement around it, which is most of what an argument is. A canvas app can't draw that, and a chat can't keep it.

## Two kinds of attack

**Proposed:** the two that argumentation theory separates, since they say different things and the analysis treats them differently.

| Kind | Points at | Means | Example |
|---|---|---|---|
| **Rebuts** | a card | "This counts against that claim" | "Most swans in Australia are black" against "All swans are white" |
| **Undercuts** | an arrow | "This claim may be true, but it doesn't support that one" | "The survey only asked people who already agreed" against the arrow from "Most people surveyed agreed" to "Most people agree" |

Support stays the only kind of arrow that makes a premise. An attack never makes its card a premise of anything, so it never changes what the outline nests under what.

## The model

**Proposed:** an attack is its own type, not a kind of `Link`.

```swift
nonisolated struct Attack: Codable, Hashable, Identifiable, Sendable {
	enum Target: Codable, Hashable, Sendable {
		case statement(UUID) // rebuts
		case link(UUID) // undercuts
	}

	var id: UUID
	var from: UUID // a statement
	var target: Target
}
```

`Board` gains `attacks: [Attack]`. Reasons it's separate:
- **`ArgumentMap` stays about support.** Its validator rejects cycles, and its topological order, layout and outline all assume support. Two claims that rebut each other are an ordinary cycle of attacks. Keeping attacks out means none of that code changes meaning.
- **Older apps.** A sync kind is a string an older app ignores (`SyncKind`). A new `attack` kind just doesn't show up in an older app. A `kind` field on `link` would be dropped instead, and an older app would draw an objection as support.
- **An undercut points at an arrow,** which a `Link` can't do.

Rules, checked by an `AttackValidator` in ErgoLogic beside `ArgumentMapValidator`: an attack's card and target exist on the same board, a card doesn't attack itself or an arrow it's an end of, and there's at most one attack from a card to a target. Deleting a card deletes its attacks and attacks on it. Deleting an arrow deletes the attacks on it.

## Sync

**Proposed:** a new kind `attack` (id: the attack's uuid; fields `board`, `from`, `target`, `deleted`), where `target` is `statement:<UUID>` or `link:<UUID>`. It works like `link`: tombstoned when either end goes, ignored with its board's tombstone (`SyncReplica.isIgnored`), and added to `SyncKind.known` and `fieldNames`. The server's role checks for shared boards treat it like `link`, so a viewer can't write one (see `Notes/SharingBoards.md`).

## Older apps on the same board

An older app can't see attacks, so it can write things around them that a newer app wouldn't allow: on a shared board, or the same person on an old iPad. The board survives this already for arrows. `BoardRecord.links` rebuilds a board's arrows from the records in a fixed order (by id) and only keeps the ones `ArgumentMapValidator` accepts, so two devices drawing A→B and B→A at once both end up showing the same one arrow, and `deleteDanglingLinks` tombstones an arrow whose card another device deleted. Nothing a sync brings can make a board invalid, only make it lose an arrow.

**Proposed:** attacks get the same two steps, after the arrows are rebuilt:
- **Rebuilding.** Attacks are added in id order and kept only when `AttackValidator` accepts them against the rebuilt arrows. Support wins over an attack, since every app can see support.
- **Cleaning up.** A newer app that can edit the board tombstones the attacks the rebuild dropped, the way `deleteDanglingLinks` does, so they don't come back if the arrow that blocked them is later deleted.

What an older app can cause, and what happens:

| An older app | Result on a newer one |
|---|---|
| Deletes a card that attacks or is attacked | The statement's tombstone only takes its links. The attack is dangling, is dropped, and is cleaned up. |
| Deletes an arrow that's undercut | The undercut is dangling, is dropped, and is cleaned up. |
| Draws support between two cards where one already attacks the other | Both can't stand. The support stays, and the attack is dropped and cleaned up. |
| Edits the text of a card so an attack no longer makes sense | Nothing stops it, the same as on a newer app. |

The server deploys before the app, since an older server would refuse to store `attack` records. Once it's deployed the app can push them, with no protocol bump: no older app misreads a kind it ignores.

## On the canvas

**Proposed:**
- **Drawing one.** Dragging from a card's handle works as now. Dropping on a card asks "Supports" or "Counts against", with the last choice first. Dropping on the middle of an arrow makes an undercut, with nothing to ask. The Mac's hover handles and right-click do the same.
- **How it looks.** An attack ends in a flat bar (⊣), not an arrowhead, and is drawn in a neutral colour with a long dash. It must never look like the analysis's green, orange and red, which judge support. An undercut ends on the middle of the arrow it's against.
- **The arrow menu** gains "Count against" and "Support" to switch an arrow between the two, and only offers what's allowed: an arrow that's a premise can't become an attack on a card that's an end of it.
- **Regions** leave attacks out for now. A card from a source that attacks something outside it doesn't pull the region over.

## What stands

**Proposed:** the board works out, never stores, which claims have objections still open, by grounded labelling: a card is **answered** when every card attacking it is itself out, and **open** when some card attacking it stands unanswered. An arrow is labelled the same way from its undercuts. It's a pure function in ErgoLogic, tested with `swift test`, and cycles of attacks with nothing outside them come out undecided rather than going round forever.

It's shown as a small marker on a card or an arrow with an open objection, and a toolbar toggle that fades what doesn't stand. The words are "open objection" and "answered", never "false" or "defeated": the board knows that an objection hasn't been replied to, not that it's right. That's the same line the analysis draws about a premise's truth.

## Templates

**Proposed:** Objection and Reply and Toulmin's rebuttal become attacks, so the objection rebuts the claim and the reply rebuts the objection. Pros and Cons keeps the cons apart, since a con isn't aimed at any one pro.

## The outline and exports

**Proposed:** an attacked card lists its attackers under it, after its premises, marked "Against". An undercut is listed under the premise of the arrow it's against, marked "Against this as a reason". `ArgumentOutline` and `ArgumentOutlineMarkdown` take the attacks, so the outline view and the markdown export still read the same. `BoardPicture` draws them as the canvas does.

## AI

**Proposed:**
- **Quick AI** gets `object_to(card, target)`, where the target is a card or an arrow, and `remove_objection`. `add_card`'s note about leaving objections unlinked goes, and `board.md` says what an attack means. The board text the model reads lists attacks under their targets, as the outline does.
- **Deep Research.** `BoardAnalysisRequest` gains an optional `attacks`, so the model sees the disagreement already on the board. An older server ignores it. A finding's `objection` is added as a card that rebuts its target, or undercuts it when the finding is about an arrow, instead of a loose card.
- **Not yet:** attacks as an annotation target. `BoardAnalysisTarget` throws on a kind it doesn't know, so a new case needs a fallback that older apps can read first (`Notes/Versions.md`).
- **Not yet:** Break Down finding objections in a text. The breakdown is premises and a conclusion, and a text's counterarguments are the next thing to try once attacks exist.

## Not in this

- A third kind of arrow, or weighting attacks by strength. Strength is the analysis's job.
- Judging whether an objection succeeds. The board only knows whether it has been answered.
