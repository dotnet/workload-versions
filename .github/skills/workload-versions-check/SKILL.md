---
name: workload-versions-check
description: Fetches current component versions (runtime, android, ios, maui) from the dotnet/workload-versions repo across all active branches. Use when asked about current workload versions, what versions are shipping, or to compare versions across branches.
---

# Check Workload Component Versions

## Purpose

Retrieve the current runtime, Android, iOS, and MAUI versions from `eng/Versions.props` in the `dotnet/workload-versions` repo across all active branches. Produces a summary table for quick comparison.

## Branches

| Branch | SDK Band | Notes |
|--------|----------|-------|
| `release/8.0.4xx` | 8.0.4xx | LTS servicing |
| `release/9.0.1xx` | 9.0.1xx | STS servicing |
| `release/10` | 10.0.1xx | Current stable |
| `main` | 11.0.1xx | Next preview |

## Workflow

- [ ] Fetch `eng/Versions.props` from each branch
- [ ] Extract the four component versions per branch
- [ ] Present results in a comparison table

## Fetching Versions

For each branch, use `github-mcp-server-get_file_contents`:

```json
{
  "owner": "dotnet",
  "repo": "workload-versions",
  "path": "eng/Versions.props",
  "ref": "refs/heads/<branch>"
}
```

## Extracting Property Values

Property names vary by branch because they encode the SDK feature band. Use these patterns to locate the right XML elements:

### Runtime / Mono

| Branch | Property Name |
|--------|---------------|
| `release/8.0.4xx` | `MicrosoftNETCoreAppRefPackageVersion` |
| `release/9.0.1xx` | `MicrosoftNETCoreAppRefPackageVersion` |
| `release/10` | Property matching `MicrosoftNETWorkloadMonoToolchain*Manifest*PackageVersion` (not the transport variant) |
| `main` | Property matching `MicrosoftNETWorkloadMonoToolChain*Manifest*PackageVersion` (not the transport variant) |

### Android

Property matching `MicrosoftNETSdkAndroidManifest*PackageVersion` (not the transport variant).

### iOS

Property matching `MicrosoftNETSdkiOSManifest*PackageVersion` (not the transport variant).

### MAUI

Property matching `MicrosoftNETSdkMauiManifest*PackageVersion` (not the transport variant).

## Gotchas

- **Property names are band-versioned**: e.g. `*80100*` for 8.0, `*90100*` for 9.0, `*100100*` for 10.0. Don't hardcode the full property name — match the prefix pattern.
- **Transport vs non-transport**: Many properties have a `*Transport*` sibling. Use the **non-transport** version (the shorter name without "Transport").
- **`main` uses preview suffixes**: Property names on `main` include a preview label like `110100preview3`. This changes each preview cycle.
- **Capitalization quirk**: `release/10` uses `Toolchain` (lowercase 'c') while `main` uses `ToolChain` (uppercase 'C'). Match case-insensitively.
- **8.0/9.0 runtime property differs**: Older branches use `MicrosoftNETCoreAppRefPackageVersion` for runtime instead of the Mono Toolchain manifest property.

## Output

Present a single comparison table:

```markdown
| Component | release/8.0.4xx | release/9.0.1xx | release/10 | main |
|-----------|-----------------|-----------------|------------|------|
| Runtime   | 8.0.x           | 9.0.x           | 10.0.x     | 11.0.0-preview.x |
| Android   | 34.0.x          | 35.0.x          | 36.x.x     | 36.99.0-preview.x |
| iOS       | 18.0.x          | 26.2.x          | 26.2.x     | 26.2.x-net11-px |
| MAUI      | 8.0.x           | 9.0.x           | 10.0.x     | 11.0.0-preview.x |
```

If any branch or property is missing, note it in the table with `⚠️ not found` rather than failing silently.
