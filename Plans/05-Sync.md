# Phase 5: Sync

Everything the user makes or chooses in Ergo follows them to their other devices, through the Ergo server. It works offline, merges edits made on two devices at once without losing typing, and never needs a "which version do you want to keep" prompt.

Read [README.md](README.md) first. Its ground rules apply here too.

## What syncs

Synced data is the user's stuff. State about where this particular screen is stays on the device: syncing it would make your iPad jump tabs when you change tab on your phone.

| Defaults key | Syncs | Why |
|---|---|---|
| `boards` | yes: a record per board, per statement and per link (see 06-Canvas) | The user's work |
| `bookmarks` | yes, one record per bookmark | The user's library |
| `logicLetters` | yes | A preference |
| `ditherEnabled` | yes | A preference |
| `translationProvider` | yes | A preference |
| `translationServer` | **no** | It says where the server *is*, so it can't come from the server |
| `currentBoardID` | no | Which board this screen shows |
| `selectedTab`, `libraryPath`, `debatePath`, `presentedSheet`, `libraryGeneralSearchText` | no | Navigation state of this screen (Handoff can do this later) |
| `lastIndexedVersion` | no | Spotlight's index on this device |

Every future Defaults key needs a decision here. `SyncedSetting` (below) is the list, so leaving a key out of it means it stays local.

### Why not something built in

- **Defaults' iCloud sync** (`NSUbiquitousKeyValueStore`): 1 MB in total, and it replaces whole values. Two devices editing different boards would overwrite each other's `boards` array.
- **CloudKit:** works, but it's Apple-only and separate from the account the server already has. Adon asked for server sync, and the server already exists.

## Identity: Sign in with Apple

Anonymous accounts are one per install, so they can't link devices. Signing in with Apple gives the same stable user id (`sub`) on every device with the same Apple ID.

- **Translation keeps working without signing in.** The anonymous account from phase 2 still exists.
- **Sync needs sign-in.** Without it nothing is uploaded. A backup nobody can reach from another device isn't worth holding someone's notes on a server.
- **Tokens are per device, not per account.** Replace `Account.tokenHash` with an `AccountToken` table (`id`, `account`, `tokenHash`, `created`, `lastSeen`). One account has one token per device, so one device can be signed out without the others.

### Signing in (`POST v1/account/apple`, bearer = this device's current token)

1. **App:** makes a random nonce, puts `SHA256(nonce)` in the Apple request, and sends the server `{ identityToken, nonce }`.
2. **Server:** verifies the identity token with Apple's public keys (`vapor/jwt`, `req.jwt.apple.verify(…, applicationIdentifier: ERGO_APPLE_APP_ID)`), and checks that its `nonce` claim is `SHA256(nonce)`. That stops replays.
3. **Server, no account has this `sub`:** it's attached to the caller's account. The response returns the same token.
4. **Server, another account has this `sub`** (the user's first device): the caller's account is **merged** into it:
   - Connections: the caller's credential for a provider moves over only if the target has none for that provider.
   - Sync records: merged with the same `SyncRecord.merge` the sync route uses (normally there are none, since anonymous accounts don't sync).
   - The caller's token moves to the target account. Then the caller's account is deleted.
   - All of this happens in one transaction.
5. **Response:** `SignedIn { accountID, token, isNewAccount }`. The app stores the token (same Keychain item as before), then does a **full sync**: cursor reset, everything local pushed.

### Signing out (`DELETE v1/account/token`)

- Deletes only this device's token.
- **The app keeps the data on the device.** It forgets the sync state and makes a new anonymous account the next time it needs one. Signing in again merges as normal.

### Deleting the account (`DELETE v1/account`)

- This exists already. Now it also deletes the sync records and every token.
- The App Store requires account deletion in the app (guideline 5.1.1(v)), so Settings has it.
- Data on the devices stays.

### Apple setup Adon has to do

- The app needs the Sign in with Apple capability (`com.apple.developer.applesignin = ["Default"]`). Add `Ergo/Ergo.entitlements` and set `CODE_SIGN_ENTITLEMENTS`. Automatic signing with team `C2HN547N49` should update the App ID, but Adon has to check that in the developer portal.
- Server: `ERGO_APPLE_APP_ID`, default `com.adonis.Ergo`.

## The data model

### Records and fields

Everything synced is a **record**: `kind` + `id` + a set of named **fields**. Each field holds a JSON value and a **stamp**.

| kind | id | fields |
|---|---|---|
| `board` | board UUID | `created`, `descriptor.0` … `descriptor.5`, `deleted` |
| `statement` | statement UUID | `board`, `position`, `content`, `deleted` |
| `link` | link UUID | `board`, `premise`, `conclusion`, `deleted` |
| `bookmark` | `CatalogReference.id` | `present` (Bool) |
| `setting` | `SyncedSetting` raw value (`logicLetters`, `ditherEnabled`, `translationProvider`) | `value` |

Ids of boards, statements and links are uppercase UUID strings.

- **A board is a canvas** (06-Canvas). It has no content of its own any more: the server refuses a `content` field on a board. What a board used to hold lives on its statements.
- **A statement's `content` field** holds `{ english, logic, source, translation }`, together. English and logic are linked (one follows the other), so mixing one device's English with another's logic gives a statement that contradicts itself. The server treats it as an opaque `JSONValue`, as it did for boards.
- **`position`** is `{ x, y }`, written when a drag ends. It is its own field, so dragging a box never clashes with typing in it.
- **`board`** (on a statement or a link) is the owning board's id. The server keeps a copy of it in the clear (like the record id) so pruning can find a deleted board's statements and links without opening them.
- **A link's `premise` and `conclusion`** are statement ids: the arrow runs from the premise to the conclusion.
- **Descriptors are one field per slot.** Naming X on the phone and Y on the iPad keeps both.
- **`modified` isn't a field.** The app works it out from the newest stamp in the record, so the boards list sorts the same way on every device.
- **Bookmarks** store only the id. The app rebuilds the `CatalogReference` from the catalog, and drops ids the catalog no longer has (from an older or newer app version) without deleting the record.

### Stamps: hybrid logical clocks

Merging is **last writer wins, per field**. Last is decided by a stamp that's safe against clock skew:

```
SyncStamp { time: Int64 (ms), counter: Int, device: String }   compared in that order
```

- **On each local change:**
  - `time = max(correctedNow, last.time)`
  - `counter = (time == last.time) ? last.counter + 1 : 0`
- **On each stamp received:** `last = max(last, received)`. The next local change is always newer than anything this device has seen, so an edit made after reading another device's edit always wins over it, even with a slow clock.
- **`correctedNow`** is the device clock plus an offset to server time. Every sync response carries `serverTime`; the offset is a smoothed `serverTime - deviceTime`. One device with a wrong clock can't win every merge.
- **The server refuses** stamps more than 10 minutes ahead of its own clock, with `.invalidRequest("Expected a time within 10 minutes of the server, found …")`. With the offset correction this only happens to tampered clients.
- **`device`** is a random id made once per install (Defaults `syncDeviceID`, not synced). It only breaks ties.

### Merging

`SyncRecord.merge(_:_:)` keeps, for each field, the value with the higher stamp.
- It's commutative, associative and idempotent, so all copies agree whatever order changes arrive in.
- **The server and the app run the same function**, from ErgoKit.

**Deletion** is a `deleted: true` field, a tombstone. A record counts as deleted only if `deleted`'s stamp is newer than every other field's stamp:
- If one device deletes a board while another keeps typing in it, the typing brings the board back.
- Deleting and then undoing on the same device is just a newer `deleted: false`.

### Deleting a board: cascading

A board's statements and links are records of their own, so deleting a board can't delete them in the same write. A board tombstone instead makes them **ignored**, and pruning removes them:

- **On read, ignored:** a statement or link whose board is deleted (`isDeleted`) or missing is ignored, and so is a link whose premise or conclusion statement is deleted or missing. The app drops them from the board it shows; the replica offers `isIgnored(_:)` and `ignored` for it. Judge after a pull has finished, since a board can be "missing" only because it hasn't arrived yet.
- **Nothing is removed by a delete.** A board brought back (a newer `deleted: false`, as an undo) brings its statements and links with it.
- **Typing in a statement doesn't revive a deleted board.** It used to, when the text was the board's own field. Now a statement edited on one device while the board is deleted on another is ignored with the board. Undo is the way back.
- **On the server, pruned:** when a board's tombstone is pruned (90 days), so are all its statements and links whatever their age. Statements and links with no board record at all, or no `board` field, are pruned once they haven't changed for the same 90 days (the grace is because a board can arrive after its statements). Those leftovers don't move `Account.prunedThrough`, since they say nothing a client needs to hear. A deleted statement or link is an ordinary tombstone, pruned and counted like a board's. A link whose statement is gone but whose board lives is ignored but not pruned (the app deletes its links when it deletes a statement).
- **On a device, the same:** `SyncReplica` drops the statements and links of a board whose tombstone it prunes, and doesn't push ignored records back after a reset, so an orphan the server pruned stays gone.

### Simultaneous edits to a statement: conflict copies

Per-field last-writer-wins would silently drop one side when two devices edit the same statement's `content` while both are offline. So:
- Each pushed field also carries its **`base`**: the stamp of the value the device edited from.
- On the server, an incoming field is **concurrent** when the stored stamp is neither its `base` nor the incoming stamp itself.
- The server still merges normally. It also returns the **losing** value (incoming or stored) in `superseded`.
- **Only the device that pushed gets `superseded`, so the copy is made exactly once.**
  - For a statement's `content`, that device makes a **new statement on the same board**, beside the original, holding the losing content (a new id, the original's `board`, a nearby `position`). It syncs like any other statement. `SyncApplied.superseded(.statement, field: SyncFieldName.content)` lists exactly these.
  - Only that statement conflicts. The board's other statements, and the same statement's `position`, merge on their own and never produce a copy.
  - For everything else (positions, descriptors, links, settings, bookmarks), last writer wins. Nothing is lost that's worth a copy.
- **The user sees** two boxes with the same first line side by side, and nothing disappeared. No dialogs.
- The mechanism is generic: `SupersededField` names a kind, an id and a field, so a future kind needs no new protocol. Only the app decides which of them make copies.

## Wire protocol (ErgoProtocol, `Sync.swift`)

```
POST v1/sync            bearer, signed in
  SyncRequest  { cursor: Int?, changes: [SyncChange], limit: Int? }
  SyncResponse { cursor: Int, changes: [SyncRecord], more: Bool, superseded: [SupersededField], serverTime: Date }

SyncChange       { kind, id, fields: [String: SyncField], bases: [String: SyncStamp] }
SyncField        { value: JSONValue, stamp: SyncStamp }
SupersededField  { kind, id, field, lost: SyncField }

WS v1/sync/live         bearer, signed in
  server → client: SyncLiveMessage.changed(cursor: Int)     another device pushed
```

- **One round trip does both directions.** The push is applied first, then everything after `cursor` is returned, including the records just pushed (they're merged and idempotent to apply). `cursor: nil` means from the start.
- **`more: true`:** the client asks again with the new cursor and no changes, until it's false.
- **`JSONValue`:** a small Codable enum (null, bool, number, string, array, object). It lets the server store and merge values without knowing what a board is.
- **New `ServiceError.Code` cases** (additive):
  - `signInRequired` ("Sign in to sync")
  - `syncResetRequired` (see Pruning)
  - `rateLimited`
  - `tooLarge` ("Expected a statement under 256 KB, found 300 KB": the kind is named in the message)

### Limits

- Request body: 1 MB.
- Any one field value: 256 KB.
- 50,000 records per account. Every box and arrow is a record, so a big canvas is a few hundred.
- 60 sync requests per minute per account.
- `limit` defaults to 500, max 1000.
- Kinds and field names are checked against the table above: an unknown field is refused for every kind, so `content` on a board or a link, or `descriptor.0` on a statement, is `invalidRequest`. Board, statement and link ids must be uppercase UUIDs. Settings ids are checked against `SyncedSetting`.

### Pruning

Tombstones older than 90 days are deleted, and `Account.prunedThrough` is set to the highest seq removed. The statements and links of a pruned board, and old orphans, go too (see "Deleting a board"), without moving `prunedThrough`. A client whose cursor is below it gets `syncResetRequired`. It then:
1. pulls everything from `cursor: nil`
2. merges
3. pushes every local record the server doesn't have

A device offline for more than 90 days can bring back a board deleted elsewhere. That's rare, and better than losing data.

## Server

```
Sources/ErgoServer/
  Accounts/      AccountToken.swift, AppleSignIn.swift, AccountMerger.swift   (+ existing)
  Sync/          SyncRecordRow.swift, SyncController.swift, SyncService.swift, SyncLive.swift, SyncLimits.swift
  Migrations/    CreateAccountToken.swift, CreateSyncRecord.swift, MoveAccountTokens.swift
```

- **`SyncRecordRow`:**
  - Columns: `account` (cascade), `kind`, `recordID`, `fields`, `seq`, `updated`, plus `tombstone` (when a record was deleted) and `board_id` (a statement's or link's `board`, set by `store`, in the clear). Unique on (account, kind, recordID), indexed on (account, seq) and (account, board_id).
  - **`fields` is sealed** with the existing vault: AES-GCM, associated data `"\(account)/sync/\(kind)/\(recordID)"`. Boards are people's writing, so they're encrypted at rest like credentials. The server opens them to merge; it never logs them.
- **`Account`** gains:
  - `appleSubject` (unique, nullable)
  - `seq` (Int, the last change number)
  - `prunedThrough` (Int)
- **One `SyncService.apply` per request, in one database transaction.** For each change:
  1. load the row, open it, check the stamps, merge
  2. if anything changed, `account.seq += 1`, set the row's `seq`, seal it, save it
  3. collect `superseded`

  Then read the rows after the cursor, ordered by seq. SQLite serialises writers, so seq has no gaps or duplicates for one account.
- **`SyncLive`:** an in-memory broadcaster, account id → open sockets. After a commit that changed something, it tells every socket of that account *except the one whose token pushed*. Pings every 20 s.
  - This is in-process only. More than one server instance would need Redis pub/sub; note that and don't build it.
- **Pruning:** a daily `Task` loop, started in `configure`. Per account, in one transaction: old tombstones, then the statements and links of the boards among them, then old orphans. The orphan pass reads the `board_id` column and each account's board ids, never the sealed fields.

## ErgoKit

A new target, **`ErgoSync`**, with no dependencies, so the server and the app share the exact merge rules:

```
ErgoKit/Sources/ErgoSync/
  JSONValue.swift
  SyncStamp.swift        + SyncClock (tick, receive, offset)
  SyncField.swift
  SyncRecord.swift       merge, isDeleted, newestStamp
  SyncReplica.swift      the device side, below
  SyncedSetting.swift    the synced setting ids (just names; the app maps them to Defaults keys)
```

`ErgoProtocol` depends on `ErgoSync` and adds `Sync.swift` (wire types plus the new error codes). `ErgoClient` adds `sync(_:)`, `signInWithApple(identityToken:nonce:)`, `signOut()` and `syncLive() -> AsyncThrowingStream<SyncLiveMessage, Error>`.

### SyncReplica

Plain value type, `Codable`, saved by the app in Defaults (`syncState`). It knows nothing about boards.

- **`records: [RecordKey: SyncRecord]`:** the last merged state per record, which is the base for the next edit.
- **`pending: [RecordKey: SyncChange]`:** local edits not acknowledged yet.
- **`cursor: Int?`**, the `clock`, and the device id.

Its methods:
- **`recordLocal(kind:id:fields: [String: JSONValue])`:**
  - Compares each field with `records`. Only fields whose value **actually changed** get a fresh stamp and go into `pending`, with the old stamp as `base`.
  - Because of that, the app can hand it the whole current state after every change, and unchanged boards cost nothing. It's also what stops echo loops: applying a remote change and then reporting it back changes nothing.
- **`makeRequest() -> SyncRequest`**
- **`apply(_ response: SyncResponse, sent: SyncRequest) -> SyncApplied`:**
  - Merges `response.changes` into `records`.
  - Advances the clock.
  - Removes from `pending` only the fields whose stamp equals what was sent. Typing during the request stays pending.
  - Returns:
    - the records whose merged value changed: what the app must write back
    - `superseded`
- **`reset()`:** for sign-out and `syncResetRequired`.

## App

```
Ergo/Sync/
  SyncController.swift      @MainActor @Observable: when to sync, status, the live socket
  SyncedDefaults.swift      Defaults ↔ records: encode the synced keys into fields, write merged records back
  BoardRecord.swift          LogicBoard ↔ board, statement and link records, conflict copies per statement
  AppleSignIn.swift         nonce + ASAuthorization result → TranslationAccount.signIn
Ergo/Views/Sheets/Account/
  AccountSettingsView.swift
```

### When it syncs

Only signed in, with a server set. Syncs:
- on launch
- on `scenePhase == .active`
- 2 s after the last local change (debounced, like `BoardStore`'s save)
- when the live socket says `changed` with a cursor ahead of ours
- after sign-in (full)

Details:
- **One sync at a time.** A trigger during a sync sets "again after this one".
- **Failures** back off: 2, 4, 8 … up to 5 minutes. A network change or the app becoming active resets that.
- **Leaving the foreground** flushes `pending` straight away (save, then sync), so closing the app on the phone and opening the iPad works.
- **The live socket** is open only while active, and reconnects with the same backoff.
- **No polling.**

### Reading local changes

`Defaults.updates([.logicLetters, .ditherEnabled, .translationProvider, .bookmarks])` feeds `recordLocal`.

Boards go through `BoardStore` instead of watching `Defaults[.boards]`. A board array can be big, and `BoardStore` already knows what changed:
- `BoardStore.save()` hands the saved boards to `SyncController` (or `SyncedDefaults`), which calls `recordLocal` for each board.
- Diffing in the replica keeps that cheap.
- Deletes call `recordLocal(kind: .board, id:, fields: ["deleted": true])`.
- Drafts are never in `boards`, so they never sync.

### Writing remote changes

- **Settings and bookmarks:** write the Defaults key directly.
  - For bookmarks, insert/remove per record. Never replace the whole set from the server, so a bookmark added during the sync isn't lost.
- **Boards:** `BoardStore.applyRemote(_ boards: [LogicBoard], deleted: Set<LogicBoard.ID>)`:
  - updates the matching boards in place, inserts new ones, removes deleted ones
  - sets `modified` from the record's newest stamp
  - **doesn't** stamp `modified = .now` or call `recordLocal`
  - **The open board changes while it's open:** the editor shows the new content. It's newer, from the user's other device.
  - **The open board is deleted remotely:** the editor goes to a new draft, as if the user had deleted it here.
- **Superseded `content`:** for a statement (`applied.superseded(.statement, field: SyncFieldName.content)`), append a new statement on the same board (new id, the original's `board`, a position beside the original, the losing content) through `BoardStore`, so it syncs as a normal new statement. Before the canvas this made a copy of the whole board.
- **Ignored records:** statements and links for which `replica.isIgnored(_:)` is true (board deleted or missing, or a link's statement gone) aren't shown, whatever the board's array says, once a pull has finished.
- **Records the app writes:** one `board` record per board (`created`, `descriptor.N`, `deleted`), one `statement` per statement (`board`, `position`, `content`, `deleted`) and one `link` per link (`board`, `premise`, `conclusion`, `deleted`). Deleting a board writes only the board's tombstone; deleting a statement writes its tombstone and its links'.
- **Value checks:** every value from the server is decoded before it's written. One that fails to decode (newer app version, damaged data) is skipped, the record stays in the replica, and nothing local is touched. Never crash on server data.

### Settings UI

The section in `SettingsView` is **"Account"**, above Translation:
- **Signed out:**
  - `SignInWithAppleButton` (`.signIn`), black/white matching the colour scheme, full width.
  - The footer says: "Sync boards, bookmarks and letters across your devices. Translation works without an account."
- **Signed in:**
  - `LabeledContent("Sync")`, valued "Up to date · 2 min ago" / "Syncing" / "Waiting for network" / the error in red.
  - "Sync Now" doesn't exist; it syncs on its own.
  - **Sign Out:** confirmation, "Your boards stay on this iPhone".
  - **Delete Account:** destructive confirmation, "Deletes everything Ergo's server keeps for you, including your Claude and ChatGPT connections. Boards on this iPhone stay".
- **No server set:** sign-in is disabled, and the footer points at Translation → Server.

Accessibility identifiers:
- `settings.account`
- `account.signIn`
- `account.syncStatus`
- `account.signOut`
- `account.delete`

## Tests

### ErgoKit `ErgoSyncTests`, offline, the most important ones

- Stamp ordering, the clock's tick/receive, and the offset correction.
- `merge` is commutative, associative and idempotent: a property test with seeded random records.
- **Convergence:**
  - Three `SyncReplica`s plus an in-memory fake "server" that uses `SyncRecord.merge`.
  - Random edits, deletes and syncs in random orders, over many seeds.
  - At the end, after everyone syncs twice, all replicas have identical records.
- Tombstone vs concurrent edit: the edit wins. Delete then undo: alive.
- Concurrent `content` edits to a statement give exactly one `superseded` to exactly one replica, and a move on one device with typing on another gives none.
- Statements and links are in the convergence walk. Boards deleted and brought back, ignored statements and links, and a board's pruning cascading on a device and on the fake server, have their own tests.
- `recordLocal` with unchanged values produces no pending. Typing during a request stays pending after `apply`.

### ErgoServer

- Sync with two tokens on one account: push from A, pull on B, `superseded`.
- Cursor paging with `more`.
- Limits: size, count (statements and links count, and the default is 50,000), kinds, future stamps, and field names per kind (unknown fields refused for statements and links, `content` refused for boards).
- Pruning: a deleted board takes its statements and links, a board with no record keeps its orphans for 90 days and then loses them, other accounts are untouched, and none of it moves `prunedThrough`.
- A conflicting statement `content` is `superseded` to the pusher only, and only for that statement.
- `signInRequired` for anonymous accounts.
- `syncResetRequired` after pruning.
- **Sealed at rest:** the raw `fields` column doesn't contain the English text.
- **Apple sign-in:** test `AccountMerger` directly. Put the JWT verification behind a small `AppleTokenVerifier` that tests replace (no network).
- **The live socket:** it notifies the other token, not the pusher.

### App

- Build only. Previews for `AccountSettingsView` signed in and signed out.

## Phases

| Phase | Owner | Can start | Owns |
|---|---|---|---|
| 5a | Agent "ErgoSync" | **now** | `ErgoKit/` (additive: the new target, `Sync.swift`, ErgoClient methods, tests) |
| 5b | Agent "Server sync" | after 2a and 5a | `ErgoServer/` |
| 5c | Agent "App sync" | after 2b and 5a | `Ergo/`, `Ergo.xcodeproj/` |

**5a** runs while phase 2 agents are building against ErgoKit, so it must never leave ErgoKit broken:
- Develop in a scratch package (under the scratchpad) that depends on `../ErgoKit` by path, or copy ErgoKit there.
- Move the finished files into `ErgoKit/` and edit `Package.swift` in one step, only once it's green.
- Then run `swift test` in ErgoKit.
- Don't change any existing public API.
