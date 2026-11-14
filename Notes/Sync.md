# Sync

See `Plans/05-Sync.md` and the server README's Sync.

- Signed in with Apple or email, boards, bookmarks and the settings in `SyncedSetting` sync through the server (`Ergo/Sync/`, ErgoSync).
- Every new Defaults key needs a decision: synced (add it to `SyncedSetting` and `SyncedDefaults`) or this device only.
- Sync kinds: `board` (`created`), `statement` (`board`, `position`, `content`, which is the English and any template placeholder, `source`), `source` (`board`, `position`, `content`), `link` (`board`, `premise`, `conclusion`), `scratchpad` (`created`, `descriptor.N`, `content`), and `share`, `annotation` and `analysis`, which only the server writes (see Sharing boards and Board analysis). Statements and links are records of their own, so dragging a box never clashes with typing in it.
- Deleting a board writes only its tombstone: the replica ignores its statements, links and sources (`SyncReplica.isIgnored`). Deleting a statement tombstones it and its links. Boards are rebuilt from the replica's records, so arrival order doesn't matter.
- Merging is last writer wins per field, with hybrid-clock stamps. Two devices editing a statement's content at once give a conflict copy of that statement beside it, not a loss.
- Sync values are always encoded with `SyncCoding`. A different encoder makes identical values look like edits.
