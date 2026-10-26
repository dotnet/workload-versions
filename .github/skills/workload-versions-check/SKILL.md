---
name: workload-versions-check
description: Checks workload component versions, manifest IDs and upstream provenance at explicit public or internal source commits, including hotfix matrices and same-version rebuilds.
---

# Check Workload Component Versions and Provenance

## Inputs

- **sources**: explicit repository, branch and immutable SHA for each source.
- **releaseMatrix**: target SDK bands, expected dependency builds and workload
  scope, when validating a release.

If no source list is provided, discover/confirm the active branches for the
requested release; do not rely on a fixed public branch table. A single source
can support several output bands. Internal-only branches do not need GitHub
counterparts.

## Read Each Source at One SHA

Use GitHub CLI/read APIs for public sources or discover the current Azure
DevOps repository-file/commit schemas for internal sources. Resolve a branch
once, record its SHA and read all files at that commit:

- `eng/Versions.props`
- `eng/Version.Details.xml`
- `NuGet.config`
- The approved upstream SDK/VMR build manifest, when available.

Do not fetch different files from moving branch heads. If access or provenance
is unavailable, report it as unverified rather than substituting a public file.

## Extract and Compare

Property names encode manifest bands and prerelease IDs, so match the actual
XML rather than hardcoding complete property names.

| Component | Version property pattern / source |
|-----------|-----------------------------------|
| Runtime/mono | `MicrosoftNETCoreAppRefPackageVersion` on older sources, otherwise `MicrosoftNETWorkloadMonoToolchain*Manifest*PackageVersion` |
| emsdk | `MicrosoftNETWorkloadEmscriptenCurrentManifest*PackageVersion` |
| Android | `MicrosoftNETSdkAndroidManifest*PackageVersion` |
| iOS | `MicrosoftNETSdkiOSManifest*PackageVersion` |
| MAUI | `MicrosoftNETSdkMauiManifest*PackageVersion` |

Match case-insensitively (`Toolchain` versus `ToolChain`) and distinguish
non-transport properties from `*Transport*` siblings. Include other selected
Apple manifests where applicable.

Compare properties with the corresponding XML dependency names/versions and
the approved upstream build. Report each dependency's URI, SHA, BAR ID and
required feed, not just the package version.

Where runtime/mono and emsdk share a servicing line, require matching versions
in the final source. Block a version mismatch. Same-version runtime rebuilds
can legitimately update SHA/feed and SDK provenance without changing emsdk;
different repositories do not require identical SHAs.

If one SHA maps to several BAR builds, require the approved explicit `BarId`.
Check internal upstream URI/feed changes and missing sources even when the
selected VS workload subset would not insert those dependencies.

Manifest IDs, upstream dependency versions, and workload-set branding are
separate. A mono/emsdk RC3 hotfix can retain unaffected mobile/MAUI RC2 IDs.
Do not infer effective output branding from the branch name or dependencies:
compare `Versions.props` plus pipeline overrides to the release matrix.

## Output

Report source repository/branch/SHA first, then a comparison table containing
component, manifest ID, property/XML version, upstream build/URI/SHA/BAR ID,
feed and validation result. Separately report output bands and effective
branding from the matrix.

Distinguish missing data, unverified provenance and confirmed mismatches.
Do not declare readiness from matching version strings alone.
