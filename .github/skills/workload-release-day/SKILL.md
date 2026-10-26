---
name: workload-release-day
description: Prepares, builds, validates and publishes workload sets for monthly releases and out-of-band hotfixes. Supports public or internal-only sources and owner-approved release matrices.
---

# Workload Set Release Day

Follow the [Release Process](../../../doc/release-process.md) as the authoritative
runbook. Do not queue builds or approve publication until the user has confirmed
the effective settings.

## Select the Release Mode

- **Monthly**: use the `dotnet-release-tracker` skill for the intended release
  date and approved staged SDK builds. Derive every shipping band; do not
  hardcode a five-run plan or assume the date is next week's Patch Tuesday.
- **Workload-only OOB**: use a release-owner-approved matrix for a revision on an
  existing SDK-aligned set, such as `10.0.402.1`.
- **SDK hotfix**: use a release-owner-approved matrix for new SDK-aligned outputs,
  such as `10.0.114` and `10.0.403`, possibly from one internal-only source.

For either hotfix mode, the approved matrix takes precedence over tracker
inference. Never infer new hotfix versions by incrementing the latest public
release. Public `dotnet/core` release metadata can corroborate published
versions, but is not authority for an unpublished hotfix. Stop for owner input
if the intended release or approved build is unclear.

## Required Matrix

Record a separate row for every SDK-band output and phase:

| Field | Required value |
|-------|----------------|
| Release | Mode, date, approving owner |
| Source | Public mirror or internal-only repository, branch, baseline SHA if creating a branch, approved final SHA, upstream build IDs |
| Output | Target SDK, expected workload-set version/pattern and package identity |
| Branding | SDK minor, two-digit feature, patch, effective prerelease label/iteration, stabilize flag |
| Phase | Validation or final publication; test-mode flag |
| Publication | AzDO enabled/feed, NuGet enabled |
| VS | Insertion enabled, exact workload subset, primary and secondary targets |

Final publication normally has `createVSInsertion=false` and
`createTestWorkloadSet=false`. An insertion/validation phase is a separate row
with independently approved settings; never inherit publication or VS targets
from another row.

## Prepare the Source

Use `vs-workloads-check-mirror` to prepare/consume the approved public or
internal-only branch, review dependency changes, and verify its final SHA.
Use `workload-versions-check` at that SHA to report dependency versions, IDs,
upstream provenance and feeds. Do not require a GitHub PR/mirror for an
internal-only source or automatically merge unapproved dependency changes.

Validate the resulting runtime/mono and emsdk versions where they share a
servicing line, while allowing approved same-version SHA-only rebuilds.
Preserve unaffected workloads in a targeted hotfix.

## Derive and Confirm Effective Branding

Always set `setVersionSdkMinor`, `setVersionFeature` and `setVersionPatch`
explicitly. Branch branding can be stale.

For SDK `X.Y.CFP`, SDK minor is the hundreds digit `C`, and feature is the
two-digit remainder `FP`. Verify the source's inherited major/minor matches the
target; these three overrides do not change it.

| Expected output | SDK minor | Feature | Patch | Stabilize | Label / iteration |
|-----------------|-----------|---------|-------|-----------|-------------------|
| `10.0.402.1` | `4` | `02` | `1` | `true` | Review inherited values; stable output |
| `10.0.114` | `1` | `14` | `0` | `true` | Review inherited values; stable output |
| `10.0.403` | `4` | `03` | `0` | `true` | Review inherited values; stable output |
| `11.0.100-rc.3.<build>` | `1` | `00` | `0` | `false` | `rc` / `3` |

`setVersionPatch` is the workload-set revision, **not** the runtime patch.
Stable nonzero patches append a fourth component. Preview/RC output must retain
prerelease branding even for final NuGet publication. Set label and iteration
explicitly for prerelease rows; changing manifest IDs does not change branding.
For servicing validation, use label `servicing` and verify the effective
iteration. `createTestWorkloadSet` changes test-version identity; it is not
required to validate an ordinary release candidate.

Present the complete matrix, including effective branding, sources and targets,
and obtain confirmation before queuing. Missing approval or ambiguous values
are blockers, not reasons to apply monthly defaults.

## Queue Pipeline 1298

Discover the installed Azure DevOps tools and their current schemas rather than
assuming operation aliases. Use the dnceng pipeline-run operation (currently
`pipelines_write`, action `run_pipeline`) or the equivalent Azure DevOps API.

The pipeline implementation is `eng`; `sourceBranch` is a separate resource.
Pin the approved source version when the run API supports it. Example request
body for a **validation-only** SDK hotfix:

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

Use only values from the confirmed matrix, not literal placeholder strings.
For a confirmed stable final-publication row, use stable branding and the
approved publishing flags. For a VS insertion row, delegate to
`vs-workloads-trigger-pipeline` with the same source/branding matrix.
After queuing, verify both resolved repository SHAs, especially `source`.
If it differs from the approved SHA, stop acceptance/publication and report it.

## Monitor, Validate and Report

- Record each run ID, link, effective parameters and both resource SHAs.
- Monitor Build, Insertion and Publish independently. The latter two depend on
  Build, not each other. Report approval waits separately from task failures;
  do not promise a fixed completion time or assume overall failure means no PR.
- Verify generated versions, package identities, workload manifests and approved
  dependency provenance before publication signoff.
- Follow [Test Workload Updates](../../../doc/test-workload-updates.md) for
  installation validation in an isolated environment for each shipping SDK band.
- Inspect requested publication tasks and verify exact package versions are
  available in the approved AzDO feed and/or NuGet.org. Workload-set publication
  does not establish availability of every referenced upstream package.
- For VS rows, use `vs-workloads-monitor-build` and `vs-workloads-approve-pr` to
  validate cumulative PR contents and hand off to a person. Do not approve,
  enable autocomplete, or merge VS PRs.

Report one row per matrix output with run link, source SHA, generated version,
validation result, each publication destination's result, and VS PR state.
Explicitly distinguish unverified, waiting, failed, partial and completed work.
Never requeue a whole pipeline solely to make a warning or PR check green.
