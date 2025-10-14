# Preview Branch Preparation Process

This document outlines the process we go through during previews to prepare the branches for a workloads insertion.

## Overview

When preparing for a new preview release of .NET, we need to ensure that the workload-versions repository is properly configured to receive and flow dependencies from the correct sources. This involves updating Maestro subscriptions to point to the appropriate channels for the preview period.

## Process Steps

### 1. Change the Channel for the dotnet/dotnet Subscription

The workload-versions repository receives dependencies from the `dotnet/dotnet` repository (the VMR - Virtual Monolithic Repository) through Maestro subscriptions. During preview periods, we need to update these subscriptions to point to the correct preview channel.

#### Steps to Update the Subscription:

1. **Identify the target preview channel**
   - Preview channels typically follow the pattern: `.NET <version> Preview <number>`
   - Example: `.NET 10 Preview 1`, `.NET 10 Preview 2`, etc.
   - You can list available channels using: `darc get-channels`

2. **Find the current subscription**
   - List all subscriptions for the repository:
     ```bash
     darc get-subscriptions --target-repo workload-versions --source-repo dotnet/dotnet --target-branch main
     ```
   - Identify the subscription from `dotnet/dotnet` (the VMR)

3. **Update the subscription to the new preview channel**
   - Use the DARC tool to update the subscription:
     ```bash
     darc update-subscription --id <subscription-id> --channel "<channel-name>"
     ```
   - Example:
     ```bash
     darc update-subscription --id 12345 --channel ".NET 10 Preview 2"
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
   - No separate preview branch is needed for these releases

2. **Update Version.props**
   - Set the appropriate version features and patch levels for the preview
   - Update `VersionFeature` to match the SDK release band
   - Ensure `VersionPatch` is set correctly (typically 0 for a new preview)

3. **Configure channel publishing**
   - Ensure builds from this branch publish to the correct workloads feed
   - For .NET 10: `dotnet10-workloads` feed
   - Feed URL: `https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet10-workloads/nuget/v3/index.json`

### 3. Update Package IDs for MAUI Packages

When transitioning to a new preview, you need to update the package ID suffixes for all MAUI-related packages in `eng/Versions.props`.

#### Steps to Update MAUI Package IDs:

1. **Locate the MauiWorkloads property group**
   - Open `eng/Versions.props`
   - Find the `<PropertyGroup Label="MauiWorkloads">` section

2. **Update the MauiFeatureBand property**
   - Change to match the new preview version
   - Example: `<MauiFeatureBand>10.0.100-rc.3</MauiFeatureBand>`

3. **Update all MAUI manifest package property names**
   - The property names encode the SDK band and preview in their suffix
   - For example, when moving from RC 2 to RC 3:
     - `MicrosoftNETSdkAndroidManifest100100rc2PackageVersion` → `MicrosoftNETSdkAndroidManifest100100rc3PackageVersion`
     - `MicrosoftNETSdkiOSManifest100100rc2PackageVersion` → `MicrosoftNETSdkiOSManifest100100rc3PackageVersion`
     - `MicrosoftNETSdktvOSManifest100100rc2PackageVersion` → `MicrosoftNETSdktvOSManifest100100rc3PackageVersion`
     - `MicrosoftNETSdkMacCatalystManifest100100rc2PackageVersion` → `MicrosoftNETSdkMacCatalystManifest100100rc3PackageVersion`
     - `MicrosoftNETSdkmacOSManifest100100rc2PackageVersion` → `MicrosoftNETSdkmacOSManifest100100rc3PackageVersion`
     - `MicrosoftNETSdkMauiManifest100100rc2PackageVersion` → `MicrosoftNETSdkMauiManifest100100rc3PackageVersion`

4. **Update the references to these properties**
   - Update property references in the assignment statements:
     ```xml
     <MauiWorkloadManifestVersion>$(MicrosoftNETSdkMauiManifest100100rc3PackageVersion)</MauiWorkloadManifestVersion>
     <XamarinAndroidWorkloadManifestVersion>$(MicrosoftNETSdkAndroidManifest100100rc3PackageVersion)</XamarinAndroidWorkloadManifestVersion>
     <!-- And so on for all workloads -->
     ```

5. **Verify all package property names are updated consistently**
   - Ensure the suffix pattern matches across all MAUI workload packages
   - The pattern should be: `{Major}{Minor}{Band}{PreviewLabel}{PreviewNumber}`
   - Example: `100100rc3` represents 10.0.100-rc.3

### 4. Update VS Manifest IDs for Mono and Emsdk Workloads

Visual Studio integration requires updating the VSMAN (Visual Studio Manifest) IDs and external.vsmanproj references for mono and emsdk workloads when preparing for a new preview.

#### Steps to Update VS Manifest Configuration:

1. **Update VSMAN IDs**
   - The VSMAN IDs need to be updated to match the new preview version
   - These IDs are typically referenced in Visual Studio insertion configuration
   - Coordinate with the VS insertion team to ensure the correct VSMAN ID format for the preview

2. **Update external.vsmanproj for mono workload**
   - Locate or create the external.vsmanproj file for the mono workload
   - Update any version-specific identifiers to match the new preview
   - Ensure the ComponentId reflects the correct preview version

3. **Update external.vsmanproj for emsdk workload**
   - Similarly, update the external.vsmanproj file for the emsdk (Emscripten) workload
   - Update version identifiers and component references
   - Verify the ComponentId aligns with the new preview numbering

4. **Verify VSMAN SDK version**
   - Check `global.json` for the `Microsoft.VisualStudio.Internal.MicroBuild.Vsman` version
   - Ensure it's compatible with the preview release
   - Update if necessary to the latest version

5. **Coordinate with VS insertion process**
   - The VS insertion pipeline may need configuration updates for the new preview
   - Ensure the VSMAN package generation is set up for the correct preview channel
   - Test the insertion process with a test build before the official preview release

> [!NOTE]
> The exact location and format of VSMAN configuration files may vary based on the repository structure and VS insertion setup. Coordinate with the Visual Studio integration team for specific requirements for your preview release.

## Reference Information

### Workloads Feeds by .NET Version

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
