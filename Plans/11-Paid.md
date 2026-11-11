# 11 · Paid and usage

Built. It's off in production until the App Store products exist and `ERGO_ENFORCE_PLANS` is set, and the prices are still to be chosen.

What's free, what's paid, and how AI use is limited. Nothing is priced. Monetisation comes after users, so the price waits for TestFlight. What the AI should do is in [12-Identity.md](12-Identity.md).

**Decided** means Adon has settled it. **Proposed** means it's on the table but not agreed.

## Free

**Decided:**
- All four tabs, the Library and widgets. The Library is what sets Ask apart from a general chatbot, and is never gated.
- Scratchpads: the logic checker, `LogicEnglish` readings and saved scratchpads.
- Ask and the board's AI, on Ergo's model within the daily limit, or on the person's own login or API key.
- One deep research a week.
- Break Down up to `EnglishValidator.characterLimit` (1,500 characters).

**Proposed:** free users get OpenRouter's free models. See [what free models can carry](#what-free-models-can-carry).

## Paid

**Decided**, in the order they'd be built. The better model has a running cost, so it's last.

1. **Shared boards**, through [09-Sharing.md](09-Sharing.md).
2. **The logic course**, built on the Logic tab, with the checker staying free.
3. **A better model.** A stronger model id for paying accounts. The server reads one id today, so this needs one per tier.

**Proposed:** viewing a shared board stays free and only editors are paid, since every invite shows Ergo to someone new.

**Proposed:** text longer than the Break Down limit is paid. See below.

## Own logins and API keys

**Decided:**
- Claude and Codex logins stay for now. Adon knows the Claude login is doubtful under Anthropic's terms, and ChatGPT has its own sign-in.
- Add a way to use an API key.
- Neither counts against the limit, since they cost Ergo nothing.

## The daily limit

**Decided:**
- Counted in real cost per day, and shown as one bar in Settings → AI.
- A free model is counted at a paid model's price, so the bar means the same whatever is running.
- Whatever is running always finishes. The next request says when the bar resets, and offers paid.
- Every chat mode and Quick AI use the same bar. It doesn't matter which mode a message was in.
- One deep research a week, counted apart from the bar, since one run would use all of it.

**Proposed:** count at GPT-5.6 Luna's price ($0.20 in, $1.20 out per million tokens) and allow $0.03 a day, which is about 10 chat messages. Once Ergo pays for a cheap model, that's at worst about $0.90 per user per month.

### One free allowance per device

**Decided:** making new accounts doesn't give more free AI.

Apple's DeviceCheck only stores two bits per device, so it can't hold a count. The bits mark that a device has claimed a free allowance, the server remembers which account claimed it, and any other account on that device gets no allowance on Ergo's model. Its own login or an API key still works. A phone can move its allowance to a different account once a month, which covers one that's shared or sold. DeviceCheck keeps the month its bits were last set, so that's all the server needs.

### What it costs

Estimates from the size of the prompts and library entries, with no caching, at November 2026 prices.

| | Claude Sonnet 5.5 | GPT-5.6 Luna | DeepSeek V4 Flash | Free model |
|---|---|---|---|---|
| Chat message with one library lookup (about 3 model calls) | ~$0.026 | ~$0.003 | ~$0.001 | 3 requests |
| Analysis of a document as built today (about 60 calls) | ~$3 | ~$0.30 | ~$0.14 | 60+ requests |

### What free models can carry

OpenRouter allows 1,000 free requests a day once $10 of credits has been bought, 50 a day before that, and 20 a minute. More keys or accounts don't raise it, so that's for all of Ergo: about 330 chat messages, or 16 of today's analyses, a day. It's enough for TestFlight and not for a launch.

Some free providers may train on what they're sent. Check each model before saying anything about privacy.

## Long text into Break Down

**Built:** Break Down takes text too long for one run and shows how many parts it will become, up to 40.
- Parts split at paragraph breaks, then sentences, each under the limit.
- Each part is its own server run, one after another. The cards from every part go onto one board, each part with its own source and region. Repeats across parts aren't merged yet.

## Open

- The price and its shape.
- Which paid model, and what limit paying accounts get. At Sonnet's price a $5 subscription covers about 160 chat messages after Apple's cut.
