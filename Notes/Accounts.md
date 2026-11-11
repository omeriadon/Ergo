# Accounts, allowances and the paid plan

- See `Plans/11-Paid.md`, and the server's README for the variables. Only the server's own model is counted, at one reference price, in UTC days and weeks. The server's the only judge: `UsageStatus` (`TranslationAccount.usage`) is fetched, never stored, and the app's checks (`hasPlusFeatures`) are only for showing the right screen.
- `ERGO_ENFORCE_PLANS` is off until the App Store products exist, and until then nothing is held back for being free.
- `PurchaseStore` hands StoreKit's signed transactions to the server, and only finishes one the server has. A plan belongs to an account, so buying needs one.
- DeviceCheck gives a phone one free allowance, which can move to a different account once a calendar month. `refreshUsage` claims it when the server says it's needed.
- Anonymous until signed in; sync needs Sign in with Apple or email + password. One account can hold both.
- Email addresses are not verified and there is no password reset yet. A wrong password is `invalidCredentials`, never `.unauthorized`: the app treats `.unauthorized` as a dead token and signs out.
- The server handles Apple's server-to-server notifications at `POST v1/apple/notifications`. Register `https://<host>/v1/apple/notifications` in the developer portal once there is a real host. Replay protection (`jti`) is in memory only.
- Deleting an account revokes its Sign in with Apple. The app sends the credential's `authorizationCode` (`AppleSignIn.credentials`), the server trades it for a refresh token and keeps it sealed on the account, and `DELETE v1/account` revokes it first. A failed trade or revoke never fails a sign-in or a deletion. Without `ERGO_APPLE_SIGNIN_KEY` nothing happens, and anyone who signed in before this shipped has no stored token until they sign in again. See the server's README.
