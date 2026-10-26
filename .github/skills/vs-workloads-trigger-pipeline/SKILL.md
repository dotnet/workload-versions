---
name: vs-workloads-trigger-pipeline
description: Queues workload VS insertions using an approved source, branding, selected workload subset and primary/secondary target matrix, including internal-only hotfixes.
---

# Trigger a VS Workloads Insertion

Use [Release Process](../../../doc/release-process.md) and
`workload-release-day` for the release matrix. NuGet publication is a separate
choice, not implied by VS insertion.

## Required Inputs

- **sourceMode**, **sourceBranch**, **expectedCommit**: verified by
  `vs-workloads-check-mirror`.
- **branding**: target SDK, expected workload-set version/pattern, explicit
  SDK minor/feature/patch, effective prerelease label/iteration and stabilize flag.
- **workloadDropNames**: exact approved subset of `emsdk`, `mono`, `iOS`,
  `android`, `maui`. Do not silently expand a hotfix to all workloads.
- **primaryVsInsertionBranches**: packs and (pre)components.
- **secondaryVsInsertionBranches**: packs only; no (pre)components.
- **publication**: explicit AzDO feed/flag, NuGet flag and test-mode flag.

Both branch lists must be explicit; either can be empty. Confirm actual VS
branches, not guessed monthly/staging names. Prevent contradictory primary and
secondary roles for the same target in one row.

## Preflight and Confirmation

Verify the final source SHA and dependency/feed/BAR coherency. Confirm the full
matrix with the owner before queuing, including version overrides and every
target's role. Default validation/insertion plans to no NuGet publication unless
the approved matrix explicitly requests it.

The current pipeline template sets `InsertAutoComplete: true`. Surface that
fact before queuing and identify the responsible human reviewer. This workflow
does not approve or merge VS PRs; enforcing manual-only completion requires a
separate pipeline/policy change, not an invented run parameter.

## Queue

Discover the current dnceng run operation/schema (currently `pipelines_write`
with action `run_pipeline`), or use the equivalent Azure DevOps API.
Use project `internal`, pipeline ID `1298`. Example request body for an approved
mono/emsdk servicing-validation insertion:

```json
{
  "resources": {
    "pipelines": {},
    "repositories": {
      "self": {"refName": "refs/heads/eng"},
      "source": {
        "refName": "refs/heads/<approved-source-branch>",
        "version": "<approved-source-sha>"
      }
    }
  },
  "templateParameters": {
    "sourceBranch": "<approved-source-branch>",
    "setVersionSdkMinor": "1",
    "setVersionFeature": "14",
    "setVersionPatch": "0",
    "setPreReleaseVersionLabel": "servicing",
    "setPreReleaseVersionIteration": "0",
    "stabilizePackageVersion": false,
    "createTestWorkloadSet": false,
    "publishToAzDO": true,
    "azDOPublishFeed": "public/dotnet-workloads",
    "publishToNuGet": false,
    "createVSInsertion": true,
    "workloadDropNames": "- emsdk\n- mono",
    "primaryVsInsertionBranches": "- <approved-primary-target>",
    "secondaryVsInsertionBranches": "[]"
  }
}
```

Replace all example values with the confirmed matrix. Pin the source repository
version when supported; verify the returned run's resolved `source` SHA in all
cases. If the API cannot pin it, recheck the branch before queuing and treat any
resolved-SHA mismatch as a blocker to accepting the run.

The pipeline implementation must use `refs/heads/eng`; `sourceBranch` does not
select the pipeline implementation. Branch/drop object parameters may need YAML
list strings with `- ` prefixes and newline separators for the selected tool.
Use `[]` for empty lists and follow the discovered API schema.

## Output

Report run ID/link, pipeline/source resource SHAs, complete effective parameters,
expected version and per-target workload/role matrix. Pass them to
`vs-workloads-monitor-build`. Do not promise fixed build duration or queue
duplicate builds to work around existing insertion PRs.
