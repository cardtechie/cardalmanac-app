# Draft-Status Gate Verification

How to verify Card Almanac against the Trading Card API's draft-status gate, and
why the verification has to be a real measurement rather than an argument.

Tracking issue: [cardtechie/cardalmanac-app#437](https://github.com/cardtechie/cardalmanac-app/issues/437).
Coordination issue: [cardtechie/tradingcardapi-api#2437](https://github.com/cardtechie/tradingcardapi-api/issues/2437).

## What the gate is

[cardtechie/tradingcardapi-api#2383](https://github.com/cardtechie/tradingcardapi-api/issues/2383)
gates players, teams and player-teams on publication status, via a materialised
`published_visible` column. Before the gate, `/v1/players` and `/v1/teams`
returned entities that appear only on unpublished cards; after it, they do not.
[cardtechie/tradingcardapi-api#2435](https://github.com/cardtechie/tradingcardapi-api/issues/2435)
changes the `/v1/stats/*` totals for the same reason.

**The gate is silent by design.** A caller on a customer-grade token gets no
error and no warning — only fewer rows. That is what makes it dangerous to
verify by reasoning: nothing fails, so a check that does not compare real
numbers cannot tell a correct result from a missed one.

### Current state: merged, not live

The gate shipped **default-off**, behind `STATUS_GATE_ON_CARDABLE_ENABLED`
(config `api.on_cardable_enabled`). api#2383 requires a production
`EXPLAIN FORMAT=TREE` plus a timed unbounded `COUNT` — captured by the API's own
`php artisan status-gate:measure-on-cardable` — before it may be switched on.

So the precondition in #437 ("merged AND deployed to an environment you can
actually query") is **half met**: the code is merged, the behaviour is not live.
Only the "before" capture can be taken today.

## Static inventory: what this app actually reads

This app browses published content. A repo-wide search (excluding `vendor/`,
`node_modules/`, `public/`, `storage/`, `.git/`) finds **no reference to
players, teams, player-teams or `/v1/stats` anywhere in its source**. The only
matches are prose or unrelated boilerplate:

| Path                                                 | Why it matches                                                                                |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `resources/views/about.blade.php`                    | Prose naming player and team among the resources the almanac covers                           |
| `resources/content/blog/introducing-card-almanac.md` | Launch post listing "Cards by player and team" as a capability                                |
| `resources/js/bootstrap.js`                          | Laravel's stock comment, "allows your team to easily build robust real-time web applications" |

Every API call this app makes goes through the `tradingcardapi()` SDK helper,
and the complete set lives in `app/Http/Controllers/SetController.php` and
`app/Http/Controllers/SetGenreController.php`:

- `genre()->list()`
- `set()->list(['genre' => …])` and `set()->list(['include' => 'genre'])`
- `set()->get($id, ['include' => 'genre,manufacturer,brand,year'])`
- `set()->get($id, ['include' => 'checklist'])`

The expected browse-count delta is therefore **zero**.

**That is a hypothesis, not the verdict.** #437 explicitly forbids closing on
reasoning, and it is right to: a reasoned "no change needed" against a silent
gate is unfalsifiable from the outside. The inventory explains what a zero delta
would mean; it does not establish that the delta is zero.

`tests/Feature/DraftGateSurfaceTest.php` pins the inventory, so a future change
that starts reading a gated entity fails loudly and re-opens this verification
instead of silently invalidating its conclusion.

## Taking the measurement

`php artisan browse:capture-counts` records every count this app surfaces to a
visitor — genre totals, the full set listing, the per-genre set rails that
`SetController::index` renders, and (with `--set`) one set's checklist rows — as
a timestamped JSON artifact. Each artifact carries the API base URL and the app
version in its header, so two captures can be shown to have come from the same
app against the same API.

A capture unit that fails is **recorded and skipped**, not fatal: a partial
capture is still comparable and its gaps are visible in the artifact's
`failures` map. That mirrors the degrade-not-500 posture pinned for the
controllers in `tests/Feature/ApiFailureHandlingTest.php`.

### 1. Before

Point the app at a live or staging API (see
[LOCAL-ENVIRONMENTS.md](LOCAL-ENVIRONMENTS.md) → _Pointing the app at a live or
staging API_), with `STATUS_GATE_ON_CARDABLE_ENABLED` **off**:

```bash
php artisan browse:capture-counts \
  --set=<a set id with a checklist> \
  --out=storage/app/browse-counts-before.json
```

Keep the artifact. It is the evidence, not a scratch file.

### 2. Enable the gate

An operator sets `STATUS_GATE_ON_CARDABLE_ENABLED=true` on the API in an
environment this app can query, after api#2383's production measurements have
been captured. **Do not mock the gate, do not enable it behind a local flag and
treat that as equivalent, and do not reason from the api#2383 spec about what it
will return.** #437 rules all three out: the acceptance criterion is a real
request carrying the real token against a live gated endpoint.

### 3. After, and the diff

```bash
php artisan browse:capture-counts \
  --set=<the same set id> \
  --compare=storage/app/browse-counts-before.json
```

`--compare` takes a fresh capture, writes it out, and prints a per-key
before/after/delta table. It exits **non-zero when any count moved**, so it works
as a check and not only as a report. It warns loudly when the two artifacts came
from different API URLs or different app versions — a delta across those is not
a gate measurement.

## Pass criterion

Every non-zero delta must be attributable to **draft-only entities disappearing**,
and nothing else. A delta explained by a set being published in between, by a
different API URL, or by a failed capture unit is not a pass — re-take the
measurement.

A zero delta has **two possible readings**, and they are not interchangeable:

1. **Nothing consumed** — this app reads no gated entity, which is what the
   static inventory above predicts.
2. **Nothing gated** — this app's OAuth client
   (`TRADINGCARDAPI_CLIENT_ID`) holds a scope that bypasses the gate, so the
   gate never applied to these requests in the first place.

Confirm which one you are looking at **before** the "after" run, by asking the
API operator what scopes this app's client holds. Reading (2) as (1) would
retire the task while leaving the risk in place.

## Do not close #437 on the "before" capture alone

The "before" capture proves the instrument works. It proves nothing about the
gate. Until an operator has enabled `STATUS_GATE_ON_CARDABLE_ENABLED` in a
queryable environment and the diff in step 3 has been run and explained, the
verification is incomplete — and, per #437, "a verification that runs before the
thing it verifies is worse than no verification, because it retires the task
while leaving the risk in place."
