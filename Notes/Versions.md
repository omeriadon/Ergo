# Protocol versions and app updates

- See `Plans/13-Versions.md`. The server answers every protocol from `ServerConfig.protocols.minimum` to `ErgoProtocol.version` (`ProtocolVersionMiddleware`). A route that answers an older app differently reads `request.protocolVersion`.
- Only a change an older app would misread bumps `ErgoProtocol.version`. A new field is optional, and a new case decodes to `unknown` (or `internalError` for `ServiceError.Code`) in an older app. Never rename a field or change what it means.
- Nothing the server sends may fail to decode because it's newer. A list skips the elements it can't read (`TolerantList`), a socket skips a kind it doesn't know (`SkipsUnknownKinds`, which only lets through kinds that don't end the run), and a role it doesn't know is `viewer` (`BoardRole(wire:)`). A new wire enum needs one of these before it ships.
- `ErgoClient` posts `appUpdateNotification` when a reply carries `Ergo-App-Update` or fails with `outdatedApp`, so no screen checks for it. `AppUpdateWarning` decides how often to show it: once per foreground, and once a day while the app still works.
