---
name: workload-release-day
description: Triggers workload set builds for Patch Tuesday releases. Publishes to NuGet.org without VS insertion. Use for monthly .NET release day workload prep.
---

# Workload Set Release Day

## Purpose

Build and publish workload sets to NuGet.org for Patch Tuesday releases. These workload sets do **NOT** insert into VS - they are consumed directly by SDK users via `dotnet workload update`.

## Inputs

- **releaseBranches**: Which branches to build (e.g., `release/8.0.4xx`, `release/9.0.1xx`, `release/10`)
- **workloadSets**: Which SDK feature bands to build. **Do not hardcode these** — always derive the exact bands from the release tracker for the upcoming release date (see Pre-Release Check).

## Standard Release Configuration

### Default Settings (apply to every pipeline unless the user says otherwise)

Unless the user overrides them, assume ALL of the following defaults so the user does not need to restate them:

- **Standard set of 5 pipelines**: one from `release/8.0.4xx`, two from `release/9.0.1xx`, two from `release/10`.
- **Target branch (pipeline resource)**: `refs/heads/eng`.
- **Source branch**: the version-specific `release/*` branch, passed as the `sourceBranch` template parameter.
- **`setVersionFeature`**: always the two-digit, zero-padded feature band (e.g. `02`, `19`, `23`).
- **Branding**: stable (`stabilizePackageVersion: "true"`) unless a band is explicitly a preview.
- **Publish targets**: publish to both AzDO (`publishToAzDO: "true"`, feed `public/dotnet-workloads`) and NuGet (`publishToNuGet: "true"`).
- **No VS insertion**: `createVSInsertion: "false"`, `createTestWorkloadSet: "false"`.
- **Always confirm all settings with the user before triggering** (see Confirmation Step).

### Active Branches & Workload Sets

> ⚠️ **Important**: Branch version files are no longer kept up to date. You **must** always set `setVersionSdkMinor` and `setVersionFeature` explicitly for every build. Use the release tracker (dotnet-release-tracker skill) or releases.json to look up the correct SDK versions.

> ⚠️ **The specific feature bands shift release to release** — especially on the newest major (`release/10`), which currently ships 10.0.1xx + 10.0.3xx (**not** 10.0.2xx). Never assume the bands below; always read the actual shipping SDK versions from the release tracker and map each to a band.

| Source Branch | Workload Sets (typical) | Required Overrides |
|---------------|---------------|-------------------|
| `release/8.0.4xx` | 8.0.4xx | `setVersionSdkMinor`, `setVersionFeature` |
| `release/9.0.1xx` | 9.0.1xx | `setVersionSdkMinor`, `setVersionFeature` |
| `release/9.0.1xx` | 9.0.3xx | `setVersionSdkMinor`, `setVersionFeature` |
| `release/10` | 10.0.1xx (+ second band, e.g. 10.0.3xx) | `setVersionSdkMinor`, `setVersionFeature` |
| `release/10` | second `release/10` band | `setVersionSdkMinor`, `setVersionFeature` |

## Workflow

- [ ] Fetch current SDK versions from releases.json
- [ ] Calculate expected versions (increment patch)
- [ ] Queue pipeline runs for each workload set
- [ ] Monitor builds and report status
- [ ] Verify packages published to NuGet.org

## Pre-Release Check

Preferred: run the **dotnet-release-tracker** skill to fetch the upcoming release's SDK versions per feature band:

```
pwsh scripts/Get-DotNetReleaseStatus.ps1
```

It lists each active release with its **Release Date** and **SDK Version(s)** (e.g. `10.0.302, 10.0.110`). Pick the release whose date matches next week's Patch Tuesday, then map each listed SDK version to a band.

Fallback (if the tracker is unavailable), fetch current versions from GitHub:
```
https://github.com/dotnet/core/blob/main/release-notes/releases-index.json
```

Parse each `releases.json` to get current SDK versions per feature band.

### Deriving the two override values from an SDK version

For SDK version `X.Y.CFP`: `setVersionSdkMinor` = `C` (hundreds digit), `setVersionFeature` = `FP` (tens + ones, two-digit zero-padded).

| SDK Version | Band | `setVersionSdkMinor` | `setVersionFeature` |
|-------------|------|----------------------|---------------------|
| 8.0.423 | 8.0.4xx | 4 | 23 |
| 9.0.119 | 9.0.1xx | 1 | 19 |
| 9.0.316 | 9.0.3xx | 3 | 16 |
| 10.0.110 | 10.0.1xx | 1 | 10 |
| 10.0.302 | 10.0.3xx | 3 | 02 |

## Confirmation Step

Before triggering, present a table of all pipelines with their source branch, target SDK, `setVersionSdkMinor`, `setVersionFeature`, branding, and publish targets, and **ask the user to confirm**. Call out any band that differs from what the user (or this doc) expected — e.g. substituting 10.0.3xx for a previously-listed 10.0.2xx. Only trigger after explicit confirmation.

## Pipeline Execution

Use the `dnceng-azure-devop-pipelines_write` tool with `action: "run_pipeline"`, `project: "internal"`, `pipelineId: 1298`, and `resources: {"repositories": {"self": {"refName": "refs/heads/eng"}}}`. Pass the per-band values via `templateParameters`.

### Base Parameters (All Runs)

```json
{
  "project": "internal",
  "pipelineId": 1298,
  "resources": {
    "pipelines": {},
    "repositories": {"self": {"refName": "refs/heads/eng"}}
  }
}
```

### Stable Workload Set

All stable builds require explicit `setVersionSdkMinor` and `setVersionFeature` parameters. Derive these from the target SDK version: for SDK version `X.Y.CFP`, `setVersionSdkMinor` = `C` (hundreds digit) and `setVersionFeature` = `FP` (tens + ones digits, two-digit zero-padded).

Example for 9.0.314 from release/9.0.1xx branch:

```json
{
  "templateParameters": {
    "sourceBranch": "release/9.0.1xx",
    "createTestWorkloadSet": "false",
    "publishToAzDO": "true",
    "azDOPublishFeed": "public/dotnet-workloads",
    "createVSInsertion": "false",
    "stabilizePackageVersion": "true",
    "publishToNuGet": "true",
    "setVersionSdkMinor": "3",
    "setVersionFeature": "14"
  }
}
```

### Preview Workload Set

> ℹ️ **Only when a band is actually a preview.** The standard monthly run is all-stable. Use this section only if the release tracker shows a preview SDK for a band (e.g. a brand-new `release/10` minor). It is **not** used for 10.0.1xx/10.0.3xx stable builds.

Example for a 10.0.2xx-preview from release/10 branch:

> ⚠️ **Important**: Set `setVersionFeature: "00"` to zero out the feature band, otherwise it inherits from the branch and produces incorrect versions like 10.0.203-preview.0 instead of 10.0.200-preview.0.

```json
{
  "templateParameters": {
    "sourceBranch": "release/10",
    "createTestWorkloadSet": "false",
    "publishToAzDO": "true",
    "azDOPublishFeed": "public/dotnet-workloads",
    "createVSInsertion": "false",
    "stabilizePackageVersion": "false",
    "publishToNuGet": "true",
    "setVersionSdkMinor": "2",
    "setVersionFeature": "00",
    "setPreReleaseVersionLabel": "preview",
    "setPreReleaseVersionIteration": "0"
  }
}
```

## Version Override Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `setVersionSdkMinor` | SDK minor version (one digit) | `3` for 9.0.3xx |
| `setVersionFeature` | Feature band (two digits) | `11` for x.x.311 |
| `setVersionPatch` | Patch number | `13` for runtime 9.0.13 |
| `setPreReleaseVersionLabel` | Pre-release label | `preview`, `rc`, `alpha` |
| `setPreReleaseVersionIteration` | Pre-release iteration | `0`, `1`, `2` |

## Critical Notes

1. **Pipeline branch**: MUST use `refs/heads/eng` in resources
2. **No VS Insertion**: `createVSInsertion` = `false` for all release day runs
3. **Stabilize versions**: `stabilizePackageVersion` = `true` for stable releases, `false` for preview
4. **Always set version overrides**: Branch version files are no longer kept current. Always set `setVersionSdkMinor` and `setVersionFeature` explicitly for every build. Use release tracker to look up SDK versions.
5. **Preview feature band**: Set `setVersionFeature` = `"00"` to zero out the feature band for new preview SDK minor versions
6. **Publish to NuGet**: `publishToNuGet` = `true` to push to NuGet.org
7. **Build duration**: ~60-90 minutes per build

## Output

Report queued builds:

| Workload Set | Build ID | Link |
|--------------|----------|------|
| 8.0.4xx | 2899378 | [View](https://dev.azure.com/dnceng/internal/_build/results?buildId=2899378) |
| 9.0.1xx | 2899379 | [View](https://dev.azure.com/dnceng/internal/_build/results?buildId=2899379) |

## Verification

After builds complete, verify packages on NuGet.org:
- `Microsoft.NET.Workloads.8.0.418`
- `Microsoft.NET.Workloads.9.0.114`
- etc.

## Difference from VS Insertion

| Aspect | Release Day | VS Insertion |
|--------|-------------|--------------|
| `createVSInsertion` | `false` | `true` |
| `publishToNuGet` | `true` | Usually `false` |
| Target | NuGet.org for SDK users | VS branches |
| Frequency | Monthly (Patch Tuesday) | As needed |

## Minimal Prompt (for the user)

Because the Default Settings above are now baked in, the standard monthly run can be requested with just:

> "Prepare next week's release-day workload sets."

That implies all of: the standard 5 pipelines (8.0.4xx, 9.0.1xx, 9.0.3xx, and the two current `release/10` bands), `eng` as the target branch, version-specific `release/*` branches as `sourceBranch`, two-digit `setVersionFeature`, stable branding, publish to both AzDO and NuGet, and confirm-before-trigger. You only need to add extra words to **override** a default — e.g. "include a preview band", "skip 8.0.4xx", or "don't publish to NuGet".
