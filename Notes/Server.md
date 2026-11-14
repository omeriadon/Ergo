# The server: environments and logs

Everything else about the server is in `ErgoServer/README.md` and `ErgoServer/ENVIRONMENT.md`.

- Release builds always use `ServerEnvironment.productionURL` (`https://ergo-15.235.184.129.sslip.io`, hosted on Dokploy).
- Debug builds can switch between Production and This Mac (Settings → AI → Server, which also has a Test Server row). For a phone, run the Mac server with `--hostname 0.0.0.0`.
- Silent while things work: only `warning` and `error` reach the log for most accounts, and those carry a pseudonym (`VerboseAccounts.pseudonym`), never the id, an email, a token or what anyone wrote. Real ids and every routine line are only for the accounts in `ERGO_VERBOSE_ACCOUNTS`. Not even they get secrets or content: sizes and counts instead. See the server README's Logs.
- Log through the account's logger (`request.logger` after `AccountAuthenticator`, or `request.jobLogger(for:)` for work that outlives the request). `logger.verbose(…)` is for what is normal and does nothing for anyone else, `warning` and `error` for problems, and `logger.reason(for:)` for an error. Never `info` on a logger that isn't an account's.
- `ErgoKit/Tests/ErgoLiveTests` runs the whole API against a running server through `ErgoClient`, everything but Sign in with Apple and the AI runs: `ERGO_LIVE_SERVER=<address> swift test --filter ErgoLiveTests`. It's skipped without the variable. It makes four accounts on `example.com` emails and deletes them even when it fails, and a server allows five new accounts an hour from one address, so it can run about once an hour. Anything new in the API gets a step there.
