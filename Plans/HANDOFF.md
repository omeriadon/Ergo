# Handoff, as of 2026-11-08

For a new agent picking the project up. Read `CLAUDE.md` first (`AGENTS.md` is a symlink to it), then [07-Direction.md](07-Direction.md) for where it's heading. This file only holds what neither says.

## Working with Adon

- **ErgoServer:** never build it. Adon builds and deploys it. Diagnose from manifests and sources.
- **Docker:** never install it on his Mac. Production runs in containers on Dokploy, which is his to manage.
- **Agents:** when he asks for subagents, start them as Sonnet 5.5 at high effort, and tell them the hard rules: no git, no simulator, no building ErgoServer, the `DEVELOPER_DIR` prefix, the style, never his own Claude or Codex credentials, and stay in their own folder.
- **Communication:** plain, short and honest. He gets frustrated by long surveys and caveats. When he says "just do it", do it, and say plainly what was and wasn't verified.
- **Another agent** may be working in the repo at the same time. Read a file right before editing it, keep edits small, and never revert changes you don't recognise. If a build breaks in code you didn't touch, wait and retry rather than "fixing" it.
- **Running the app** is his job. Agents only know how it behaves on a device from what he reports.

## Confirmed

- The server runs in production at `ServerEnvironment.productionURL`, hosted on Dokploy, which settles the old questions about building on Linux and putting WebSockets behind a proxy.
- A full Codex eval ran through production on 2026-11-07: 89 of 93 cases passed. That was the first live Codex test. It only covers the translate route, which the app no longer uses.
- Production serves the app-site association for invite links (checked 2026-11-08), so the sharing server is deployed.

## Open

- **Sharing and pushes** haven't been tried on devices. That's first on the checklist in 07.
- **`aps-environment`:** `Ergo/Special/Ergo.entitlements` says `production`, but `CLAUDE.md` and 09 say it's always `development`. Ask Adon which is meant.
- **The device connectivity bug** from 2026-11-05 (Settings showed Claude connected, but Translate said "Couldn't reach the Ergo server" against This Mac). Nobody has said whether it still happens.
- **Revoking Sign in with Apple** on account deletion isn't built. App Store guideline 5.1.1(v) needs it. It needs a `.p8` key, its Key ID and the team on the server (the app target's team is `P6PV2R9443`), and the app sending the sign-in `authorizationCode`.
- **Email** addresses aren't verified and there's no password reset. Both need a mail provider, which isn't chosen.
- **Apple's notification URL** (`https://<host>/v1/apple/notifications`) may not be registered in the developer portal yet, and its replay protection is in memory only.
- **Saving passwords** needs a `webcredentials:` associated domain. The entitlements don't have one.
- **One server instance only:** the live sync broadcaster is in memory.
- **Accepted by Adon:** if the server's reply is lost at the exact moment two devices edit the same board, one version can be lost with no conflict copy.

## The rackmill incident

Adon's old server, `rackmill`, was found compromised on 2026-11-05: a password login to a sudo account, then root, then persistent malware. The full report is `~/Backups/rackmill-2026-11-05/forensics/REPORT.md`, beside an untrusted backup of the server. Never extract or run anything from it on the Mac, including the inert malware tarball.

Everything stored on that host has to be treated as exposed and rotated from a clean machine: SSH keys (including the GitHub deploy key and the `github-actions-deploy` secret), the Resend, APNs, WeatherKit, R2 and AWS keys his other apps use, `.env` files, database passwords, the Pterodactyl `APP_KEY` and TLS keys. Nothing here records whether that's been done, or whether rackmill was wiped. Ask before assuming either.
