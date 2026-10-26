# Test Workload Updates Process

This document provides instructions for the MAUI, Android, and iOS teams on how to create test workload sets for validation and testing purposes.

## Overview

Test workload sets allow teams to validate workload updates before they are included in official releases. This process supports two main scenarios:
1. Creating test workload sets for general validation
2. Creating test workload sets with Visual Studio insertion for integration testing

For monthly or hotfix release validation, start with the approved matrix in the
[Release Process](release-process.md). Validating a release candidate is not the
same as enabling `createTestWorkloadSet`: ordinary servicing/RC candidates can
use `createTestWorkloadSet=false`. Enable the special test mode below only when
its modified test-version identity is intended.

## Prerequisites

- Access to the workload-versions repository
- Permissions to create branches and pull requests
- Access to Azure DevOps internal builds

## Process Steps

### 1. Create a Test Branch

1. **Branch from a release branch**: Start by creating a test branch from one of the existing release branches
   ```
   Example branch name: release/9.0.3xx-mauitest
   ```
   
   **Branch naming convention:**
   - `release/{version}/mauitest{mauiversion}` - for MAUI team tests
   - `release/{version}/androidtest{androidversion}` - for Android team tests  
   - `release/{version}/iostest{iosversion}` - for iOS team tests

2. **Make your changes**: Update the necessary workload configurations in your test branch
   - An approved hotfix can use an internal-only branch from an explicit baseline.
     Review its dependency changes through an internal Azure DevOps PR rather
     than requiring a GitHub branch or mirror wait.

### 2. Create and Merge Pull Request

1. **Publish your test build to a Darc channel**: After making changes, publish the build artifacts to a dedicated Darc channel for test workloads.
2. **Use `darc update-dependencies`**: Run `darc update-dependencies` to update your test branch with the new build information from the Darc channel. This ensures your branch references the correct test workload versions.
3. **Get approval** from the appropriate reviewers
4. **Merge the PR** once approved

> **Note**: Once the test pipeline is established, PRs will not be required and teams can push directly to the internal Azure DevOps repository.

### 3. Queue Internal Build

After merging your PR, queue an internal build using the Azure DevOps pipeline.
https://dev.azure.com/dnceng/internal/_build?definitionId=1298

## Build Configuration Options

When queuing the pipeline, you have several configuration options depending on your testing needs:

### For Test Workload Sets Only

If you only need to create a test workload set:

1. ✅ **Select pipeline version by branch/tag** set to **eng**
2. ✅ **🚩 Source branch 🚩** set to your branch
3. ✅ **Select "Publish to AzDO"** when queuing the pipeline
4. ✅ **AzDO publish feed** is the feed it'll publish the workload set to. Default should be _dotnet-workloads_.
5. ✅ **⭐ Create a test workload set** enabled
   - This modifies the prerelease iteration used for test workload-set identity;
     verify the generated version in the build artifacts
   - The workload set will be published to Azure DevOps for testing

Keep `publishToNuGet=false` for validation. Set SDK minor, feature and patch
overrides explicitly, and review the effective prerelease label/iteration.
Use `stabilizePackageVersion=false` for servicing/preview/RC candidates;
stable artifacts can also be tested with publication disabled.

The default feed URL is
`https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet-workloads/nuget/v3/index.json`.
Use the actual destination selected for the run, plus any dependency feeds
required by unreleased manifests and packs.

### For Visual Studio Insertion Testing

If you need to test a Visual Studio insertion:

1. ✅ **Update the workload drop names** for the workloads you want to update in VS
2. ✅ **Update the primary VS insertion branch** configuration
3. ✅ **Check the box for "Create VS insertion"**

Use the exact workload drop names: `emsdk`, `mono`, `iOS`, `android`, `maui`.
Primary targets receive packs and (pre)components; secondary targets receive
packs only. Set both lists explicitly, using an empty list when appropriate.
Validate expected JSON entries and drop URLs rather than counting changed files.
Shared topic branches can accumulate several builds in the same PR.

Report validated PRs for human approval/merge. The pipeline currently requests
autocomplete; inspect and report its actual state rather than assuming that a
human handoff disables it.

This configuration will:
- Create the workload set using the selected test-mode and branding settings
- Prepare the workloads for VS insertion
- Initiate the insertion process into the specified VS branch

## Important Notes

- **Installation validation**: In an isolated environment with the intended SDK
  and feeds configured, run `dotnet workload update --version <generated-version>`.
  Validate each shipping SDK band, even when several outputs share one source.
- **Run provenance**: Record the resolved `eng` and `source` resource SHAs and
  verify the source matches the approved commit.
- **Stage results**: Insertion and Publish independently depend on Build.
  Approval waits and Publish failures do not necessarily prevent VS PR creation.

- **Branch Management**: Keep test branches organized and clean up after testing is complete
- **Communication**: Coordinate with other teams if multiple test branches are being used simultaneously

## Troubleshooting

If you encounter issues during the process:

1. **Build Failures**: Check the build logs in Azure DevOps for specific error messages
2. **Permission Issues**: Ensure you have the necessary access rights for the repositories and pipelines
3. **Workload Set Versioning**: Pipeline overrides take precedence over
   `eng/Versions.props`. Inspect the generated version and effective branding,
   not just the branch file or branch name.

## Support

For additional support or questions about this process, please reach out to the .NET SDK team on our Teams chat.
