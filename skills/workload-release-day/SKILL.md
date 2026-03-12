---
name: workload-release-day
description: Triggers workload set builds for Patch Tuesday releases. Publishes to NuGet.org without VS insertion. Use for monthly .NET release day workload prep.
---

# Workload Set Release Day

## Purpose

Build and publish workload sets to NuGet.org for Patch Tuesday releases. These workload sets do **NOT** insert into VS - they are consumed directly by SDK users via `dotnet workload update`.

## Inputs

- **releaseBranches**: Which branches to build (e.g., `release/8.0.4xx`, `release/9.0.1xx`, `release/10`)
- **workloadSets**: Which SDK feature bands to build (e.g., 8.0.4xx, 9.0.1xx, 9.0.3xx, 10.0.1xx, 10.0.2xx-preview)

## Standard Release Configuration

### Active Branches & Workload Sets

| Source Branch | Workload Sets | Notes |
|---------------|---------------|-------|
| `release/8.0.4xx` | 8.0.4xx | Stable, uses branch defaults |
| `release/9.0.1xx` | 9.0.1xx | Stable, uses branch defaults |
| `release/9.0.1xx` | 9.0.3xx | Stable, override `setVersionSdkMinor: 3` |
| `release/10` | 10.0.1xx | Stable, uses branch defaults |
| `release/10` | 10.0.2xx | Preview, override `setVersionSdkMinor: 2` |

## Workflow

- [ ] Fetch current SDK versions from releases.json
- [ ] Calculate expected versions (increment patch)
- [ ] Queue pipeline runs for each workload set
- [ ] Monitor builds and report status
- [ ] Verify packages published to NuGet.org

## Pre-Release Check

Fetch current versions from GitHub:
```
https://github.com/dotnet/core/blob/main/release-notes/releases-index.json
```

Parse each `releases.json` to get current SDK versions per feature band.

## Pipeline Execution

Use `dnceng-azure-devop-pipelines_run_pipeline`:

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

### Stable Workload Set (Default Version)

```json
{
  "templateParameters": {
    "sourceBranch": "<branch>",
    "createTestWorkloadSet": "false",
    "publishToAzDO": "true",
    "azDOPublishFeed": "public/dotnet-workloads",
    "createVSInsertion": "false",
    "stabilizePackageVersion": "true",
    "publishToNuGet": "true"
  }
}
```

### Stable Workload Set (Version Override)

For 9.0.3xx from 9.0.1xx branch:

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
    "setVersionFeature": "11"
  }
}
```

### Preview Workload Set

For 10.0.2xx-preview from release/10 branch:

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
4. **Preview feature band**: Set `setVersionFeature` = `"00"` to zero out the feature band for new preview SDK minor versions
5. **Publish to NuGet**: `publishToNuGet` = `true` to push to NuGet.org
6. **Build duration**: ~60-90 minutes per build

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
