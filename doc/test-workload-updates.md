# Test Workload Updates

Use this guide to validate workload sets and optional VS insertions before
release. You need repository/PR permissions and access to internal Azure DevOps
builds. For monthly releases or hotfixes, first agree on the matrix in the
[Release Process](release-process.md).

## 1. Prepare the source

Create a test branch from the intended release baseline, update its dependencies
using `darc update-dependencies` with the approved upstream build/channel, then
review and merge the dependency PR. Example branch names:

| Team | Example |
|------|---------|
| MAUI | `release/{version}/mauitest{mauiversion}` |
| Android | `release/{version}/androidtest{androidversion}` |
| iOS | `release/{version}/iostest{iosversion}` |

Use GitHub and verify mirroring for public sources. For an internal-only
hotfix, create/review the branch and PR in Azure DevOps; no GitHub mirror wait
is needed. See the runbook for dependency, feed and source-SHA checks.

## 2. Queue a validation build

Open [pipeline 1298](https://dev.azure.com/dnceng/internal/_build?definitionId=1298)
and choose:

| Setting | Value |
|---------|-------|
| Pipeline version by branch/tag | `eng` |
| Source branch | Your prepared branch |
| Version overrides | Explicit SDK minor, feature and patch; confirm prerelease label/iteration |
| Stabilize package version | `false` for servicing/preview/RC candidates |
| Publish to AzDO | Enable for feed-based testing; default feed is `public/dotnet-workloads` |
| Publish to NuGet | `false` |
| Create a test workload set | Enable only for special test-version identity; ordinary servicing/RC validation can use `false` |

Pipeline overrides take precedence over `eng/Versions.props`. You can also test
stable artifacts with publication disabled.

For VS testing, enable **Create VS insertion** and explicitly select:

- Workload drop names: the required subset of `emsdk`, `mono`, `iOS`, `android`, `maui`.
- Primary targets: packs and (pre)components.
- Secondary targets: packs only. Either target list can be empty.

## 3. Validate the output

Verify the run's resolved `eng` and `source` SHAs and generated version against
the approved plan. Insertion and Publish each depend on Build, not each other;
a Publish approval wait/failure does not establish whether a VS PR was created.

In an isolated environment for **each shipping SDK band**:

1. Install the intended SDK and create a test folder with `dotnet new nugetconfig`.
2. Add the selected AzDO feed or downloaded artifact directory (such as
   `C:\packages`) as a NuGet source. The default feed URL is
   `https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-workloads/nuget/v3/index.json`.
3. Add any feeds required by unreleased manifests/packs, then run:

```powershell
dotnet workload update --version <generated-workload-set-version>
```

For VS testing, follow the runbook's
[insertion validation](release-process.md#5-validate-workload-installation-and-vs-insertions):
check expected JSON entries/drop URLs, including contributions from other builds
in a shared PR. A person approves/merges; report the actual autocomplete setting
because the pipeline currently requests it.

If validation fails, check the first failing task, effective version overrides
and feed/repository permissions. See the runbook's
[recovery guidance](release-process.md#troubleshooting-and-recovery) before retrying.
Coordinate shared branches/PRs with other teams and remove test branches when
they are no longer needed. Contact the .NET SDK team for help.
