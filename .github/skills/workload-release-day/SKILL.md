---
name: workload-release-day
description: Prepares, builds and publishes monthly or hotfix workload sets using an approved release matrix, including internal-only sources.
---

# Workload Set Release Day

Follow the [Release Process](../../../doc/release-process.md).
Discover current tool schemas before making GitHub/Azure DevOps calls.

## 1. Confirm the plan

Complete the runbook's release matrix, with one row per SDK-band output and phase.

- **Monthly:** use `dotnet-release-tracker` for the intended date and approved
  staged SDK builds. Derive the shipping bands; do not assume five runs.
- **Hotfix:** the release owner's approved matrix overrides monthly tracker
  inference. Distinguish workload-only revisions (`10.0.402.1`) from new
  SDK-hotfix outputs (`10.0.114`, `10.0.403`). Public release metadata cannot
  establish an unpublished hotfix's versions.

Confirm source repository/mode, branch/SHA, upstream builds, expected package
version/identity, branding, validation/final phase, test mode, publication
destinations and VS scope. Ask for missing values; do not apply monthly defaults
to a hotfix. Obtain user confirmation before queuing.

## 2. Prepare and check the source

Use `vs-workloads-check-mirror` to prepare or consume the approved public or
internal-only branch. It uses `workload-versions-check` to validate dependencies,
feeds and upstream builds at the final SHA. Several output rows can share that
source without changing dependencies.

## 3. Confirm branding

Use the runbook's version examples. Set SDK minor, two-digit feature and patch
explicitly; verify inherited major/minor matches the target.

- `setVersionPatch` is a workload-set revision, not the runtime patch.
- For prerelease output, explicitly set label/iteration. RC3 requires `rc` / `3`
  and `stabilizePackageVersion=false`, even for final NuGet publication.
- For servicing validation, use label `servicing` and confirm the iteration.
- `createTestWorkloadSet` changes test-version identity; it is not required for
  ordinary release-candidate validation.

## Queue Pipeline 1298

Use project `internal` in dnceng, pipeline `1298`, with the current run operation
(currently `pipelines_write`, action `run_pipeline`) or equivalent API.
This request illustrates **validation only**; replace values from the confirmed
matrix:

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
    "createVSInsertion": false
  }
}
```

`eng` selects the implementation; `sourceBranch` selects release dependencies.
Pin the approved source SHA when supported. Otherwise recheck the branch before
queuing. Record both resolved resource SHAs and block acceptance/publication if
`source` differs from the approved SHA.

For final publication, apply the confirmed branding and publishing flags;
normally leave VS insertion and test mode disabled. For VS rows, use
`vs-workloads-trigger-pipeline` with the same plan.

## 4. Validate and report

Use `vs-workloads-monitor-build` for stage results and insertion PR discovery.
Before publication signoff, check generated identities/versions and follow
[Test Workload Updates](../../../doc/test-workload-updates.md) for each SDK band.
Verify publishing tasks and exact package availability in every requested
destination, including referenced upstream packages.

For VS rows, use `vs-workloads-approve-pr` for human handoff; do not approve,
enable autocomplete or merge. Report each output's run link, source SHA,
generated version, validation, publication results and VS PR state. Mark waiting,
failed or unverified work explicitly.
