# 13 · Versions

How the app and the server change without cutting anyone off.

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## The problem

An app on someone's phone can't be changed, and people update when they feel like it, so many app versions are in use at once. The server is one thing that changes for all of them at the same moment. Apple's review also sits between a new server and the new app, so for days the only app anyone can get is the old one.

## Two numbers, not one per app version

**Decided:**
- The protocol has its own number, apart from the app's version. Many app versions speak the same protocol.
- The number only goes up for a change an older app would misread. That should be rare: a few times a year at most.
- The server answers every protocol from its **minimum** up to its **current**. Normally that's two: the one in people's hands and the one in review.
- Between them sits **recommended**. An app below it still works and is told to update. An app below the minimum is refused.

| The app's protocol | What happens |
|---|---|
| Below the minimum | Refused with `outdatedApp`. Nothing that needs the server works. The badge says so. |
| From the minimum, below recommended | Answered as normal. Every reply carries a marker, and the app shows the badge. |
| Recommended up to current | Answered as normal. |
| Above current | Only when a server is rolled back. Refused as the server's fault, and never told to update. |

## Changing things without a new number

**Decided:** most changes are additions, and an addition never needs a number.

- A new field is optional, and an old app ignores it.
- A new path is one an old app never calls.
- A new kind of message, button, block or error decodes to `unknown` in an old app and is skipped. Every type the server can add a case to has to decode this way before the first public build. It can't be added afterwards.
- A field is never renamed, never changes type, and never changes meaning. A new meaning is a new field.
- Removing something is the breaking change. It waits until the minimum has passed every app that reads it.

## Making a breaking change

**Decided,** in this order:
1. The server learns the new protocol and keeps answering the old one. A route that differs asks which protocol the request speaks and answers in that shape.
2. The server is deployed. Nothing changes for anyone.
3. The new app is released.
4. Once it's out, recommended is raised. Old apps start showing the badge.
5. Once nearly everyone has updated, the minimum is raised. The stragglers are refused, and the badge tells them why.
6. The code that answered the old protocol is deleted.

Recommended and the minimum are settings on the server, not code, so steps 4 and 5 need no deploy and can be undone.

**Proposed:** wait at least a month between 4 and 5, and look at how many requests still come from the old protocol before raising the minimum. That needs the server to count requests per protocol.

## The badge

**Decided:**
- One place hears it. Whatever the app asks the server, the client notices the marker or the refusal and reports it, so no screen has to check.
- It mustn't nag. It shows at most once each time the app comes to the front. For an app that still works, at most once a day.
- It's the status badge from Timetable, which is also where any other failure worth interrupting for goes.

**Proposed:** tapping the badge opens the App Store page, once there is one.

## Other things with versions

- **The logic grammar** has its own number, and a mismatch is `outdatedApp` too.
- **The catalog** ships inside the app. The server has its own copy for the model, which can be newer. An entry the app doesn't have is shown as plain text rather than a link, so nothing breaks. **Decided:** an entry's id is permanent. Entries are added and edited, and an id is never renamed or removed.
- **Sync records** are the hardest thing to change, since every device keeps its own copy. A new kind or field has to be ignored by an old app without being thrown away, or the old app erases it for everyone the next time it writes.

## Open

- Whether an old app keeps unknown sync fields today, or drops them when it saves.
- What a refused app can still do. The library, scratchpads and boards on the device don't need the server.
