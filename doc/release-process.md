# Release Process Documentation

Based on https://github.com/dotnet/sdk/issues/41607

## Current Process

This is the operational runbook for monthly releases and out-of-band (OOB/hotfix)
releases. The [Ideal Process](#ideal-process) below describes future goals, not
the behavior of the current pipeline.

### 1. Agree on the release matrix

For monthly releases, use the release tracker for the intended release date to
identify every shipping SDK band and its approved staged build. Inspect the
tracker's build history when the latest staging is not the approved build.

For hotfixes, obtain an explicit matrix approved by the release owner. That
matrix takes precedence over a next-Patch-Tuesday lookup. Do not infer the set
of bands, source branches, or versions from the normal monthly release.

Record one row per output and phase, including:

| Setting | Required information |
|---------|----------------------|
| Release | Date, owner, monthly/workload-only OOB/SDK-hotfix mode |
| Source | Repository, branch, approved baseline and final commit SHA, dependency PRs and upstream builds |
| Version | Target SDK, exact expected workload-set version/pattern, all effective branding values |
| Publication | Validation or final release, stabilize flag, AzDO feed and NuGet flags |
| VS insertion | Enabled or disabled, selected workloads, primary and secondary target branches |

One source branch can produce multiple SDK-band outputs. Keep a separate row
and explicit version overrides for each; do not change dependencies merely
because two outputs have different workload-set versions.

### 2. Prepare and verify the source

For public changes, create/review the dependency PR on GitHub, merge through the
normal review process, and verify the expected commit has mirrored to
`dnceng/internal`'s `dotnet-workload-versions` repository.

Hotfixes can instead use an internal-only branch. Create it in that repository
from the release owner's approved baseline commit, update dependencies from the
approved upstream build, and create/review/merge the internal Azure DevOps PR.
Verify the resulting internal source commit directly. Such a branch does not
need a GitHub counterpart or a GitHub mirror wait.

At the final source commit, check these together:

- `eng/Version.Details.xml`: dependency names, versions, upstream URI, SHA and
  explicit `BarId` where needed.
- `eng/Versions.props`: matching dependency version properties and manifest IDs.
- `NuGet.config`: feeds for the selected upstream builds, including internal
  sources when applicable.
- Runtime/mono and emsdk coherency: where they share a servicing version line,
  require matching versions in the resulting source. A same-version rebuild can
  legitimately change only the runtime SHA/feed and SDK provenance; it does not
  require an artificial emsdk version change.

Do not globally advance manifest IDs for a targeted hotfix. For example,
mono/emsdk can move to RC3 while unaffected Android, Apple and MAUI manifests
remain RC2. See [Preview Branch Preparation](preview-branch-preparation.md).

### 3. Set and review effective branding

Source branding in `eng/Versions.props` can lag the intended output. Always set
`setVersionSdkMinor`, `setVersionFeature` and `setVersionPatch` explicitly, and
review the effective prerelease label/iteration before queuing.

For SDK version `X.Y.CFP`, the override values are `C` (hundreds digit) and `FP`
(two-digit remainder). `setVersionPatch` is a workload-set revision, **not** the
runtime servicing patch.

| Scenario | Target example | SDK minor | Feature | Patch | Stabilize |
|----------|----------------|-----------|---------|-------|-----------|
| Workload-only OOB on an existing SDK | `10.0.402.1` | `4` | `02` | `1` | `true` |
| New SDK hotfix, first band | `10.0.114` | `1` | `14` | `0` | `true` |
| Same source, another SDK band | `10.0.403` | `4` | `03` | `0` | `true` |
| RC hotfix | `11.0.100-rc.3.<build>` | `1` | `00` | `0` | `false` |

For the RC example, also set `setPreReleaseVersionLabel=rc` and
`setPreReleaseVersionIteration=3`. Updating dependency IDs to RC3 does not update
workload-set branding automatically.

Use the approved exact version matrix rather than an automatic patch increment.
Stable outputs with nonzero patch append the fourth component; prerelease
outputs retain build-derived suffixes. Verify the generated version and package
identity from the build artifacts before publication.

### 4. Queue the appropriate phase

Use [official pipeline 1298](https://dev.azure.com/dnceng/internal/_build?definitionId=1298).
Select **pipeline version by branch/tag = `eng`**. Separately set **Source branch**
(`sourceBranch`) to the prepared branch name, without `refs/heads/`.
The `eng` checkout supplies pipeline/build implementation; the `source`
repository resource supplies release dependencies. The pipeline is manual:
merging a PR does not queue it automatically.

Confirm these independent choices against the matrix:

- `stabilizePackageVersion`: `true` for stable output; `false` for servicing
  validation or preview/RC output. Final RC publication still uses `false`.
- `publishToAzDO` and `azDOPublishFeed`: select the approved destination. The
  current default is `public/dotnet-workloads`, consumed at
  `https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-workloads/nuget/v3/index.json`.
- `publishToNuGet`: enable only for approved final publication, not ordinary
  validation or VS insertion runs.
- `createVSInsertion`: enable only for the approved VS insertion phase.
- `createTestWorkloadSet`: a special test-version mode, not a general validation
  flag. Ordinary servicing/RC validation can leave it `false`.

Validation can use AzDO publication without NuGet, or stable artifacts with
publication disabled. Publishing a workload set does not by itself guarantee
that all referenced workload packages have been published by their owners.

Record the resolved `eng` and `source` resource SHAs from the run. Verify the
resolved source matches the approved commit before approving publication or
accepting an insertion; do not substitute the current branch head for the
commit actually consumed by the run.

### 5. Validate workload installation and VS insertions

Use an isolated test environment for each shipping SDK band. Follow
[Test Workload Updates](test-workload-updates.md), using the exact generated
workload-set version and approved feeds or downloaded package artifacts.
For local artifacts, add their directory (for example `C:\packages`) as a NuGet
source. Add any additional feeds required by unreleased dependencies, then run:

```powershell
dotnet workload update --version <generated-workload-set-version>
```

For VS insertion, select only the required `workloadDropNames` (`emsdk`, `mono`,
`iOS`, `android`, `maui`; casing matters). Primary targets receive packs and
(pre)components; secondary targets receive **packs only**. Empty primary or
secondary lists are valid. When `createVSInsertion=false`, these lists are inactive.

Validate the expected entries and drop URLs in the VS PR, not a fixed number of
changed files. Several workloads can be represented in one JSON file. The
default monthly topic branch can accumulate updates from several builds and
.NET versions; inspect all contributing builds, latest PR iteration and target.
Search active and completed PRs when the logs report an existing PR or no change.

Automation validates and reports VS PRs; a person approves and merges them.
The current insertion template nevertheless sets `InsertAutoComplete: true`.
Check and report the PR's actual autocomplete state to the responsible person;
documentation or agent handoff alone does not disable pipeline autocomplete.
Enforcing manual-only completion requires a separate pipeline/policy change.

### 6. Monitor and approve publication

After Build, Insertion and Publish are independent stages, not a serial sequence.
A failed Publish approval/check does not mean Build or VS insertion failed.
The Publish deployment uses the `DotNet-SDK-Workloads` environment; AzDO and
NuGet publishing tasks share that deployment rather than separate approval stages.

Approval waits can dominate elapsed time. Report stage/task results, waiting
approvals and links instead of promising a fixed end-to-end duration. Approve
publication only after the release owner's required validation and signoff.
Verify the publishing tasks and exact package identities/versions in each
requested destination. Record VS PR state separately from publication status.

### Troubleshooting and recovery

- **Ambiguous BAR lookup:** an upstream SHA can identify more than one BAR build.
  Verify the intended upstream build and add its explicit `BarId` in
  `eng/Version.Details.xml` through a reviewed source update. A mono/emsdk-only
  insertion can still fail while resolving another dependency such as macios.
- **Existing PR / no changes:** inspect the current target, topic branch and PR
  contents. These messages do not prove either success or failure. Do not queue
  duplicate builds merely to obtain a new PR.
- **Partial/failed run:** inspect the first failing task, stage attempts and
  existing side effects before retrying. Reuse valid artifacts/PRs and retry the
  appropriate failed stage where supported. Changed source or branding may
  require a new run; retain links to the superseded run.

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
