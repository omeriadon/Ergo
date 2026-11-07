# 09 · Sharing boards

People share a board with others, who can edit it or only view it. Only the person who made it (the **owner**) can add people, change what they can do, or remove them. Invites go out through the system share sheet, Messages included, and tapping one opens the app straight away.

Read [README.md](README.md) and [05-Sync.md](05-Sync.md) first. No migrations of app data before v1, but the server's database is live, so its schema changes are normal Fluent migrations.

## The decisions

- **Each member keeps their own copy of a shared board's records, and the server copies every change to the others ("fan-out").** The app keeps one replica and one cursor per account, so offline edits, conflict copies, paging, pruning and resets all work unchanged. A single shared copy with its own cursor was rejected: turning a private board into one would move its records out of the owner's account, which breaks the owner's other devices if they have offline edits.
- **Who's on a board travels through sync**, as a server-written record of a new kind, `share`. The app needs no "fetch members" call, works offline, and every device of every member hears about changes the usual way.
- **Leaving is just deleting.** A member's board tombstone means "leave", and the owner's means "delete for everyone". It works offline and needs no extra route.
- **Apple's parts:** the system share sheet, with `SWCollaborationMetadata` so Messages shows it as a collaboration with Apple's own permission picker, and a universal link. `UICloudSharingController` and the manage button of `SWCollaborationView` are CloudKit only (Apple's docs say a custom infrastructure must provide its own), so managing people is our own sheet.
- **A link is the only way in.** Anyone holding an unexpired link can join with its role. The owner is told, and can remove them or revoke links. Messages' cryptographic per-person identities (`SWPerson.Identity`, Merkle proofs) are not verified in this version: `SWUpdateCollaborationParticipantsAction` is simply fulfilled.

## Sync records

A new `SyncKind.share` (`"share"`), id = the board's uppercase UUID. **Only the server writes it**, so it isn't in `SyncKind.known`, and `SyncKind.isServerOwned` is true for it.

| field | value |
|---|---|
| `role` | `"owner"`, `"editor"` or `"viewer"` |
| `member` | this account's member id (uppercase UUID) |
| `members` | `[{ id, name, role }]`, everyone on the board, owner included |
| `deleted` | tombstone: no longer shared with this account |

New types in `ErgoSync` (`BoardShare.swift`), re-exported by ErgoProtocol:

```swift
public enum BoardRole: String, Codable, Sendable, Hashable { case owner, editor, viewer }
public struct BoardMember: Codable, Sendable, Hashable, Identifiable { public var id: UUID; public var name: String; public var role: BoardRole }
public struct BoardShare: Sendable, Hashable { public var board: String; public var role: BoardRole; public var member: UUID; public var members: [BoardMember] }
public extension BoardShare { init?(_ record: SyncRecord); var fields: [String: JSONValue] }  // via SyncCoding. Nil for the wrong kind, a tombstone or fields this version can't read.
public extension BoardRole { var canEdit: Bool }  // owner, editor
```

Server stamps are `SyncStamp(time: max(now, newest.time), counter: same time ? newest.counter + 1 : 0, device: "server")`, always newer than what the record has. Add a helper in ErgoSync: `SyncStamp.server(after: SyncStamp?, now: Date)`.

## Rejected changes

`SyncResponse` gains `rejected: [RejectedChange]?` (optional on the wire).

```swift
public struct RejectedChange: Codable, Sendable, Hashable {
	public var kind: SyncKind
	public var id: String
	public var current: SyncRecord?   // what the server has, nil when it has nothing
}
```

Sent when a device pushes to a board it may not edit (a viewer, or someone removed, whose device hasn't heard yet). It doesn't fail the request. `SyncReplica.apply`, after merging and acknowledging:

- drops all of that record's pending fields, and its entries in `seeds` and `unconfirmed`
- replaces the record with `current`. With no `current`, and a record held locally, it keeps the old fields and adds a `deleted: true` tombstone stamped by the clock, so the app drops the phantom. Nothing about this is pending.
- lists it in `SyncApplied.changed`

The replica never pushes a server-owned kind: `apply`'s "missing" re-push and `finishCatchingUp` skip them. In `finishCatchingUp`, an unconfirmed server-owned record the full pull didn't return is removed from `records` (the server no longer has it, for this account).

`SyncReplica.forget(_ keys: Set<SyncRecord.Key>)` removes records, pending, seeds and unconfirmed outright, for signing out of a board that isn't yours.

## Wire protocol (additive, no version bump)

Paths in `ErgoProtocol.Path`. Tokens go in bodies, never in API paths, so they can't land in logs.

```
POST   v1/boards/<board>/invites            CreateBoardInvite { role, title, name } → BoardInvite { url, role, expires }    owner, or first share
DELETE v1/boards/<board>/invites            → 204, revokes every open link                                                  owner
POST   v1/boards/<board>/members/<member>   UpdateBoardMember { role } → 204                                                owner
DELETE v1/boards/<board>/members/<member>   → 204, removes them                                                             owner
DELETE v1/boards/<board>/share              → 204, stops sharing: everyone else loses the board, the owner keeps it         owner
POST   v1/invites/preview                   BoardInviteToken { token } → BoardInvitePreview { board, title, ownerName, role, memberCount }   no auth, limited per address
POST   v1/invites/accept                    AcceptBoardInvite { token, name } → JoinedBoard { board, role }                 signed in
PUT    v1/push/device                       PushDevice { token, environment } → 204                                         signed in
DELETE v1/push/device                       → 204, this device's token only                                                 signed in
GET    /.well-known/apple-app-site-association                                                                              public, no version header
GET    /join/<token>                        small HTML page for someone without the app                                     public, no version header
```

- `BoardInvite.url` is `https://<public host>/join/<token>`.
- Role must be `editor` or `viewer` in `CreateBoardInvite` and `UpdateBoardMember`. The owner can't change or remove themselves.
- `title` is at most 200 characters, `name` 1–60 after trimming. Errors are `invalidRequest`, compiler style: "Expected an invite that's still open, found one that expired or was revoked". No new `ServiceError.Code`.
- Accepting twice, or as the owner, keeps the role you have and answers normally.
- `ErgoClient` gets one method per route. Preview sends no bearer token.

`SyncLiveMessage` doesn't change: a member's socket gets `.changed(cursor:)` with their own account's seq.

## Server

### Tables (one migration, `CreateBoardSharing`, plain Fluent schema, both SQLite and Postgres)

- `board_shares`: `id` (the board's UUID), `owner_id` → accounts (cascade), `sealed_title` (data, nullable, sealed by the vault), `created`
- `board_members`: `id`, `board_id` → board_shares (cascade), `account_id` → accounts (cascade), `role`, `name`, `joined`. Unique (board, account). Index on account. The owner has a row too.
- `board_invites`: `id`, `board_id` → board_shares (cascade), `token_hash` (`Account.hash`, unique), `role`, `created`, `expires` (30 days). Never store the token. At most 20 open per board, oldest deleted first; expired ones are deleted when a new one is made.
- `push_devices`: `id`, `account_id` → accounts (cascade), `token_id` → account_tokens (cascade), `apns_token` (unique), `environment` (`sandbox`/`production`), `updated`

Limit: 30 members per board (`SyncLimit.membersPerBoard`).

### Pushing to a shared board (`SyncService.apply`)

Every change belongs to a board: a board record's own id, or `SyncRecord.owningBoard` of the stored row, else of the incoming fields (so `source` is covered without naming it). Scratchpads, bookmarks and settings have none and are untouched.

1. **Server-owned kinds are rejected before anything else**, ahead of `SyncLimits.check`, which would fail the whole request.
2. **Locks.** Postgres is used in production, so before the transaction read the boards the request touches and their members, and lock all of those accounts in sorted UUID order, the caller among them, with `SyncService.lock`. Inside, re-read membership. A member who joined in between is locked late.
3. **Per change, with board B:**
   - B isn't shared: as today.
   - A statement, link or source whose stored `board` differs from its incoming `board`, when either is shared: rejected.
   - The caller is owner or editor: applied, then fanned out.
   - A board record with only `deleted: true`, from anyone: applied to their own row, then treated as below.
   - Otherwise (viewer, or not a member): `RejectedChange` with their current record.
4. **Fan-out**, only when the caller's record actually changed. For every other member, merge into their row with the same key, take their next seq and store. **Skip a target whose existing row has a different `board`**, so a malicious editor can't reach into a board they aren't on by reusing an id. Board records fan out `created` only: `deleted` is per person. A member's record limit never fails someone else's push, so fan-out isn't counted.
5. **Board tombstones:** the owner's deletes for everyone (like stop sharing, below, but the owner's copy is deleted too). A member's is leaving: their `share` gets a tombstone, their member row goes, and everyone else's `members` is rewritten.
6. **After commit:** `live.changed` for each account whose seq moved, except the pushing token, then the pushes below.

Only `deleted: false` from a member with no share record (coming back) changes nothing special: they aren't a member, so it's rejected.

### Sharing (`BoardSharing`, a struct like `SyncService`, in `Sources/ErgoServer/Sharing/`)

- **First invite:** the board record must exist in the owner's rows and not be deleted, else `invalidRequest` ("Expected a synced board, sync and try again"). Creates the share, the owner's member row and their `share` record. A board already shared by someone else: refused. Later invites refresh `sealed_title` and the owner's `name`.
- **Accepting:** copies every row of the owner's with this board (`board_id`, or the board record itself), skipping tombstones, into the joiner's account, resealed. If the joiner had a tombstone from before, the board gets a fresh `deleted: false` with a server stamp, for them only. Writes their `share`, rewrites everyone's `members`.
- **Removing someone, or stopping sharing:** writes a board tombstone with a server stamp into their account (their children are then ignored and pruned as usual), and a tombstone on their `share`. Their rows aren't deleted, so pruning stays the one thing that deletes.
- **Changing a role:** rewrites `share` records. Takes effect on the next push.
- **Deleting an account (`AccountController.deleteEverything`):** boards it owned are deleted for everyone, and it leaves the others. Signing in only merges anonymous accounts, which are on no boards, so `AccountMerger` needs nothing.

Pruning needs no change.

### Pushes (`Sources/ErgoServer/Sharing/Push/`)

No new dependency: `APNSClient` signs an ES256 JWT with swift-crypto (`P256.Signing.PrivateKey(pemRepresentation:)`, raw signature, base64url, cached 40 minutes) and posts with `application.client`, which negotiates HTTP/2. Behind a closure-holding struct `PushSender`, like `AppleTokenVerifier`, so tests swap it. With no key configured it does nothing and logs once at launch. A `410` or `BadDeviceToken`/`Unregistered` deletes the device row. Failures are logged without the token or the title, and never fail a request.

Headers: `apns-topic`, `apns-push-type` (`alert` or `background`), `apns-priority` (10 or 5), `apns-collapse-id` (the board). Hosts: `api.push.apple.com`, `api.sandbox.push.apple.com` by the device's `environment`.

```json
{ "aps": { "alert": { "title": "…", "body": "…" }, "sound": "default", "thread-id": "<board>", "content-available": 1 }, "board": "<board>" }
```

| Event | To | Alert |
|---|---|---|
| Someone joined | owner | "Sam joined" / the title |
| Edits | other members | "Sam edited" / the title. At most one per board and person per 15 minutes; otherwise silent, at most one per account per minute |
| Role changed | that member | "You can now edit" or "You can now only view" |
| Removed, or sharing stopped | them | "You were removed" |
| Owner deleted the board | members | "Sam deleted" |

- Devices with an open live socket get nothing: `SyncLive` gains `isListening(token:)`. They've already been told.
- Throttles live in memory (`PushThrottle`), like `SyncLimits`.
- Sent in a detached `Task` after commit.
- The title is `sealed_title`, what the owner's device last sent, falling back to "a board". Never logged.

### Config (`ServerConfig`)

`ERGO_PUBLIC_URL` (default `ServerEnvironment.productionURL`'s value, `https://ergo-15.235.184.129.sslip.io`), `ERGO_APPLE_TEAM_IDS` (comma separated, default `P6PV2R9443`, the app target's team, not the project's `C2HN547N49`), `ERGO_APNS_KEY` (PEM, literal `\n` accepted) or `ERGO_APNS_KEY_FILE`, `ERGO_APNS_KEY_ID`, `ERGO_APNS_TEAM_ID` (default `P6PV2R9443`), `ERGO_APNS_TOPIC` (default `appleApplicationID`), `ERGO_APP_STORE_ID` (optional). Document them in `ErgoServer/README.md`.

### Public routes

`ProtocolVersionMiddleware` lets these two through. `RequestLogMiddleware` must never log the path of `/join/…`, so check how it logs and redact it.

- **AASA:** `{"applinks":{"details":[{"appIDs":["<team>.<bundle>"],"components":[{"/":"/join/*"}]}]}}`, `application/json`, no redirect.
- **`/join/<token>`:** one small page, never shown to someone with the app installed. Says "You've been invited to a board on Ergo", offers `ergo://join/<token>`, and an App Store link and `apple-itunes-app` meta when `ERGO_APP_STORE_ID` is set. `noindex`, `no-referrer`, `og:title` without any board content. It reads nothing from the database, and escapes the token.

## ErgoKit

`ErgoSync/BoardShare.swift`, `SyncKind.share`, `SyncFieldName.role/member/members`, `SyncStamp.server`, `RejectedChange`, replica changes, `SyncLimit.membersPerBoard`. `ErgoProtocol/Sharing.swift`: wire types and paths. `ErgoClient/ErgoClient+Sharing.swift`. Also `BoardInviteLink` in ErgoProtocol: `static func token(from url: URL) -> String?`, true for `https://<any host>/join/<token>` and `ergo://join/<token>`. Any host, so a debug build pointed at This Mac still opens links.

Tests in `ErgoSyncTests`: rejected with and without `current`, typing during a rejected request, server-owned kinds never pushed after a reset, `forget`, `BoardShare` round trip, `SyncStamp.server` always newer, and `BoardInviteLink`.

## App

New files in `Ergo/Sharing/`.

### BoardStore

- `shares: [Board.ID: BoardShare]`, set by `SyncController` from the replica's `share` records on launch and after every sync (not on `Board`, so it can't go stale, and it needs no new Defaults key).
- `canEdit(_ id:)`: true when not shared or the role can edit.
- **The `current` setter returns early for a board this person can't edit.** Every edit goes through it, so it's the one place. `insertStatementCopy` guards too.
- `discardCurrentIfEmpty` never discards a shared board: its tombstone would be a leave or a delete for everyone.

### SyncController

- `write`: `.share` records affect their board, and `boardStore.shares` is refreshed.
- `record`: skips boards this person can't edit, so a viewer's device doesn't push a rebuilt placeholder.
- `recordAll`'s "deleted while signed out" never counts a board that has a live `share` record. A decode failure must not become a delete for everyone.
- `accountChanged`, when the account really changes: boards shared with this account that it doesn't own are removed from `BoardStore` and `replica.forget`-ten with their statements, links and sources. Owned ones stay as ordinary local boards, and their `share` record is forgotten.
- Sharing operations (`invite`, `updateMember`, `removeMember`, `revokeInvites`, `stopSharing`, `previewInvite`, `join`), each flushing and waiting for a sync where it matters: before the first invite (the board must be on the server) and after joining (so the board is there to open).
- `syncAndWait()`, and handling a silent push by syncing and reporting the result.

### Sheets

- **Canvas toolbar:** a People button (`person.2`, with a filled symbol when shared), opening `BoardPeopleSheet`. Hidden or disabled for an empty draft.
- **`BoardPeopleSheet`:** signed out, it says sharing needs an account and links to the sign-in in Settings. **Owner / not yet shared:** a name field the first time (`Defaults[.sharingName]`, this device only), a `Can edit` / `View only` picker, **Send Invite**, the people (swipe or menu to change role or remove), Revoke Links, Stop Sharing with confirmation. **Member:** read-only list, and Leave with confirmation.
- **Send Invite** is one tap: create the invite, then present the system share sheet (`UIActivityViewController` in a very small representable, Adon doesn't write UIKit, so explain it plainly in comments).
- **`BoardInvitation`:** builds `UIActivityItemsConfiguration` with an `NSItemProvider` holding the URL and, when `usesMessagesCollaboration` (a `static let` so it can be switched off if it misbehaves on a device), an `SWCollaborationMetadata` with `defaultShareOptions` non-nil (a `SWCollaborationOptionsPickerGroup` of the two roles, with the chosen one selected: Apple's forums report that nil makes it not appear), title, and `initiatorNameComponents`. `LPLinkMetadata` for the preview.
- **`CollaborationHandler`**, an `SWCollaborationActionHandler` set on `SWCollaborationCoordinator.shared` in `didFinishLaunching`. Start: read `userSelectedShareOptions`; the same role as the invite just made fulfills with its URL, another role makes a new invite; `collaborationIdentifier` is the board's id. Update participants: `fulfill()`.
- **`JoinBoardSheet`** (a new `AppSheet.joinBoard(String)` case): loads the preview, shows the title, who invited you and the role, the name field, and Join. Signed out, sign-in comes first, using the same controls as Settings. A bad or expired link shows the message. Joining syncs, opens the board, goes to the Board tab and dismisses.
- **`BoardsSheet`:** rows show "Shared by Sam" or "Shared" and the role. The swipe action is Delete on private boards, Leave for members, and for owners of a shared board Delete with a confirmation that says it deletes it for everyone. `SharedItemSheet`'s board choices leave out boards that can't be edited.
- **Read-only canvas:** with `!canEdit` no add, edit, delete, drag, connect, arrange or undo. The bar shows a "View only" notice, boxes open read-only editors. Role changes apply live. Remember hosted boxes and the hosted editor get no environment (CLAUDE.md): pass it in `CanvasBoard.boxContent` and `CanvasView.editorPresenter`.

### Links

`ErgoApp`'s `.onOpenURL` checks `BoardInviteLink.token(from:)` first and presents `.joinBoard`, else the existing `receiveShared()`. SwiftUI delivers universal links there too.

### Push

- `AppDelegate` via `@UIApplicationDelegateAdaptor`: registers with APNs when signed in, hands the token to the server (`PUT v1/push/device`, `sandbox` in `DEBUG`, else `production`), does a sync on a silent push, and on tapping a notification opens `userInfo["board"]` on the Board tab. Foreground banners show unless that board is the one open.
- Notification permission is asked only at the moment it makes sense: after the first invite is made, and after joining.

### Project

- `Ergo.entitlements`: `aps-environment` = `development`, `com.apple.developer.associated-domains` = `["applinks:ergo-15.235.184.129.sslip.io"]`, `com.apple.developer.shared-with-you` = true.
- `Ergo/Special/Info.plist`: `UIBackgroundModes` = `["remote-notification"]`.
- New Defaults key: `sharingName`, this device only.

## What Adon has to do

1. Enable Push Notifications, Associated Domains and Shared with You for `com.adonis.Ergo` under team **P6PV2R9443** (automatic signing may do this).
2. Create an APNs key (.p8) in the same team and set `ERGO_APNS_KEY`, `ERGO_APNS_KEY_ID`.
3. Rebuild and redeploy ErgoServer. Check `https://<host>/.well-known/apple-app-site-association` returns the JSON with no redirect. Apple's CDN can take up to a day to pick it up.
4. Before shipping, consider a real domain. Universal links are tied to this hostname, and an sslip.io name changes if the server's IP does, which would break every link already sent.

## Not in this version

- Verifying Messages' per-person identities, which would stop a forwarded link working
- Approving people before they join, and transferring ownership
- `SWHighlightCenter` notices in the Messages thread, and `SWCollaborationView`
- Who changed what, presence, and live cursors
- Two people typing in one box at once still gives a conflict copy, as with two devices

## Status

- [x] ErgoKit: as planned. `ErgoProtocol.Path` has `boardInvites(_:)`, `boardMember(_:_:)`, `boardShare(_:)` as functions of string ids. `BoardInvitePreview.board` and `JoinedBoard.board` are uppercase UUID strings. `ErgoClient`: `createBoardInvite(board:_:)`, `revokeBoardInvites(board:)`, `updateBoardMember(board:member:role:)`, `removeBoardMember(board:member:)`, `stopSharingBoard(board:)`, `previewBoardInvite(token:)`, `acceptBoardInvite(token:name:)`, `registerPushDevice(token:environment:)`, `unregisterPushDevice()`. A record that's rejected also drops its `superseded` entries, so no conflict copy is made of a refused edit.
- [x] Server: written, but never compiled or run, so nothing is confirmed yet. Differences: on joining, a tombstone is also copied to someone who already has that record, so a statement deleted while they were away doesn't come back for them. Copying a board in on joining isn't counted against the joiner's record limit, like fan-out. A statement, link or source whose incoming `board` isn't a string is treated as moving boards, so it's rejected on a shared board. Devices for a push are read after the commit but before the response, and only the sending is detached. Previews are limited to 30 a minute per address. Member ids are `board_members.id`, not account ids.
- [x] App: as planned, in `Ergo/Sharing/`. Builds, but nothing has run on a device or against the server yet. Differences: `BoardPeopleSheet` is a new `AppSheet.boardPeople(Board.ID)`, like `.joinBoard`. The read-only flag is `isReadOnly` on `CanvasBoxModel` and `CanvasSourceModel`, so a role changing redraws the box, rather than passed in `boxContent`, and the editor reads `canEdit` from the `BoardStore` it's already handed. Sources open read-only in `SourceReaderSheet`. Dragging on a box pans the canvas when it's read-only. `deleteDanglingLinks` skips boards this person can't edit, which the plan didn't list: the server would refuse the cleanup and it would repeat after every sync. `unregisterPushDevice` isn't called, since `push_devices.token_id` cascades when signing out deletes the token. `sharingName` starts empty, since Sign in with Apple asks for no name here. The Leave swipe in `BoardsSheet` asks first, like Leave in `BoardPeopleSheet`, since only the owner can invite someone back.
