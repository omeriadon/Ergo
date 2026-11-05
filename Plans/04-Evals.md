# Phase 2c: Evals

A corpus of English arguments with the logic they should become, and a runner that sends each one through a **running server**, exactly as the app does, and scores the result by meaning.

Read [README.md](README.md) (especially **English conventions**), [01-ErgoKit.md](01-ErgoKit.md), and the real ErgoKit sources. You own `Evals/` only.

## Layout

```
Evals/
  Package.swift              depends on ../ErgoKit (ErgoLogic, ErgoTranslation, ErgoProtocol, ErgoClient); macOS only
  README.md                  how to run, how to read results, how to add cases
  Corpus/
    conditionals.json
    syllogisms.json
    connectives.json         and/or/xor/neither/not both/unless/only if
    negation-scope.json
    fallacies.json           invalid forms: affirming the consequent, denying the antecedent, …
    statements.json          claims with no conclusion
    rejections.json          questions, commands, gibberish → gate says neither
    tricky.json              conclusion first, "since/because", reworded claims, double negation
  Sources/ErgoEval/
    main.swift               argument parsing (keep it simple: no ArgumentParser dependency unless it pays for itself)
    EvalCase.swift
    Corpus.swift             load + validate
    Runner.swift             concurrency-limited, through ErgoClient
    Scoring.swift
    Report.swift             Markdown table + JSON
  Tests/EvalCorpusTests/     offline: every case is well formed
  Results/                   .gitignored output (add Evals/.gitignore)
```

## Case format

```json
{
  "id": "modus-ponens-rain",
  "english": "If it rains, the ground gets wet. It's raining, so the ground is wet.",
  "kind": "argument",
  "expected": { "premises": ["X→Y", "X"], "conclusion": "Y" },
  "verdict": "valid",
  "tags": ["conditional", "valid"],
  "note": "optional, why this case exists"
}
```

- `kind`: `argument` | `statements` | `neither`.
- `expected`:
  - Omit it for `neither`.
  - For `statements`, `conclusion` is `""`.
  - Written with the **default letters** X Y Z P Q R, in order of first appearance. Any equivalent form is fine, since scoring is by meaning.
- `verdict` (optional): `valid` | `invalid`. It's cross-checked against `LogicChecker` in the offline tests, so the corpus can't contain a wrong answer key.

Aim for about 80 cases in total.
- Each table row in the README's English conventions needs at least 3 cases.
- Include at least 10 invalid arguments and 8 rejections.
- Write natural English, the kind a student would actually type. Not textbook-stilted.

## Offline tests (`swift test`, no server)

- Every case decodes, and ids are unique.
- Every expected formula parses with `LogicParser`, with no diagnostics, as one statement.
- No more than 6 distinct letters per case.
- `verdict`, when present, matches `LogicChecker`.
- `EnglishValidator.problem(with:)` is nil for every non-`neither` case.

## Runner

```
swift run ErgoEval --server http://localhost:8080 --token <account token> --provider claude
                   [--tag conditional] [--case modus-ponens-rain] [--repeat 3] [--concurrency 1]
```

- The account must already have that provider connected. The README explains how to set that up: through the app, or by curling the connection endpoint. Never hardcode or commit tokens. `--token` can also come from `ERGO_EVAL_TOKEN`.
- Concurrency defaults to 1. The server allows one translation per account at a time, so higher values need several accounts; keep it simple and document that.
- For each case:
  - record every `TranslateServerMessage`, wall time, the final `Translation` or `ServiceError`
  - count formalize attempts (from `started(.formalize, n)`) and whether verify ever ran

## Scoring

Per case, one of:
- **pass:** for `argument`/`statements`, the result's parse is `LogicEquivalence`-equivalent to `expected` under some letter mapping. For `neither`, the result has an error issue and no entries.
- **wrongMeaning:** it parsed but isn't equivalent. Record both forms, read back with `LogicEnglish`, to make review easy.
- **wrongKind:** for example, it gave up on a real argument, or translated a question.
- **failed:** a `ServiceError`, or the pipeline gave up (no entries).
- **unscorable:** equivalence returned nil (uses unchecked symbols). Count it separately.

Report:
- **Overall:** pass rate, mean and p90 latency, mean formalize attempts, how many needed more than one attempt, how many had verify warnings.
- **Per tag:** the same, briefly.
- **Failures:** a table with id, outcome, expected, got, and the first problem/warning.
- **Files:** Markdown on stdout, plus `Results/<ISO date>-<provider>.md` and `.json`.

## Verify

- `cd Evals && DEVELOPER_DIR=… swift build && swift test`, all green.
- If the server from phase 2a already exists and runs, do a dry run of one `neither` case against it with no provider connected, and check it reports `failed` with `.notConnected`. Don't use Adon's tokens.

## Report back

- Case counts per file.
- Anything in the conventions table you found ambiguous while writing cases. These need Adon's call, since prompts and corpus must agree.
