# Secret History Purge

Operator runbook for [#462](https://github.com/cardtechie/cardalmanac-app/issues/462):
removing the credentials that are permanent in this repository's git history, before the
repository is flipped public.

This is a **manual, operator-executed procedure**. It ends in a force-push that rewrites
every commit, which is not something a pull request or a CI job can do. This repository
ships the two scripts that make the run repeatable and verifiable
(`build/secret-purge-expressions.sh`, `build/verify-secret-purge.sh`); the runbook below
is the procedure they belong to.

Read the [Decision](#decision-go-or-no-go) section first. Doing nothing is a legitimate
outcome, and it is cheaper than this procedure.

## What is actually exposed

Removing a value from `HEAD` does not remove it from history, and flipping the repository
public publishes the full history. But the reverse matters too, and the issue's original
scope table did not reflect it: **`HEAD` is already clean.** Every value that table marked
as live at `HEAD` is now delivered by variable reference, empty, or explicitly allowlisted.

| Secret                                                                                                                                                                              | Where it is                                                                                        | Status                                                                                                                |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Admin production DB password (as `DB_PASSWORD` **and** `CARDS_DB_PASSWORD`)                                                                                                         | history only (`20f0dce`, `8b77b2c`)                                                                | **LIVE** — blocked on `tradingcardapi-admin#1414`                                                                     |
| Admin production DB username (as `DB_USERNAME` **and** `CARDS_DB_USERNAME`)                                                                                                         | history only (`20f0dce`, `8b77b2c`) — was also in this document's own text until #495 corrected it | **LIVE** — blocked on `tradingcardapi-admin#1414`                                                                     |
| Admin production DB database name (as `DB_DATABASE` **and** `CARDS_DB_DATABASE`)                                                                                                    | history only (`20f0dce`, `8b77b2c`) — was also in this document's own text until #495 corrected it | **LIVE** — blocked on `tradingcardapi-admin#1414`                                                                     |
| Admin production `APP_KEY`                                                                                                                                                          | history only (`20f0dce`, `8b77b2c`)                                                                | **LIVE** — still at `tradingcardapi-admin` HEAD; blocked on `tradingcardapi-admin#1414`                               |
| DigitalOcean cluster host (`DB_HOST`, `CARDS_DB_HOST`)                                                                                                                              | history only                                                                                       | Live coordinate for a live cluster                                                                                    |
| `cardalmanac_blog` DB password                                                                                                                                                      | history only                                                                                       | Dead — revoked in #468                                                                                                |
| This repo's production `APP_KEY`                                                                                                                                                    | history only                                                                                       | Removed from HEAD by #430; rotate per #430                                                                            |
| Mailgun API key                                                                                                                                                                     | history only (`.docker/docker-compose.full.yml`, `.env.local` from `20f0dce`)                      | `MAILGUN_SECRET` and `MAILGUN_DOMAIN` are both varrefs at HEAD (#460)                                                 |
| Passport client ID + secret                                                                                                                                                         | history only                                                                                       | Both varrefs at HEAD                                                                                                  |
| Eight `WP_*` auth keys/salts (`WP_AUTH_KEY`, `WP_SECURE_AUTH_KEY`, `WP_LOGGED_IN_KEY`, `WP_NONCE_KEY`, `WP_AUTH_SALT`, `WP_SECURE_AUTH_SALT`, `WP_LOGGED_IN_SALT`, `WP_NONCE_SALT`) | history only (`.env.local`, `cc39616` → `06aa06b`, removed by `b0e4c82`)                           | Dead — WordPress removed in #108; blog is flat-file (#468)                                                            |
| Local dev `APP_KEY`                                                                                                                                                                 | HEAD (`.env.local`)                                                                                | Empty (`APP_KEY=`)                                                                                                    |
| Local dev DB password                                                                                                                                                               | HEAD                                                                                               | The literal string `password`, on containers never exposed off the developer machine; allowlisted in `.gitleaks.toml` |
| Self-signed dev TLS private keys                                                                                                                                                    | HEAD (`.docker/{admin,api,cert}/*.key`)                                                            | Deliberately committed, allowlisted in `.gitleaks.toml`; owned by #425                                                |

So the remaining exposure is **entirely historical**, which is what this procedure
addresses — and the scope must be derived from history, not from a HEAD-facing table.
That is why `build/secret-purge-expressions.sh` reads history rather than taking a
hand-written list.

The earliest commit touching any in-scope file is `20f0dce` (2022-03-18), which is
effectively the start of the repository. **The rewrite therefore re-SHAs the entire
history** (723 commits on `main` at the time of writing).

## Gate conditions

**Rotate first, purge second.** A history rewrite does not un-leak a credential that was
already exposed to anyone with repository access — rotation is what neutralizes it. The
rewrite only stops shipping the evidence to the public.

All of these must be **closed** before the procedure below is run:

| Blocker                                                                                       | What it covers                                                            |
| --------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| [#430](https://github.com/cardtechie/cardalmanac-app/issues/430)                              | This repo's production `APP_KEY`                                          |
| [#460](https://github.com/cardtechie/cardalmanac-app/issues/460)                              | Mailgun API key                                                           |
| [#461](https://github.com/cardtechie/cardalmanac-app/issues/461)                              | Passport client secret                                                    |
| [#463](https://github.com/cardtechie/cardalmanac-app/issues/463)                              | `.env.local` untracking                                                   |
| [`tradingcardapi-admin#1414`](https://github.com/cardtechie/tradingcardapi-admin/issues/1414) | Admin production `APP_KEY`, DB password, DB username and DB database name |

`tradingcardapi-admin#1414` is the long pole. Those credentials cannot be rotated until
that repository stops shipping them in its deploy compose file, or
`admin.tradingcardapi.com` goes down at rotation.

**None of these secrets is confined to this repository.** The admin DB credentials
(password, username, database name), the admin `APP_KEY`, the Mailgun key and the
Passport secret each appear in `tradingcardapi-admin`, `tradingcardapi-api` or
`cardtechie-site` as well. Rotation is a
cross-repo coordination problem, and purging _this_ repository's history does not by
itself neutralize any of those values.

Once every value is rotated, this rewrite becomes **optional risk reduction** rather than
a hard gate. See [Decision](#decision-go-or-no-go).

## Known costs

Re-measure these at run time rather than trusting the numbers below; they move.

| Cost                             | Reading (2026-09-08)                        | How to re-check                                            |
| -------------------------------- | ------------------------------------------- | ---------------------------------------------------------- |
| Every commit SHA changes         | 723 commits on `main`                       | `git rev-list --count origin/main`                         |
| Open PR refs break               | 32 open, of which 4 are not bot-authored    | `gh pr list --state open --limit 100 --json number,author` |
| Collaborators must re-clone      | 1 (`picklewagon`)                           | repository settings                                        |
| Forks must be handled separately | 0                                           | `gh repo view --json forkCount`                            |
| External SHA references go stale | CHANGELOG entries, Asana links, deploy tags | —                                                          |

The Dependabot PRs can be closed en masse; Dependabot re-opens them against the rewritten
history on its next run. **Non-bot PRs cannot be treated that way** — merge or close them
deliberately before the rewrite, or their branches have to be rebuilt by hand afterwards.
At the time of writing, all four are runner PRs for the blocker issues above, so the gate
conditions and this cost clear together.

GitHub retains unreferenced objects for a period after a force-push, and cached views can
still serve an old commit by SHA. Contact GitHub Support to have them expunged if that
matters for the public flip.

## Procedure

The scripts live in this repository, so run them from your checkout — but keep every
_artifact_ (the mirrors and the generated expressions file) in a scratch directory outside
it, which is what the explicit `--out` below is for. No step rewrites, checks out, or
otherwise mutates the working clone you invoke them from.

### 1. Confirm the gates

Every issue in [Gate conditions](#gate-conditions) is closed, and the credentials are
**rotated**, not merely removed from `HEAD`. This is a judgement step, not a scripted one.

### 2. Take the backup mirror

The backup is the rollback. Take it before anything else, and keep it until the public
flip is done and verified.

```bash
git clone --mirror git@github.com:cardtechie/cardalmanac-app.git /path/to/scratch/cam-backup.git
```

### 3. Generate the expressions file

```bash
build/secret-purge-expressions.sh --out /path/to/scratch/purge /path/to/scratch/cam-backup.git
```

Writes `/path/to/scratch/purge/replace-text.txt`, mode `0600`. Pass `--out` explicitly:
without it the file lands in `<repo>/.secret-purge/`, inside your checkout. That default
path is gitignored, so it is safe rather than wrong — but a credential-bearing artifact
belongs in the same scratch area as the mirrors, not in a normal working clone. The script
refuses to run against anything but a bare mirror.

> **The generated file is a plaintext list of live credentials.** Do not commit it, paste
> it into an issue or a PR, or let it reach a CI log. Delete it when the purge is verified.
> The scripts themselves never print a value — everything is reported by truncated SHA-256
> fingerprint and character count, so their output is safe to paste.

The script prints two tables always, plus a third, conditional one. **Read all printed
tables before continuing.**

- **INCLUDED** — what will be rewritten.
- **EXCLUDED** — what will not, and why. `present-at-head` means the value still exists in
  the `HEAD` tree; since `HEAD` is clean, a survivor is a dev default (a compose service
  name, a database name, the literal `password`). `too-short` means shorter than
  `--min-length` (default 8). Both exclusions exist because the in-scope key set includes
  `DB_HOST` and `DB_USERNAME`, which in the dev compose files hold 4- and 5-character
  tokens — and a `literal:` rewrite of a token that short replaces **every** occurrence of
  it across all of history, including unrelated prose. That is far more damaging than
  leaving a non-secret in place. `gitleaks-allowlist` means the value matched an allowlist
  regex in `.gitleaks.toml` — the repository has already declared it not-a-credential.

Nothing is dropped silently. If you disagree with an exclusion, add its
`literal:<value>==>***REMOVED***` line to the file by hand, or lower `--min-length`.

A third table, **UNSCOPED**, can also print: every `KEY=value` / `KEY: value` assignment
found in the scope paths' history whose key is **not** in the generator's fixed key-name
set, whose value is at least `--min-length` characters, and which is not a variable
reference. It exists because a fixed allowlist can only ever catch a key somebody already
thought of — this issue (#495) is the second time an inventory gap was found in the same
purge tooling, first with the WordPress salts below. UNSCOPED entries are reported by
fingerprint, character count and key name only, exactly like INCLUDED and EXCLUDED, and
they are never written to the expressions file. **Review the UNSCOPED table before
continuing to step 4.** A non-empty table does not fail the script (see the Decision
section's operator judgement call on this); it is a prompt to decide, by key name, whether
each entry belongs in `SCOPE_KEYS` and needs a follow-up run.

Sanity-check the count against the scope table above: the expected shape is several
distinct 51-character `APP_KEY` values, one 60-character cluster host, the 16-character
password and username, the admin production database name (`DB_DATABASE` **and**
`CARDS_DB_DATABASE` — present in the scope table above, so its absence from this shape
should not go unnoticed), eight 64-character `WP_*` values, and the Mailgun and Passport
values.

### 4. Rewrite

```bash
cp -R /path/to/scratch/cam-backup.git /path/to/scratch/cam-rewritten.git
git -C /path/to/scratch/cam-rewritten.git filter-repo \
    --force --replace-text /path/to/scratch/purge/replace-text.txt \
    --path .claude/PROJECT-OVERVIEW.md --invert-paths
```

`--path ... --invert-paths` removes that whole file from every commit, in the same single
pass as the credential substitution. It is a non-secret document that must not be
published (#507 — see [Non-secret content removed before publish](#non-secret-content-removed-before-publish-507)),
and `--replace-text` cannot remove a file. The file must already be deleted on `main`
before this step runs, or check 2 below fails. Every path added here must also be added to
`REMOVED_PATHS` in `build/verify-secret-purge.sh`, and vice versa.

`git filter-repo` is not bundled with git — install it separately
(`brew install git-filter-repo`). It removes the `origin` remote as it runs; that is
expected and is why the push in step 6 names the URL explicitly.

### 5. Verify

```bash
build/verify-secret-purge.sh /path/to/scratch/cam-backup.git /path/to/scratch/cam-rewritten.git
```

Four checks, all of which must pass:

1. **literal-hits** — zero occurrences of every in-scope literal across all refs of the
   rewritten mirror, covering commit messages as well as file contents.
2. **head-tree** — `HEAD^{tree}` is byte-identical between the two mirrors, proving the
   rewrite changed history and nothing else.
3. **refs** — every branch and tag present before the rewrite is present after.
4. **removed-paths** — no commit on any ref of the rewritten mirror touches a path listed in
   the script's `REMOVED_PATHS` array (#507). Check 1 scans for credential literals and
   cannot see a whole non-secret file surviving the rewrite; this check can.

The verifier **rebuilds the literal set from the backup mirror** rather than reading the
expressions file `filter-repo` was run with. That is deliberate, and it is the specific
failure #462 warns about: a `--replace-text` file built from a stale scope table purges
dead values, leaves live ones, and then verifies itself green because it only checks for
literals already on its own list.

Run the negative test **once** before trusting a green result — a verifier that passes on
an unrewritten repository is worthless:

```bash
build/verify-secret-purge.sh /path/to/scratch/cam-backup.git /path/to/scratch/cam-backup.git
# MUST fail checks 1 and 4 and exit non-zero
```

### 6. Handle open PRs, then force-push

Merge or close the non-bot PRs; close the Dependabot ones and let them re-open themselves.

```bash
git -C /path/to/scratch/cam-rewritten.git push --force --mirror \
    git@github.com:cardtechie/cardalmanac-app.git
```

`--mirror` force-updates every ref, including deleting refs absent locally. Branch
protection on `main` must be lifted for the push and restored immediately afterwards.

### 7. Re-clone everywhere

Every existing clone now has a divergent history and must be **deleted and re-cloned** —
not pulled, not rebased. That includes the operator's working clone, every runner
workspace clone under `runner-workspaces/`, and any deploy checkout on the host.

### 8. Final gate

Re-run the working-tree scan, and scan the rewritten history independently — the verifier
proves only that the _known_ literal set is gone, and an independent scan is what catches
a secret that was never on the list:

```bash
docker run --rm -v "$PWD:/repo:ro" zricethezav/gitleaks:v8.28.0 \
    dir /repo --config /repo/.gitleaks.toml --redact --exit-code 1

docker run --rm -v "/path/to/scratch/cam-rewritten.git:/repo:ro" zricethezav/gitleaks:v8.28.0 \
    git /repo --config /repo/.gitleaks.toml --redact --exit-code 1
```

Then delete `/path/to/scratch/purge/replace-text.txt` and the backup mirror, once you are
confident the rewrite is not going to be rolled back.

## Rollback

Until the backup mirror is deleted, the rewrite is fully reversible:

```bash
git -C /path/to/scratch/cam-backup.git push --force --mirror \
    git@github.com:cardtechie/cardalmanac-app.git
```

This restores the original SHAs exactly. It also restores the secrets, so it is a recovery
step, not an undo — the reason to use it is a botched rewrite (a failed check 2 or 3 that
was force-pushed anyway), not second thoughts about the purge.

After the backup mirror is deleted, there is no rollback.

## Post-purge follow-ups

These are correct **only after** a successful purge, and must not be done before it — CI
would fail permanently on a history that has not been rewritten.

- **Flip `.github/workflows/secret-scan.yaml` from `gitleaks dir` to a history-wide scan.**
  It is deliberately working-tree-only today.
- **Correct the stale comments in `.gitleaks.toml` and `.github/workflows/secret-scan.yaml`**
  which state that #430 rules out a history rewrite. If the purge happens, that is no
  longer true, and the comments are the only place the reasoning is recorded.
- **Consider deleting `build/secret-purge-expressions.sh`, `build/verify-secret-purge.sh`,
  this document, and the `/.secret-purge/` gitignore entry.** They are single-use tooling
  for a one-time procedure. Keeping them is harmless; keeping them without this note is
  how a repository accumulates scripts nobody can date.

## Decision: go or no-go

**Not yet decided — this is the operator's call, and it is the first thing to settle.**

#430 already ruled a history rewrite out, and that ruling is encoded in comments in both
`.gitleaks.toml` and `.github/workflows/secret-scan.yaml` — it is why CI scans the working
tree only. #462 proposes the opposite. Both cannot be right.

The two options:

- **Purge.** Follow the procedure above. Costs: a full re-SHA of 723 commits, every clone
  re-cloned, open PR branches rebuilt, external SHA references broken.
- **Rotate and accept.** Rotate every value (which the gate conditions require _either
  way_), leave history intact, and accept that the historical values are dead. Close #462
  as `wontfix` and record the decision here. This is #462's own "Alternative worth
  considering," and it is what #430 already chose.

Two inputs that were not available when #462 was written both push toward the purge being
_cheaper_ than the issue assumes: there are no forks and a single collaborator, so "have
every collaborator re-clone" is one `git clone`; and most open PRs are Dependabot, which
re-opens its own.

The input that pushes the other way is that **rotation is the part that actually
neutralizes the credentials**, and rotation is required under both options. The purge buys
only the removal of the evidence — real value when the repository goes public, but strictly
less than the rotation it depends on.

Record the decision in this section when it is made, with the date and the reasoning.

## Non-secret content removed before publish (#507)

The gate conditions above ask whether history contains _secrets_. #507 asks a different
question — whether committed content is appropriate to publish at all — and this section
records its answer. It deliberately does not restate any of the removed content, because
this document will itself be published.

### `.claude/PROJECT-OVERVIEW.md`

A business planning document, not developer documentation. Deleted from `main` by #507.
`.claude/CLAUDE.md` is genuine developer documentation and stays.

**History decision: fold into the #494 rewrite.** Recorded 2026-09-28.

- A HEAD-only delete leaves the full document readable in every earlier commit, and history
  is published with the repository.
- #507 directs that the file be folded into the single planned rewrite rather than run as a
  second one. Step 4 above therefore removes the path with `--invert-paths`, and
  `build/verify-secret-purge.sh` check 4 (`removed-paths`) fails if any commit on any ref
  still touches it.
- The file has only ever existed at that one path (no renames), so a single `--path` covers
  its entire history.

**If the go/no-go above lands on "Rotate and accept"** — no rewrite — this file stays in
public history. That is a different decision from the one recorded here, and it must be
recorded in this section as an explicit acceptance, with its rationale, **before** the
repository flips public.

### Sweep for other publish-unsuitable content

Performed 2026-09-28 against `main` at the time of #507. Covered:

- every tracked Markdown file at HEAD (`.claude/`, `docs/`, `README.md`, `SECURITY.md`,
  `CHANGELOG.md`, `resources/content/blog/`) and `docs/gtm/`;
- code comments under `app/`, `resources/`, `routes/`, `config/`, and `.github/`;
- files that exist only in history (`git log --all --diff-filter=D`).

Searched for strategy and exit notes, revenue, pricing and investment figures, competitor
commentary, internal self-assessments, confidentiality markers, and customer names.

**Result: nothing else found.** The only hits were card-manufacturer names in public set
data (`public/sitemap.xml`, test fixtures), which are product data, not commentary. The
history-only files are the self-signed dev TLS keys under `.docker/` (a credential
question, owned by #425 per the scope table above — not a publish-suitability one) and a
routine CI troubleshooting note (`.github/BUILD-STATUS.md`).
