# ErgoServer

Ergo's English → logic translation server. It runs ErgoKit's `TranslationPipeline` through the official `claude` and `codex` CLIs, each user with their own Claude or ChatGPT credential, and streams progress to the app over a WebSocket. Ergo provides no model access of its own.

It also syncs boards, bookmarks and a few settings between a user's devices, once they sign in, with Apple or with an email and password.

The wire protocol is `ErgoProtocol` in ErgoKit. The design is in `Plans/02-Server.md` and `Plans/05-Sync.md`.

## Routes

Every request from the app sends `Ergo-Protocol-Version: 1`, and all but `POST v1/accounts` send `Authorization: Bearer <token>`. Errors are a `ServiceError` body. The one route the app doesn't call, `POST v1/apple/notifications`, needs neither, see [Sign in with Apple notifications](#sign-in-with-apple-notifications).

| Route | Needs | |
|---|---|---|
| `POST v1/accounts` | nothing | A new anonymous account and this device's token. 5 an hour per address. |
| `DELETE v1/account` | token | Deletes the account, its connections, its synced records and every device's token |
| `POST v1/account/apple` | token | `SignInWithAppleRequest` → `SignedIn`. Attaches the Apple ID, or merges this device's account into the one that has it. |
| `POST v1/account/register` | token | `EmailCredentials` → `204`. Attaches an email and password to this device's account. `409` `emailInUse` if the email is taken, `400` if the account already has one. 10 an hour per address. |
| `POST v1/account/login` | token | `EmailCredentials` → `SignedIn`. Merges this device's anonymous account into the one that owns the email, like Sign in with Apple. `401` `invalidCredentials` for a wrong password or an unknown email, `429` `rateLimited` after too many failures. |
| `POST v1/account/password` | token | `ChangePasswordRequest` → `204`. Signs out every other device of the account and closes their sockets; this device's token stays. |
| `DELETE v1/account/token` | token | Signs out this device only. An anonymous account with no device left is deleted. |
| `GET v1/connections` | token | `[ConnectionStatus]` |
| `PUT` / `DELETE v1/connections/<provider>` | token | Checks a credential with one real call, then stores it, or removes it |
| `WS v1/connections/codex/device-login` | token | Codex's device login |
| `WS v1/translate` | token | One translation, streamed. `TranslateRequest.scope` is `statement` (the default: the whole pipeline for one statement, ends with a `Translation`) or `argument` (gate and breakdown only, for pasted English: ends with an `ArgumentBreakdown`). `descriptors` carries the board's letter names so claims keep their letters. |
| `POST v1/sync` | signed in | `SyncRequest` → `SyncResponse` |
| `WS v1/sync/live` | signed in | `SyncLiveMessage.changed(cursor:)` whenever another device pushes |
| `POST v1/apple/notifications` | Apple's signature | Sign in with Apple's server-to-server notifications. Called by Apple, never the app. |

"Signed in" means an Apple ID, an email, or both, on one account. An anonymous account gets `403` `signInRequired` from both sync routes.

`invalidCredentials` is `401` like a dead token (`unauthorized`), but it's a different `code` and means the device's token is still good. The app must read the code, never the status.

## Running locally

Xcode is a beta at a non-default path, so prefix every `swift` command:

```sh
export DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"
cd ErgoServer
swift build
swift test
swift run ErgoServer serve --hostname 127.0.0.1 --port 8080
```

In development the server makes up a vault key when there isn't one, so stored connections only last until it restarts. `claude` and `codex` are found on `PATH`.

Then, by hand:

```sh
curl -X POST -H 'Ergo-Protocol-Version: 1' http://127.0.0.1:8080/v1/accounts
# {"id":"…","token":"…"}

curl -X PUT -H 'Ergo-Protocol-Version: 1' -H "Authorization: Bearer $TOKEN" \
	-d '{"kind":"apiKey","secret":"sk-ant-api…"}' http://127.0.0.1:8080/v1/connections/claude
```

A fake token (`sk-ant-oat01-fake`) costs nothing and must come back as `422` with `credentialRejected`.

Sync needs a signed-in account, so an anonymous account is turned away:

```sh
curl -X POST -H 'Ergo-Protocol-Version: 1' -H "Authorization: Bearer $TOKEN" \
	-d '{"changes":[]}' http://127.0.0.1:8080/v1/sync
# 403 {"code":"signInRequired","message":"Sign in to sync"}
```

Email accounts can be tried entirely by hand:

```sh
curl -X POST -H 'Ergo-Protocol-Version: 1' -H "Authorization: Bearer $TOKEN" \
	-d '{"email":"ada@example.com","password":"correct horse"}' http://127.0.0.1:8080/v1/account/register
# 204, and the sync above now works
```

Signing in with Apple needs a real identity token from the app. To try sync by hand against a scratch database only, mark the account signed in directly: `sqlite3 ergo.sqlite "UPDATE accounts SET apple_subject = 'test' WHERE id = '<account id>'"` (ids are stored as their uppercase text).

## Testing from a device

Debug builds of the app can use this server instead of the hosted one: Settings → Translation → Server → This Mac. `127.0.0.1` only takes connections from the Mac itself, so listen on every interface:

```sh
swift run ErgoServer serve --hostname 0.0.0.0 --port 8080
```

- In the app, enter `http://<Mac name>.local:8080`. The name is `scutil --get LocalHostName`, or System Settings → General → Sharing. The Mac's LAN address works too (`ipconfig getifaddr en0`). The phone and the Mac need to be on the same network, and the macOS firewall may ask to let ErgoServer accept connections.
- The first request shows iOS's local network prompt. If it was turned down, turn it back on in Settings → Privacy & Security → Local Network. Only debug builds have the usage description, so release builds never ask.
- Plain `http://` and `ws://` to a `.local` name or a local address are allowed by the app's `NSAllowsLocalNetworking`, so no other ATS exception is needed.
- Settings → Translation → Test Server (debug builds only) tries REST and the translate socket separately, and shows each one's error as the app would.
- Every request logs one line at `info` with its status, so the console shows what actually reached the server:

	```
	[ INFO ] GET /v1/connections 200 [request-id: …]
	[ INFO ] GET /v1/translate 101 (WebSocket upgrade) [request-id: …]
	```

	A translation always starts with `GET /v1/translate`. A status other than 101 is why it was turned away: 401 for an unknown account, 426 for another protocol version. No line at all means the upgrade never reached the server, so look at the address, the network, local network access and the firewall.
- Don't run with `--log trace` outside your own machine: Vapor's trace lines print every request's headers, bearer token included.

## Configuration

Everything comes from the environment.

| Variable | Default | |
|---|---|---|
| `ERGO_DATABASE_URL` | none | Postgres, as `postgres://user:password@host:5432/database` with the password percent-encoded. Empty or unset uses SQLite. Migrations run at every launch either way. |
| `ERGO_DATABASE_PATH` | `./ergo.sqlite` | SQLite file, created `0600` |
| `ERGO_VAULT_KEY` or `ERGO_VAULT_KEY_FILE` | required in production | 32 bytes, base64. Seals credentials at rest. Make one with `head -c 32 /dev/urandom \| base64`. |
| `ERGO_RUNS_DIRECTORY` | temp + `/ergo-runs` | One scratch directory per CLI call, always removed afterwards |
| `ERGO_CLAUDE_PATH` / `ERGO_CODEX_PATH` | found on `PATH` | The CLIs |
| `ERGO_CLI_DIRECTORY` | none | Set, a CLI that doesn't run at launch gets installed here with npm, and launch waits for it. Needs `ERGO_CLAUDE_CODE_VERSION` and `ERGO_CODEX_VERSION`. The Dockerfile sets all three. |
| `ERGO_RUNNER_PREFIX` | empty | Put before every CLI call, e.g. `setpriv --reuid=ergo-runner …` |
| `ERGO_RUNNER_USER` | none | Who each run directory is handed to while a CLI runs in it, when the prefix switches users |
| `ERGO_MAX_PROCESSES` | 8 | CLI processes at once, across all users |
| `ERGO_STAGE_TIMEOUT` | 120 | Seconds per CLI call |
| `ERGO_MODELS_FILE` | none | JSON overriding the models, see below |
| `ERGO_APPLE_APP_ID` | `com.adonis.Ergo` | The audience Sign in with Apple tokens must have, the app's bundle id |
| `ERGO_TRUST_PROXY` | off | `1` or `true` behind a proxy on the same machine or Docker network, such as nginx or Traefik. `compose.yaml` turns it on. Then the per-address limits use the client address the proxy put in `X-Forwarded-For`, see below. Anything but `1`, `true`, `0`, `false` or empty refuses to start. |

Production is `serve --env production`. It refuses to start without a vault key, an unreadable models file, or an unknown runner user.

### Models

Users only choose the provider. By default every stage (gate, breakdown, formalize, verify) uses the same model and effort, and checking a new connection uses the gate stage's:

| Provider | Model | Effort |
|---|---|---|
| Claude (`--model`, `--effort`) | `claude-haiku-5-5` | `medium` |
| Codex (`-m`, `model_reasoning_effort`) | `gpt-6-luna` | `medium` |

`ERGO_CLAUDE_MODEL`, `ERGO_CODEX_MODEL` and `ERGO_MODEL_EFFORT` change that for every stage, and take effect at the next restart. For different models per stage, `ERGO_MODELS_FILE` replaces any cell, and the retry policy. The three variables win over the file:

```json
{
	"claude": { "formalize": { "model": "sonnet", "effort": "high" } },
	"codex": { "verify": { "model": "gpt-5.5", "effort": "medium" } },
	"attempts": 3,
	"verifies": true
}
```

A cell replaces the default cell whole, and leaving out `model` or `effort` leaves out the flag.

## Deploying

The Dockerfile builds from the repository root, since the server needs `../ErgoKit`:

```sh
docker build -f ErgoServer/Dockerfile -t ergo-server .

# Once: a vault key in the data volume, readable only by the server
docker run --rm -v ergo-data:/data --entrypoint sh ergo-server -c \
	'head -c 32 /dev/urandom | base64 > /data/vault.key && chown ergo:ergo /data/vault.key && chmod 600 /data/vault.key'

docker run -d -p 8080:8080 -v ergo-data:/data ergo-server
```

- Claude Code and Codex are pinned with the build arguments `CLAUDE_CODE_VERSION` and `CODEX_VERSION`. Bump them deliberately: the server relies on their flags and output formats. The image build fails if either doesn't run, and if one stops running anyway, the server installs that version again at launch. Neither CLI is ever interactive, so there's no onboarding: each call is `claude -p` or `codex exec` in an empty home, with only that account's credential.
- Put it behind a TLS-terminating proxy. Sockets ping every 20 seconds so a proxy doesn't drop a slow translation or a quiet sync socket.
- New accounts are limited per client address, 5 an hour, and so are registrations (10 an hour) and failed logins. Behind a proxy every request comes from the proxy's own address, so without `ERGO_TRUST_PROXY=1` all clients would share one limit. With it, the right-most `X-Forwarded-For` entry that isn't a local address is the client: the proxy appended it, and everything to its left is the client's to make up. nginx needs `proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;`. It only applies when the connection itself comes from this machine or a private network (`127.0.0.0/8`, `::1`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fc00::/7`), so a client on the internet that reaches the server directly can't set it. Anything else on that private network can, so never set it on a server that is reachable without the proxy.
- Run one instance. The sync socket's broadcaster is in memory, so a push on one instance wouldn't reach devices connected to another. More than one would need Redis pub/sub (or similar) between them, and Postgres rather than SQLite.
- Sign in with Apple fetches Apple's public keys from `appleid.apple.com` and caches them, so the server needs outbound HTTPS.

## Security model

The CLIs run with users' secrets on a machine holding everyone's sealed credentials.

- **Storage:** credentials are sealed with AES-GCM. The associated data is `<account>/<provider>`, so a sealed blob only opens in its own row. Account tokens are stored only as their SHA-256.
- **No tools:** Claude gets `--tools ""`, no settings files and no MCP servers. Codex gets a read-only sandbox, every tool-like feature disabled, no user config and `--strict-config`, so a setting a newer Codex no longer knows fails the call instead of quietly leaving a tool on. Prompt injection can then only produce wrong output, which the app re-parses anyway.
- **Isolation:** every call gets a fresh `0700` directory, with `home/` as its `HOME` and `work/` as its working directory, and an environment built from nothing: a minimal `PATH`, `HOME`, `TMPDIR`, `LANG`, and exactly one credential variable. Nothing from the server's environment reaches a CLI. The user's English only ever reaches a CLI on stdin, as JSON, never in argv.
- **Codex logins:** `auth.json` is written `0600` for each call and read back afterwards. If Codex refreshed it, it's sealed and saved again. Refresh tokens rotate, so each account runs one thing at a time: a second translation, or a connection check, gets `busy` while one is running.
- **Users in production:** the server runs as `ergo`, and every CLI runs as `ergo-runner` through `ERGO_RUNNER_PREFIX`.
  - `/data` (database and key file) is `0700 ergo`, so the runner can't read it.
  - Each run directory is handed to `ergo-runner` with `chown` before the call and taken back afterwards, so the server can read the answer and delete it. The runs directory itself is `0711`: the runner can reach the run it's given but can't list the others.
  - For that the server needs `setuid`, `setgid` and `chown` and nothing else. The image starts as root only long enough to drop to `ergo` with exactly those three as ambient capabilities. The runner prefix clears them again before the CLI starts.
  - All runs share one runner user, so a CLI could in principle reach another call's directory if it knew its random name. With no tools that isn't reachable from a prompt.
- **Email and password:** bcrypt through Vapor's password hasher on its thread pool, so a hash never blocks an event loop. Cost 12, `passwordCost` in tests. Passwords are 10 to 72 bytes (UTF-8) with no NUL, since bcrypt only reads 72 and would quietly accept anything after them; they're hashed as given, with no trimming or normalizing. Emails are trimmed, Unicode-normalized and lowercased, at most 254 bytes, with one `@` and a dot in the domain, and kept in the clear (a login looks them up) behind a unique index. The shapes are `AccountEmail` and `AccountPassword` in ErgoKit, so the app can check before sending. A password is never stored, logged or sent back, and a hash never leaves the server.
- **No account enumeration:** a login for an unknown email checks the password against a made-up hash, so it takes as long as a wrong password, and both answer with the same `invalidCredentials`. Registering an email that's taken does say so (`emailInUse`), which the app needs to offer signing in instead. Anyone can find out whether an email has an account by trying to register it.
- **Brute force:** 10 failed logins per 15 minutes per client address and 10 per email, counted whether or not the email has an account, answered with `rateLimited` and how long to wait. Wrong current passwords when changing a password count too. A success forgets that email's failures, not the address's. In memory, so a restart forgets. The cost: anyone can use up an email's failures to lock its owner out of logging in for 15 minutes.
- **Lost devices:** changing the password deletes every other device's token and closes their live sockets. Signing in with the password on a device doesn't sign the others out.
- **Logs:** never request bodies, secrets, CLI output or synced values. Each call logs its stage, provider, duration, exit status and token usage. A failed call adds the tail of the CLI's stderr. A sync logs only how many records it pushed, changed and returned. Emails, passwords and hashes are never logged: SQL query logging is off (it prints bound values at debug), and the email routes use a database handle at `info` so Fluent's own debug log of every query stays quiet. A test captures the server's logs at `trace` through a real register, login and password change and checks none of them appear.

## Sync

Sync follows `Plans/05-Sync.md`. The merge rules are ErgoKit's `ErgoSync`, so the server and the app merge identically.

- **Accounts and devices:** an account starts anonymous, one per install. Each device has its own token (`account_tokens`), so one device can sign out without the others.
- **Sign in with Apple:** the identity token's signature, issuer, expiry and audience (`ERGO_APPLE_APP_ID`) are checked with Apple's keys, and its `nonce` claim must be the SHA-256 (lowercase hex) of the raw nonce the app sends alongside, so a token meant for another sign-in can't be replayed.
  - No account has that Apple ID yet: the caller's account takes it.
  - Another account has it: the caller's account is merged into it in one transaction. Connections move only for providers the target has none for, synced records merge with `SyncRecord.merge`, the caller's token moves over, and the caller's account is deleted. The device keeps its token.
  - A device already signed in to a different Apple ID has to sign out first.
- **Records:** one row per record (`sync_records`). The fields are sealed with the same key as credentials, with associated data `<account>/sync/<kind>/<id>`, so a board's text is never at rest in the clear and a row can't be moved to another account or record. The server opens them only to merge. In the clear are only the kind, id, seq, when it last changed, for a tombstone when it was deleted and, for a statement or link, which board it is on.
- **Seq:** every record that changes takes the account's next seq, in the same transaction, so a cursor is exactly "everything up to here". Each sync transaction starts with a write, so SQLite hands it the write lock before it reads anything, and two syncs of one account can't take the same seq.
- **One request does both directions:** the push is applied, then everything after the cursor comes back in seq order, at most `limit` records (default 500, at most 1000) and about 4 MB. `more` says to ask again.
- **Conflicts:** an edit whose base isn't what the server has is concurrent. It still merges by stamp, and only the device that pushed it gets the losing value in `superseded`, so the copy is made exactly once.
- **Kinds:** `board` (`created`, `descriptor.0`…`5`, `deleted`), `statement` (`board`, `position`, `content`, `deleted`), `link` (`board`, `premise`, `conclusion`, `deleted`), `bookmark` and `setting`. Board, statement and link ids are uppercase UUIDs. A statement's `content` (`english`, `logic`, `source`, `translation`) is an opaque JSON value to the server, like a board's used to be. Two devices typing in one statement at once give the later pusher a `superseded` `content` for that statement alone; moving a box never conflicts with typing in it.
- **Limits:** a body of 1 MB, a value of 256 KB, 50,000 records per account (statements and links count), 60 syncs a minute per account, and no stamp more than 10 minutes ahead of the server's clock. Kinds, field names and ids are checked against ErgoSync's lists.
- **Pruning:** at launch and then daily, tombstones whose `deleted` stamp is over 90 days old are removed and the account's `prunedThrough` moves past them. A device whose cursor is below it, or ahead of the account, gets `410` `syncResetRequired` and pulls from the start. When a board's tombstone is pruned its statements and links go too, and statements and links with no board record (or no `board` field) go once they're 90 days old; those don't move `prunedThrough`. The owning board's id is kept in a `board_id` column, in the clear like the record id, so none of this opens a sealed row. Devices ignore a statement or link whose board is deleted or missing on read, so nothing waits on the server.
- **Live:** `WS v1/sync/live` sends `changed(cursor:)` to every socket of the account except those of the token that pushed. Signing out closes that device's sockets, and deleting the account closes all of them.

- **Email accounts:** `accounts.email` (unique) and `accounts.password_hash`, both empty until someone registers. An account can have an Apple ID and an email at once, and either gets back in.
  - Registering needs a token and attaches to that device's account. An account has one email.
  - Logging in is the Apple flow with a password: it refuses a device that's already signed in as another account ("sign out first"), and otherwise merges the anonymous account in with `AccountMerger`. `isNewAccount` is always `false`, since an email can only be logged in to once registered. `AccountMerger` refuses to merge away an account that has an email.
  - An account with an email isn't deleted when its last device signs out.

## Sign in with Apple notifications

Apple posts to `POST v1/apple/notifications` when someone changes their Hide My Email forwarding, stops using Sign in with Apple with Ergo, or deletes their Apple Account. It's the server's only route that Apple calls rather than the app.

- **Body:** JSON `{"payload": "<JWT>"}`, or the same `payload` field as `application/x-www-form-urlencoded`. At most 16 KB.
- **Exemptions:** no bearer token, and the only request `ProtocolVersionMiddleware` lets through without `Ergo-Protocol-Version`, since Apple doesn't send it. Only `POST` to exactly this path is exempt.
- **Checks:** the JWT's signature against Apple's published keys (`https://appleid.apple.com/auth/keys`, fetched and cached the same way as for signing in), `iss` is `https://appleid.apple.com`, `aud` is `ERGO_APPLE_APP_ID`, and `iat` is at most a day old and at most 5 minutes ahead of the server's clock. `events` is JSON inside a string; only its `type` and `sub` are read, so `email`, `is_private_email` (a bool or a string) and `event_time` can come in any shape.
- **Answers:** an empty `200` for every verified notification, including one about an Apple ID no account has, one already handled, and an unknown type, so Apple doesn't retry. `400` with the same vague `ServiceError` for anything that doesn't verify, whatever the reason. `413` for a body over 16 KB, `429` after 120 a minute from one address (per address as for the other limits, so `ERGO_TRUST_PROXY` applies), and `502` if Apple's keys can't be fetched, so Apple tries again later.
- **Replays:** each `jti` is remembered for 25 hours (a day being the oldest `iat` accepted) and a repeat is answered `200` without doing anything. If handling fails, the `jti` is forgotten so Apple's retry is handled. The set is in memory, so a restart forgets it: a notification captured in the day before a restart could be handled once more. Every event is safe to repeat except that a replayed `consent-revoked` would sign out devices that signed in again since.

| Event | What the server does |
|---|---|
| `email-enabled`, `email-disabled` | Nothing. The relay address is never stored. |
| `consent-revoked` | Deletes every device token of the account with that `sub` and closes its live sockets, so each device is signed out on its next request. The account, its `appleSubject` and all its data stay, so signing in with Apple again gets back to them. |
| `account-delete` | That Apple ID can never sign in again. An account that also has an email only loses its `appleSubject`, and its devices stay signed in. Otherwise the whole account goes, exactly like `DELETE v1/account`: connections, synced records, every token, and its live sockets. |
| anything else | Nothing, and the type is logged. |

The log says only the event type and whether an account matched. Never the `sub`, an email, a token or the JWT, and the route's queries use the quiet database handle, so Fluent's debug log can't print the `sub` either.

**Registering it**, once the server is hosted: in the developer portal, open Certificates, Identifiers & Profiles → Identifiers → the App ID `com.adonis.Ergo` → Sign in with Apple → Configure (or Edit), and set **Server-to-Server Notification Endpoint** to `https://<production host>/v1/apple/notifications`. It must be an absolute HTTPS URL with TLS 1.2 or later, and there's one per primary App ID group. Then save the App ID.

## Known gaps

- **Emails aren't verified.** Nothing is sent to the address, so anyone can register an email they don't own, which then can't be registered by its owner. There's no mail provider yet.
- **There's no password reset.** Forgetting the password loses the email sign-in, unless the account also has Sign in with Apple. Both need a mail provider, so that's a planned item: verification mail at registration, and a reset link.
- **The login lockout can be used to annoy.** See Brute force above.

## Tests

`swift test` is offline. Shell scripts stand in for `claude` and `codex`, so it never uses a real login, and a fake `AppleTokenVerifier` stands in for Apple. The socket and sync tests run a real server on a free port and talk to it with the app's own `ErgoClient`, and two real `SyncReplica`s converge through the actual route.

Codex can't be called from the network this was built on, so its command line follows the 0.166 docs and `codex exec --help`, and is only exercised with fakes.
