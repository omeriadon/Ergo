# Sharing into the app (the share extension)

- The extension only asks what to do (add to chat, break down, add to board). It saves a `SharedItem` to `SharedItemInbox` in the App Group `group.com.adonis.Ergo`, then tries to open the app with `ergo://share`.
- Apple doesn't support share extensions opening their app, so `ShareViewController.openErgo` goes through the responder chain and may stop working. The app checks the inbox whenever it becomes active, so a share is never lost: the extension then says to open Ergo by hand.
- `PageReader` fetches links on the device. Nothing runs JavaScript, so pages built by scripts have little text.
- Shared text and links go through `AddToChatSheet` and are attached unsent, since the person still has a question to ask. A link's page text is read on the way in, since the CLI can't open links. Break Down starts on its own only when the text fits `EnglishValidator.characterLimit`. On a board, what's shared becomes a source.
