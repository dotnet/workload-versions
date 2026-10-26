# Release Process Documentation

Based on https://github.com/dotnet/sdk/issues/41607

## Current Process

Use this runbook for monthly and out-of-band (OOB/hotfix) releases.
The [Ideal Process](#ideal-process) below is a future goal, not current behavior.

### 1. Agree on the release matrix

For monthly releases, get the shipping SDKs and approved builds from the release
tracker for the intended date. Check build history if the latest staging is not
the approved build.

For hotfixes, use the **release owner's approved matrix**, even if it differs
from the monthly tracker. Record one row per output and phase:

| Setting | Required information |
|---------|----------------------|
| Release | Date, owner, monthly/workload-only OOB/SDK-hotfix mode |
| Source | Repository, branch, final SHA, dependency PRs and upstream builds; baseline SHA if creating a branch |
| Version | Target SDK, expected workload-set version/pattern and branding overrides |
| Publication | Validation or final release, stabilize/test-mode flags, AzDO feed and NuGet flags |
| VS insertion | Enabled or disabled, selected workloads, primary and secondary target branches |

One source branch can produce several SDK-band outputs. Give each its own row
and version overrides; they can share the same dependencies.

### 2. Prepare and verify the source

The build consumes `dnceng/internal`'s `dotnet-workload-versions` repository.
Prepare the source through the appropriate review path:

| Source | Steps |
|--------|-------|
| Public | Review/merge the GitHub dependency PR, then verify that commit has mirrored internally. |
| Internal-only hotfix | Create the branch from the approved baseline SHA, update from the approved upstream build, and review/merge an Azure DevOps PR. No GitHub branch or mirror wait is needed. |

At the final approved SHA, check:

- `eng/Version.Details.xml`: dependency names, versions, upstream URI, SHA and
  explicit `BarId` where needed.
- `eng/Versions.props`: matching dependency version properties and manifest IDs.
- `NuGet.config`: feeds for the selected upstream builds, including internal
  sources when applicable.
- Runtime/mono and emsdk versions must match where they share a servicing line.
  A same-version runtime rebuild can change its SHA/feed and SDK provenance
  without changing emsdk.

Preserve unaffected workloads. A mono/emsdk RC3 hotfix can retain mobile/MAUI
RC2 IDs; see [Preview Branch Preparation](preview-branch-preparation.md).

### 3. Set and review effective branding

Branding in `eng/Versions.props` can be stale. Set
`setVersionSdkMinor`, `setVersionFeature` and `setVersionPatch` explicitly, and
confirm the prerelease label/iteration before queuing.

For SDK version `X.Y.CFP`, the override values are `C` (hundreds digit) and `FP`
(two-digit remainder). `setVersionPatch` is a workload-set revision, **not** the
runtime servicing patch.

| Scenario | Target example | SDK minor | Feature | Patch | Stabilize |
|----------|----------------|-----------|---------|-------|-----------|
| Workload-only OOB on an existing SDK | `10.0.402.1` | `4` | `02` | `1` | `true` |
| New SDK hotfix, first band | `10.0.114` | `1` | `14` | `0` | `true` |
| Same source, another SDK band | `10.0.403` | `4` | `03` | `0` | `true` |
| RC hotfix | `11.0.100-rc.3.<build>` | `1` | `00` | `0` | `false` |

For RC3, also set `setPreReleaseVersionLabel=rc` and
`setPreReleaseVersionIteration=3`; changing dependency IDs does not update
branding. Stable nonzero patches append a fourth component; prerelease outputs
retain build-derived suffixes. Verify the generated version and package identity
against the matrix before publication.

### 4. Queue the appropriate phase

Use [official pipeline 1298](https://dev.azure.com/dnceng/internal/_build?definitionId=1298).
Select **pipeline version by branch/tag = `eng`**. Separately set **Source branch**
(`sourceBranch`) to the prepared branch name, without `refs/heads/`.
`eng` supplies the build implementation; `source` supplies release dependencies.
Merging a PR does not queue this manual pipeline.

Confirm these settings against the matrix:

| Parameter | Selection |
|-----------|-----------|
| `stabilizePackageVersion` | `true` for stable output; `false` for servicing validation or preview/RC output, including final RC publication. |
| `publishToAzDO`, `azDOPublishFeed` | Approved feed; current default is `public/dotnet-workloads`. |
| `publishToNuGet` | Enable only for approved final publication. |
| `createVSInsertion` | Enable only for the approved VS phase. |
| `createTestWorkloadSet` | Enable only for special test-version identity, not ordinary servicing/RC validation. |

Validation can use AzDO without NuGet, or unpublished stable artifacts.
Record both resolved resource SHAs and verify `source` matches the approved
commit before accepting the run's outputs.

### 5. Validate workload installation and VS insertions

Follow [Test Workload Updates](test-workload-updates.md) in an isolated environment
for every shipping SDK band. Use the generated version and approved feeds or
downloaded artifacts, including sources for unreleased dependencies.

For VS insertion, select only the required `workloadDropNames` (`emsdk`, `mono`,
`iOS`, `android`, `maui`; casing matters). Primary targets receive packs and
(pre)components; secondary targets receive **packs only**. Empty primary or
secondary lists are valid. When `createVSInsertion=false`, these lists are inactive.

Validate JSON entries and drop URLs, not changed-file counts. Shared topic
branches can combine several builds/.NET versions in one PR. Check the latest
iteration, target and all contributions; search active and completed PRs for
existing-PR/no-change messages.

Automation reports readiness; a person approves and merges. The pipeline still
sets `InsertAutoComplete: true`: report the actual PR setting to that person.
Enforcing manual-only completion needs a separate pipeline/policy change.

### 6. Monitor and approve publication

Insertion and Publish each depend on Build, not each other. A Publish failure
does not imply a failed insertion. AzDO and NuGet tasks share the Publish
deployment and its `DotNet-SDK-Workloads` approval.

Report stage/task results and waiting approvals separately; waits can dominate
elapsed time. Approve publication after required validation and owner signoff.
Verify exact package identities/versions in each destination and availability of
referenced upstream packages. Record VS PR status separately.

### Troubleshooting and recovery

- **Ambiguous BAR lookup:** confirm the intended build and add its `BarId` in
  `eng/Version.Details.xml` through a reviewed update. Even a narrow insertion
  can fail while resolving another dependency.
- **Existing PR / no changes:** verify the required update in the PR or target;
  do not queue duplicates just to obtain a new PR or clear a warning.
- **Partial/failed run:** inspect the first failure, attempts and existing
  artifacts/PRs. Retry only failed work where supported. Changed source or
  branding may need a new run; link it to the superseded run.

## Ideal Process

> [!NOTE]
> This process may vary based on the workload owners.

> [!NOTE]
> Most of this process today is done through disparate builds in each workload repo and this repo (or manually). Below is outlining our desired goal.

1. **Publishing Release-Ready Versions**
    - Each workload owner publishes release-ready versions to the `dotnet8-workloads` and `dotnet9-workloads` channels.

2. **Creating Workload Set Repo PRs**
    - Workload set repository pull requests (PRs) are created based on the release channel.

3. **Review and Merge PRs**
    - A person reviews the PR, approves it, merges it, and a build is triggered automatically.

4. **Build Process**
    - There are a few phases to the build process:
        1. Create a stable and unstable version of the workload set (a stable version is only needed in servicing).
            - 9.0.102-servicing.12345.6
            - 9.0.102
        2. Publish the unstable version to the workloads feed.
        3. The process is different depending on if we're in servicing/golive.
            1. If we're **not** in servicing/golive:
                - Publish runtime, emsdk, and maui to the workloads feed.
            2. If we're in servicing/golive:
                - Only publish maui and the unstable workload set to the workloads feed.
                - Additionally, create a stable workloads feed and publish the runtime, emsdk, maui, and stable workload to that feed.
                  - To enable this step, the .NET staging pipeline will have to be modified to publish the runtime and emsdk builds to the appropriate workloads channels. Today, that publishing is done in the runtime public build.
        4. Create a vsdrop for each workload.

5. **Creating a VS PR**
    - Creates a Visual Studio (VS) PR with the workloads JSON file updated.

6. **Testing and Merging**
    - Test the VS PR, sign off, and merge the workload set and all workloads together.

7. **Publish to nuget.org** (on release day)
    - Publish packs for all workloads
    - Query nuget.org until the packs are available
    - Publish manifests for all workloads
    - Query nuget.org until the manifests are available
    - Publish the workload set

## Additional Details for the Ideal Process

### Approvals

In the above steps, step 3 will require approval in GitHub. Additionally, steps 4.b, 4.c, 5, and 7 should each require approval in the workload staging pipeline (specifically any step that does publishing to feeds, NuGet, or VS should require an approval within the pipeline). The reason for this is so we can have the pipeline run automatically on all PRs but only publish the changes we want to. Workload partners may have changes they want to publish internally for testing but not go to NuGet or VS, teams may have changes they want to publish on NuGet.org but not publish to VS, etc.

Basically, everything should happen automatically once merged but we want to control whether we publish the workloads to the feeds, to VS, and to nuget.org so we don't publish by default.

### Legacy version-specific preview feeds

These feeds appear in older workflows. For current official publication, use
the approved destination described in [Current Process](#current-process);
do not infer a feed solely from the .NET major version.
- dotnet8-workloads https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet8-workloads/nuget/v3/index.json
- dotnet9-workloads https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet9-workloads/nuget/v3/index.json
