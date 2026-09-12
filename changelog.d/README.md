# Changelog fragments

This directory holds **per-PR changelog fragments**. Each PR that changes
user-facing behavior drops one small file here instead of editing the shared
`## [Unreleased]` section of `../CHANGELOG.md` directly.

## Why

When every open PR appends to the same `## [Unreleased]` block in
`CHANGELOG.md`, each merge to `develop` re-conflicts every other open PR's
changelog — an N² re-conflict storm that deadlocks the board. Fragments are
written to unique per-PR paths, so concurrent PRs never touch the same file and
never conflict. The fragments are collated into `CHANGELOG.md` once, at release
time, and then deleted.

## File naming

```text
changelog.d/<issue>-<type>.md
```

- `<issue>` — the GitHub issue number the change closes (e.g. `391`).
- `<type>` — one of: `added`, `changed`, `deprecated`, `removed`, `fixed`,
  `security` (lower-case, canonical Keep a Changelog order — the same order
  `build/collate-changelog.sh` uses). This selects which `### <Type>`
  subsection the fragment is collated under.

Each PR writes a unique new path, so this is genuinely zero-conflict.

## Fragment format

A fragment body is the single
[Keep a Changelog](https://keepachangelog.com/en/1.0.0/) list line that would
otherwise have gone under the matching `### <Type>` heading, optionally followed
by at most one indented caveat sub-bullet:

```markdown
- **[Issue #391]** Adopt `changelog.d/` fragments and collate them into `CHANGELOG.md` at release time so concurrent PRs stop conflicting on the shared `## [Unreleased]` section.
    - Non-trivial PRs must now add a `changelog.d/<issue>-<type>.md` fragment or carry the `skip-changelog` label.
```

Do **not** put a top-level heading in a fragment — the `### <Type>` heading is
derived from the filename at collation time.

## CI gate

The `Changelog Fragment` workflow (`../.github/workflows/changelog-fragment.yaml`)
fails any pull request that adds no `changelog.d/*.md` fragment (the README and
`.gitkeep` placeholder do not count). This keeps the convention honest: a
non-trivial change cannot merge without recording its changelog line.

To opt a trivial / no-user-facing PR out of the gate, add the `skip-changelog`
label to the PR. The check re-runs on label add/remove, so the gate clears as
soon as the label is applied.

Dependabot PRs carry no fragment, so they need the `skip-changelog` label; the
gate deliberately has no bot carve-out so it stays byte-comparable with the
sibling `cardtechie` repos.

## Formatting

This repo's `Build and Test` workflow runs `npm test`, whose `pretest` hook runs
`prettier --check .` over the whole tree — fragments included. Write fragments in
Prettier's markdown style (`-   ` list marker, four-space sub-bullet indent, as
shown above), or run `npm run format` before committing.

## Release-time collation

At release, `build/collate-changelog.sh` folds every `changelog.d/*.md`
fragment into the `## [Unreleased]` section of `CHANGELOG.md` — grouped under
the matching `### Added` / `### Changed` / `### Deprecated` / `### Removed` /
`### Fixed` / `### Security` heading (merging into an existing same-type
subsection rather than duplicating headings) — then `git rm`s the consumed
fragments. It is a clean no-op when `changelog.d/` holds no fragments. The
script runs ahead of `build/update-changelog.sh` in the `changelog-update` and
`release-prepare` makefile targets so the fragments are folded into
`## [Unreleased]` before the version cut runs. `make changelog-preview` runs the
collation in non-destructive `--preview` mode so you can see the assembled
`[Unreleased]` section without mutating any file.

> **Note:** the version cut is `build/update-changelog.sh`. Both of its actions
> insert the new `## [<version>] - <date>` heading immediately below
> `## [Unreleased]`, so the content collated here becomes the body of the new
> version section and `[Unreleased]` is left empty for the next cycle.
>
> - `finalize` (used by `release-prepare`) relocates the collated content
>   only.
> - `update` (used by `changelog-update`) additionally generates bullets from
>   commit messages and inserts them above the collated content, so that path
>   concatenates both sources under the version heading.
>
> De-duplicating commit-derived bullets against fragment-derived ones is tracked
> centrally in the Release workflow milestone.
