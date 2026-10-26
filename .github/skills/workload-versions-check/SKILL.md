---
name: workload-versions-check
description: Checks workload versions, IDs, feeds and upstream builds at public or internal source SHAs, including same-version rebuilds.
---

# Check Workload Versions and Upstream Builds

## Inputs

Source repository/branch/SHA and, for releases, the approved matrix of SDK
bands, workloads and upstream builds. If omitted, confirm the active sources;
do not assume a fixed public branch list or substitute public data for an
inaccessible internal source.

## 1. Read one snapshot

Resolve each branch once and read these at the same SHA:

- `eng/Versions.props`
- `eng/Version.Details.xml`
- `NuGet.config`

Compare them with the approved upstream SDK/VMR build manifest. Report missing
access or upstream evidence as unverified.

## 2. Compare dependencies

Match properties case-insensitively and exclude `*Transport*` siblings:

| Component | Version property |
|-----------|------------------|
| Runtime/mono | `MicrosoftNETCoreAppRefPackageVersion` or `MicrosoftNETWorkloadMonoToolchain*Manifest*PackageVersion` |
| emsdk | `MicrosoftNETWorkloadEmscriptenCurrentManifest*PackageVersion` |
| Android | `MicrosoftNETSdkAndroidManifest*PackageVersion` |
| iOS | `MicrosoftNETSdkiOSManifest*PackageVersion` |
| MAUI | `MicrosoftNETSdkMauiManifest*PackageVersion` |

Include other selected Apple manifests. Check each property's XML dependency
ID/version, upstream URI/SHA/BAR ID and required feed.

- Runtime/mono and emsdk versions must match where they share a servicing line.
  A same-version runtime rebuild can change SHA/feed and SDK build without
  changing emsdk; different repositories do not require identical SHAs.
- If a SHA identifies several BAR builds, require the approved explicit `BarId`.
  Check all dependencies/feeds, even those outside the selected VS subset.
- Keep manifest IDs, upstream versions and output branding distinct. A
  mono/emsdk RC3 hotfix can retain unaffected mobile/MAUI RC2 IDs. Compare
  `Versions.props` plus pipeline overrides with the expected output.

## Output

Report source repository/branch/SHA, then component ID, property/XML version,
upstream build/URI/SHA/BAR ID, feed and result. Report output bands/branding
separately. Distinguish confirmed mismatches from missing or unverified data;
matching version strings alone do not establish readiness.
