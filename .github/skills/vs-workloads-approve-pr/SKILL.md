---
name: vs-workloads-approve-pr
description: Validates VS insertion PRs for human approval and merge. Read-only despite the legacy skill name.
---

# Validate VS Insertion PRs

A person approves and merges. Do not vote, enable autocomplete, change PR
settings or complete the PR.

## Inputs

PR ID, approved workload/version/target-role matrix, and contributing runs with
their source SHAs.

Use DevDiv's VS repository: `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`.

## Validate

1. Read the target/topic branches, status, latest iteration/commits and diff.
   Include completed PRs when investigating reused topics or no-change messages.
2. Trace all contributions to their runs/source SHAs; the original build link
   may not describe later updates.
3. Check each selected workload/version entry and drop URL, including prerelease
   branding. Primary contributions require packs and (pre)components;
   secondary contributions require packs only.
4. Preserve entries from other approved builds and unaffected content. Flag
   changes outside the combined approved matrix, not simply multiple .NET
   versions in one PR. Count **JSON entries, not changed files**.
5. Check policies, validation results, conflicts and reviewer state. Report
   missing evidence as unverified, not passed.

The pipeline sets `InsertAutoComplete: true`. Report the actual PR setting to
the responsible person; human handoff does not disable it. Manual-only
enforcement needs a separate pipeline/policy change.

## Report

Include PR link/target, latest iteration, verified builds/contributions, checks,
blockers, autocomplete state and human owner. State `ready`, `blocked` or
`unverified`, not merged unless completion was observed.

Link: `https://dev.azure.com/devdiv/DevDiv/_git/VS/pullrequest/<prId>`.

If already completed, verify the required update is present. If the iteration
changes after validation, revalidate before reporting readiness again.
