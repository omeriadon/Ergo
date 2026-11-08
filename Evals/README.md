# Evals

English arguments with the logic they should become, and `ErgoEval`, which sends each one through a running Ergo server's translate route and scores the result by meaning. The app no longer translates, so this route is only here for the evals.

Every command below needs the beta toolchain:

```sh
export DEVELOPER_DIR="/Applications/Xcode 27.3 beta 1.app/Contents/Developer"
```

## Offline tests

```sh
cd Evals && swift build && swift test
```

No server needed. These check the corpus itself:
- every file decodes and ids are unique
- every expected formula parses with `LogicParser`, with no diagnostics, as one statement
- letters are X Y Z P Q R, at most six, with none skipped
- `verdict` matches `LogicChecker`
- `EnglishValidator` lets every case through, except rejections tagged `local`, which it has to stop
- each row of the English conventions table has at least 3 cases, with at least 10 invalid arguments and 8 rejections
- the scorer gives `pass` when a case's own answer key comes back as the translation

`ErgoEval` runs the same corpus checks before it starts and refuses to score against a broken answer key.

## Running against a server

### 1. An account with a provider connected

Use a separate account for evals, not the app's. The app keeps its token in the Keychain, and a separate account keeps eval usage apart.

```sh
SERVER=http://localhost:8080

# Prints {"id": …, "token": …}. The token is shown only once.
curl -s -X POST -H 'Ergo-Protocol-Version: 1' "$SERVER/v1/accounts"

# Paste the token without it going into your shell history
read -rs ERGO_EVAL_TOKEN && export ERGO_EVAL_TOKEN
```

Then connect a provider. `kind` is `subscription` (the output of `claude setup-token`, or the contents of `~/.codex/auth.json`) or `apiKey`:

```sh
read -rs SECRET
jq -n --arg secret "$SECRET" '{kind: "apiKey", secret: $secret}' \
	| curl -s -X PUT "$SERVER/v1/connections/claude" \
		-H 'Ergo-Protocol-Version: 1' \
		-H "Authorization: Bearer $ERGO_EVAL_TOKEN" \
		-H 'Content-Type: application/json' \
		--data @-
unset SECRET
```

The server checks the credential with one real call before saving it. Never put tokens or keys in a file in this repo.

You could connect the provider in the app instead, but then the token is that install's, and it only lives in the Keychain.

### 2. Run

```sh
swift run ErgoEval --server "$SERVER" --provider claude
swift run ErgoEval --server "$SERVER" --provider claude --tag unless --tag xor
swift run ErgoEval --server "$SERVER" --provider claude --case modus-ponens-rain --repeat 3
```

| Option | Default | |
|---|---|---|
| `--server` | required | http or https |
| `--provider` | required | `claude` or `codex` |
| `--token` | `ERGO_EVAL_TOKEN` | the account's bearer token |
| `--tag`, `--case` | everything | repeatable, a case runs if it matches any of them |
| `--repeat` | 1 | runs each case this many times |
| `--concurrency` | 1 | translations in flight at once |

The server runs one translation per account at a time and answers a second one with `busy`. With a single token, keep `--concurrency` at 1: higher values only make sense once the runner can spread work across several accounts, which it doesn't do yet.

A full run makes about four model calls per case, more when formalize retries, so it uses the connected account's quota.

## Reading the results

Progress goes to stderr, one line per run. The report is Markdown on stdout, and is also written to `Results/<date>-<provider>.md` and `.json`. `Results/` is ignored by git.

Each run gets one outcome:

| Outcome | Meaning |
|---|---|
| `pass` | `argument`/`statements`: the parsed result is `LogicEquivalence`-equivalent to `expected` under some renaming of letters, comparing all the premises joined with ∧, and the conclusion separately. `neither`: an error issue and no entries. |
| `wrongMeaning` | It parsed, but no renaming makes it equivalent. |
| `wrongKind` | The gate turned real logic away, logic was written for a rejection, or an argument and statements got mixed up. |
| `failed` | A `ServiceError` (from the server or the client), the pipeline giving up after breakdown, or logic that doesn't parse. |
| `unscorable` | The result uses □ ◇ ∀ ∃, predicates or sets, which equivalence can't compare. Counted separately, read these by hand. |

The report has:
- **Overall:** pass rate, mean and p90 wall time, mean formalize attempts (over runs that got that far), how many needed more than one attempt, and how many finished with verify still disagreeing.
- **By tag:** the same, briefly.
- **Failures:** id, outcome, expected and got formulas, and the first problem or warning.
- **Readings:** for failures that produced logic, the English, then both formulas read back with `LogicEnglish`. Both readings use the translation's descriptors, which assumes both sides lettered claims by first appearance. So if they read the same but the formulas differ, the letters are probably just in another order.

The JSON has every run in full: the case, every `TranslateServerMessage` the server sent, the time, any thrown error, and the score.

## Adding cases

Put each case in the file that fits it best. Every file is an array of:

```json
{
	"id": "modus-ponens-rain",
	"english": "If it rains, the ground gets wet. It's raining, so the ground is wet.",
	"kind": "argument",
	"expected": { "premises": ["X→Y", "X"], "conclusion": "Y" },
	"verdict": "valid",
	"tags": ["conditional", "if-then"],
	"note": "optional, why this case exists"
}
```

- `kind` is `argument`, `statements` or `neither`.
- Leave out `expected` for `neither`. For `statements`, `conclusion` is `""`.
- Write `expected` with the default letters X Y Z P Q R, in the order the claims first appear in the English. Any equivalent formula is fine.
- `verdict` is optional, but give it for every argument the checker can decide, except enthymemes, where "invalid" isn't what the case is about.
- `descriptors` is optional and rare: the board's six letter names, with `""` for free slots, sent with the request for a case about keeping a letter. The runner always asks for the `statement` scope and sends none otherwise.

Follow the English conventions table in `Plans/README.md` exactly, because the server's formalize prompt follows it too. On top of the table, the corpus assumes:
- **One premise per separately asserted sentence or clause.** "It's sunny but freezing" is one premise, X∧Y, as the table says. Two facts in separate sentences are two premises. Scoring joins the premises with ∧, so how they're split doesn't change the score.
- **Plain "or" is inclusive,** the same as "either … or".
- **Words like "must" and "can't" in ordinary English aren't □ or ◇.** "So it must have rained" is just the conclusion.
- **No antonym pairs.** "Dry" isn't written as ¬wet, and "fine" isn't ¬broken. Use the negation the English actually says ("isn't wet").

Tags:
- **Convention rows:** `conditional`, `iff`, `unless`, `either-or`, `xor`, `neither`, `not-both`, `but`, `since-because`. Each needs 3 or more cases.
- `fallacy`: exactly the cases whose verdict is invalid.
- `local`: only on `neither`, for input `EnglishValidator` rejects before any model call, like keyboard mashing.
- Anything else is free-form and shows up in the per-tag table.

Then run `swift test`.
