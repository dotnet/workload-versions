---
name: vs-workloads-monitor-build
description: Tracks independent workload build, insertion and publication stages, locates new or cumulative VS PRs, and verifies warnings against actual target state.
---

# Monitor Workloads Builds and Insertions

## Inputs

- **buildIds**: all contributing dnceng runs.
- **releaseMatrix**: approved source SHAs, expected versions, workload subsets,
  publication destinations and primary/secondary VS targets.

Discover installed dnceng and DevDiv Azure DevOps read operations/schemas.
Inspect run resources, parameters, timeline, stage attempts and relevant logs;
do not rely only on the top-level build result.

## Monitor Stages

1. Verify resolved pipeline (`eng`) and `source` SHAs against the recorded plan.
   Check generated versions and package identities against effective branding.
2. Track Build, Insertion and Publish independently. Insertion and Publish both
   depend on Build; they do not run in a required serial order.
3. Report pending environment approvals separately from failed tasks. Publish's
   `DotNet-SDK-Workloads` approval/check can block both AzDO and NuGet tasks.
   A failed overall run can already have created valid VS PRs.
4. Inspect the first failing task and all attempts. Missing artifacts or SBOM
   errors after an earlier dependency download failure may be secondary.
5. Poll at reasonable intervals (for example 10-15 minutes), reporting meaningful
   changes. Do not promise a fixed end-to-end duration; approvals can take much
   longer than the actual build/publication work.

## Locate New or Existing VS PRs

Use insertion logs for PR links and actual topic/target branches. Query active
**and completed** PRs in the DevDiv VS repository:
`a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`.

`MicroBuildInsertionVS` has identity
`558012ed-704d-617d-868c-985c8dbc9b16`; use it as corroboration, not the sole
matching criterion.

The default topic branch is
`temp/DotNet-Cli/<target>/yyyy-MM`, and topic-branch updates are enabled.
Different builds and .NET versions can contribute to the same PR. A title or
original build link can remain unchanged after later updates.

Match the target, actual topic branch, latest iteration/commits and drop URLs
to all contributing builds. If `createVSInsertion=false`, report insertion as
not requested even if old target/drop parameters are still present in the run.

## Interpret Existing-PR and No-Change Messages

For `TF401179`, an active-PR warning, or "No changes detected":

- Locate the current PR or completed insertion and inspect its actual contents.
- Check whether the required contribution reached the topic branch, PR or
  target. Do not assume a warning means a successful update.
- Reconcile all contributions and intended versions with the approved matrix.
  Preserve legitimate entries from other approved builds.
- Report an unresolved or missing update as blocked. Do not queue an entire
  duplicate run just to suppress the warning or make checks green.

If recovery is needed, report existing side effects and identify the specific
failed stage/check. Retry only the appropriate failed work when supported and
authorized. Changed dependencies/branding can require a new run; record its
relationship to the old one.

## Validate and Hand Off

Use `vs-workloads-approve-pr` for semantic validation. Primary means packs and
(pre)components; secondary means packs only. Count expected entries, not files:
multiple workloads/versions can share one JSON file.

Report one row per run/stage and one per target PR, including:

| Run / target | Source SHA / PR iteration | Expected contribution | Observed state | Link / blocker |
|--------------|---------------------------|-----------------------|----------------|----------------|
| `<run or target>` | `<SHA or iteration>` | `<workloads, role, version>` | `<verified/waiting/failed/unverified>` | `<link>` |

Include publication task/destination results independently of VS state.
Report the PR's actual autocomplete state and responsible human reviewer.
Do not approve, enable autocomplete or merge.
