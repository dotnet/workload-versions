# Preview Branch Preparation Process

This document outlines the process we go through during previews to prepare the branches for a workloads insertion.

## Overview

When preparing for a new preview release of .NET, we need to ensure that the workload-versions repository is properly configured to receive and flow dependencies from the correct sources. This involves updating Maestro subscriptions to point to the appropriate channels for the preview period.

For OOB/RC hotfixes, follow the [Release Process](release-process.md): use the
approved baseline and internal-only branch when needed, without a GitHub mirror
wait. Do not retarget monthly subscriptions for an isolated hotfix.

## Process Steps

### 1. Change the Channel for the dotnet/dotnet Subscription

The workload-versions repository receives dependencies from the `dotnet/dotnet` repository (the VMR - Virtual Monolithic Repository) through Maestro subscriptions. During preview periods, we need to update these subscriptions to point to the correct preview channel.

#### Steps to Update the Subscription:

1. **Identify the target preview channel**
   - Preview channels typically follow the pattern: `.NET <version>.0.1xx SDK Preview <number>`
   - Example: `.NET 10.0.1xx SDK Preview 1`, `.NET 10.0.1xx SDK Preview 2`, etc.
   - For RC1, RC2, and servicing releases, the channel form is: `.NET <version>.0.1xx SDK Internal` (for MSRC releases)
   - You can list available channels using: `darc get-channels`

2. **Find the current subscription**
   - List all subscriptions for the repository:
     ```bash
     darc get-subscriptions --target-repo workload-versions --source-repo dotnet/dotnet --target-branch main
     ```
   - Identify the subscription from `dotnet/dotnet` (the VMR)
   
   > [!NOTE]
   > For RC1, RC2, and servicing releases, the subscription source is from `dotnet-dotnet` (the internal Azure DevOps URI: `https://dev.azure.com/dnceng/internal/_git/dotnet-dotnet`).

3. **Update the subscription to the new preview channel**
   - Use the DARC tool to update the subscription:
     ```bash
     darc update-subscription --id <subscription-id> --channel "<channel-name>"
     ```
   - Example:
     ```bash
     darc update-subscription --id 12345 --channel ".NET 10.0.1xx SDK Preview 2"
     ```

4. **Verify the subscription update**
   - Confirm the change was applied:
     ```bash
     darc get-subscription --id <subscription-id>
     ```
   - Check that the `Channel` field shows the new preview channel

5. **Monitor dependency flow**
   - After updating the subscription, monitor for new pull requests from Maestro
   - PRs will be automatically created when new builds are published to the preview channel
   - These PRs will update the `eng/Version.Details.xml` file with new dependency versions

### 2. Update Branch Configuration

For major version previews shipped from the main branch:

1. **Work from the main branch**
   - Major version previews (e.g., .NET 10 RC 1, RC 2) are typically shipped from the main branch
   - A separate preview branch is not normally needed; isolated hotfixes can use a separate internal branch as described above

2. **Review `eng/Versions.props` and pipeline overrides**
   - Set explicit SDK minor, feature and patch overrides (patch is typically 0)
   - Confirm `PreReleaseVersionLabel` and `PreReleaseVersionIteration`;
     dependency ID changes do not update branding
   - Use `stabilizePackageVersion=false` for preview/RC output, including final publication

3. **Configure channel publishing**
   - Use the release-approved feed; the current default is `public/dotnet-workloads`
   - See [test feed setup](test-workload-updates.md#3-validate-the-output) for its URL

### 3. Update Package IDs for MAUI Packages

Update MAUI-related ID/property suffixes in `eng/Versions.props` only when those
workloads transition. A mono/emsdk RC3 hotfix can leave mobile/MAUI IDs at RC2.
Preserve upstream dependency versions, SHAs, URIs and feeds: changing IDs does
not change the upstream build or workload-set branding.

#### Steps to Update MAUI Package IDs:

1. **Locate the MauiWorkloads property group**
   - Open `eng/Versions.props`
   - Find the `<PropertyGroup Label="MauiWorkloads">` section

2. **Update the MauiFeatureBand property**
   - Change to match the new preview version
   - Example: `<MauiFeatureBand>10.0.100-rc.2</MauiFeatureBand>`

3. **Update all MAUI manifest package property names**
   - The property names encode the SDK band and preview in their suffix
   - For example, when moving from RC 1 to RC 2:
     - `MicrosoftNETSdkAndroidManifest100100rc1PackageVersion` → `MicrosoftNETSdkAndroidManifest100100rc2PackageVersion`
     - `MicrosoftNETSdkiOSManifest100100rc1PackageVersion` → `MicrosoftNETSdkiOSManifest100100rc2PackageVersion`
     - `MicrosoftNETSdktvOSManifest100100rc1PackageVersion` → `MicrosoftNETSdktvOSManifest100100rc2PackageVersion`
     - `MicrosoftNETSdkMacCatalystManifest100100rc1PackageVersion` → `MicrosoftNETSdkMacCatalystManifest100100rc2PackageVersion`
     - `MicrosoftNETSdkmacOSManifest100100rc1PackageVersion` → `MicrosoftNETSdkmacOSManifest100100rc2PackageVersion`
     - `MicrosoftNETSdkMauiManifest100100rc1PackageVersion` → `MicrosoftNETSdkMauiManifest100100rc2PackageVersion`

4. **Update the references to these properties**
   - Update property references in the assignment statements:
     ```xml
     <MauiWorkloadManifestVersion>$(MicrosoftNETSdkMauiManifest100100rc2PackageVersion)</MauiWorkloadManifestVersion>
     <XamarinAndroidWorkloadManifestVersion>$(MicrosoftNETSdkAndroidManifest100100rc2PackageVersion)</XamarinAndroidWorkloadManifestVersion>
     <!-- And so on for all workloads -->
     ```

5. **Verify all package property names are updated consistently**
   - Ensure the suffix pattern matches across all MAUI workload packages
   - The pattern should be: `{Major}{Minor}{Band}{PreviewLabel}{PreviewNumber}`
   - Example: `100100rc2` represents 10.0.100-rc.2

### 4. Update VS Manifest IDs for Mono and Emsdk Workloads

Visual Studio integration requires updating the VSMAN (Visual Studio Manifest) IDs and external.vsmanproj references for mono and emsdk workloads when preparing for a new preview.

#### Steps to Update VS Manifest Configuration:

1. **Update VSMAN IDs in dotnet-workloads-components.json**
   - The VSMAN IDs need to be updated to match the new preview version
   - These IDs are referenced in `dotnet-workloads-components.json`
   - Update the VSMAN references for mono and emsdk workloads in this configuration file

2. **Update VisualStudio.External.vsmanproj for mono workload**
   - Locate the `VisualStudio.External.vsmanproj` file for the mono workload
   - Update any version-specific identifiers to match the new preview
   - Ensure the ComponentId reflects the correct preview version

3. **Update VisualStudio.External.vsmanproj for emsdk workload**
   - Similarly, update the `VisualStudio.External.vsmanproj` file for the emsdk (Emscripten) workload
   - Update version identifiers and component references
   - Verify the ComponentId aligns with the new preview numbering

4. **Coordinate with VS insertion process**
   - The VS insertion pipeline may need configuration updates for the new preview
   - Ensure the VSMAN package generation is set up for the correct preview channel
   - Test the insertion process with a test build before the official preview release

> [!NOTE]
> The exact location and format of VSMAN configuration files may vary based on the repository structure and VS insertion setup.

## Reference Information

### Workloads Feeds by .NET Version

These legacy feeds are not the current default. Use the release-approved
`azDOPublishFeed` (default: `public/dotnet-workloads`).

- dotnet8-workloads: https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet8-workloads/nuget/v3/index.json
- dotnet9-workloads: https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet9-workloads/nuget/v3/index.json
- dotnet10-workloads: https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet10-workloads/nuget/v3/index.json

### Useful DARC Commands

```bash
# List all channels
darc get-channels

# List subscriptions for this repository
darc get-subscriptions --target-repo workload-versions

# Get details of a specific subscription
darc get-subscription --id <subscription-id>

# Update a subscription's channel
darc update-subscription --id <subscription-id> --channel "<channel-name>"

# List available builds in a channel
darc get-builds --channel "<channel-name>"
```

### Documentation Links

- [DARC Documentation](https://github.com/dotnet/arcade/blob/main/Documentation/Darc.md)
- [Maestro/Dependency Flow Documentation](https://github.com/dotnet/arcade/blob/main/Documentation/DependencyFlowOnboarding.md)
- [Release Process Documentation](release-process.md)

## Common Issues and Troubleshooting

### Subscription Not Updating

If dependency PRs are not being created after updating the subscription:

1. Verify the subscription channel is correct
2. Check that builds are being published to the target channel
3. Ensure the subscription is enabled (not disabled)
4. Check Maestro for any errors in the subscription processing

### Wrong Dependencies Flowing In

If you're receiving dependencies from the wrong builds:

1. Verify the subscription is pointing to the correct channel
2. Check the channel's build sources
3. Ensure you updated the correct subscription (there may be multiple)

## Timeline Considerations

- Subscription channel updates should be made **before** the first preview build is published
- Allow time for the first dependency update PR to flow through and be merged
- Coordinate with the dotnet/dotnet (VMR) team on preview build schedules
- Plan for at least one full dependency flow cycle before declaring the branch ready for insertions
