---
name: vs-workloads-approve-pr
description: Validates VS insertion PR contents and reports readiness for human approval and merge. Despite the legacy skill name, never approves, enables autocomplete or merges.
---

# Validate VS Insertion PRs for Human Handoff

This is a read-only validation skill. A person approves and merges the PR.
Do not submit a reviewer vote, enable autocomplete or complete the PR.

## Inputs

- **prId**: DevDiv VS PR.
- **releaseMatrix**: expected workloads, versions, drop URLs, targets and roles.
- **contributingBuilds**: all contributing runs and their resolved source SHAs.

Discover the installed DevDiv PR/iteration/file/status/policy read schemas.
Use VS repository `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`,
project `DevDiv` (`0bdbc590-a062-4c3f-b0f6-9383f67865ee`).

## Validate Identity and Current State

1. Read PR details, target/topic branches, status, latest iteration and commits.
   Use symbolic status meanings from the current API, not guessed numeric enums.
2. Corroborate the insertion author, originating build and subsequent topic
   updates. An original title/build link does not identify every contribution.
3. Inspect the latest diff and relevant target/current JSON contents. Include
   completed PRs when a build reused a topic branch or reported no changes.
4. Check policies, required validation results, conflicts and reviewer state.
   Missing validation is unverified, not a pass.

## Validate Semantic Contributions

For every approved contributing build and target:

- Match selected workload and .NET-version entries to the intended drop URLs
  and versions, including prerelease labels/iterations.
- Require packs and (pre)components for primary targets; require packs only
  from secondary contributions. Existing component entries from other approved
  primary contributions are not automatically unexpected.
- Confirm unaffected entries remain intact and flag changes outside the
  accumulated approved release matrix.
- Validate actual JSON entries rather than a fixed changed-file count.
  Multiple workloads and versions can live in one components JSON file.
- Confirm provenance back to the exact build/source SHA, not today's branch tip.

Do not reject a cumulative PR merely because it contains several .NET versions.
If the expected contribution cannot be established, report the specific gap
instead of approving or requeuing the pipeline.

## Autocomplete Caveat

The current pipeline's insertion template sets `InsertAutoComplete: true`.
Inspect and report the actual PR setting. This skill's human handoff does not
disable that pipeline behavior. If manual-only completion is required, report
the risk to the responsible person before they proceed; a pipeline/policy
change is separate work. Do not silently change PR settings or promise that
automation cannot complete it.

## Output

| PR / target | Latest iteration | Builds / contributions | Checks and content | Autocomplete | Handoff |
|-------------|------------------|------------------------|--------------------|--------------|---------|
| `<id / branch>` | `<iteration>` | `<all verified runs>` | `<ready/blocked/unverified>` | `<actual state>` | `<human owner>` |

Link: `https://dev.azure.com/devdiv/DevDiv/_git/VS/pullrequest/<prId>`.

Report validation readiness, not merge completion. If already completed,
report observed completion and whether the required contribution is present.
If the PR changes after validation, invalidate the stale result and inspect
the new iteration before reporting readiness again.
