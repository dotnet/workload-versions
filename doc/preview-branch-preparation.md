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
     darc get-subscriptions --target-repo workload-versions
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

Depending on the preview and SDK version you're preparing for, you may need to:

1. **Create or update the appropriate branch**
   - For example: `release/10.0.1xx-preview2` for .NET 10 Preview 2 SDK band 100
   - Ensure the branch is created from the correct starting point

2. **Update Version.props**
   - Set the appropriate version features and patch levels for the preview
   - Update `VersionFeature` to match the SDK release band
   - Ensure `VersionPatch` is set correctly (typically 0 for a new preview)

3. **Configure channel publishing**
   - Ensure builds from this branch publish to the correct workloads feed
   - For .NET 10: `dotnet10-workloads` feed
   - Feed URL: `https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet10-workloads/nuget/v3/index.json`

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
