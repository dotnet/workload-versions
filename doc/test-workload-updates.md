# Test Workload Updates Process

This document provides instructions for the MAUI, Android, and iOS teams on how to create test workload sets for validation and testing purposes.

## Overview

Test workload sets allow teams to validate workload updates before they are included in official releases. This process supports two main scenarios:
1. Creating test workload sets for general validation
2. Creating test workload sets with Visual Studio insertion for integration testing

## Prerequisites

- Access to the workload-versions repository
- Permissions to create branches and pull requests
- Access to Azure DevOps internal builds

## Process Steps

### 1. Create a Test Branch

1. **Branch from a release branch**: Start by creating a test branch from one of the existing release branches
   ```
   Example branch name: release/9.0.3xx/mauitest
   ```
   
   **Branch naming convention:**
   - `release/{version}/mauitest{mauiversion}` - for MAUI team tests
   - `release/{version}/androidtest{androidversion}` - for Android team tests  
   - `release/{version}/iostest{iosversion}` - for iOS team tests

2. **Make your changes**: Update the necessary workload configurations in your test branch

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
   - This will generate the test workload set for validation that is of the form
   - The workload set will be published to Azure DevOps for testing

### For Visual Studio Insertion Testing

If you need to test a Visual Studio insertion:

1. ✅ **Update the workload drop names** for the workloads you want to update in VS
2. ✅ **Update the primary VS insertion branch** configuration
3. ✅ **Check the box for "Create VS insertion"**

This configuration will:
- Create the test workload set
- Prepare the workloads for VS insertion
- Initiate the insertion process into the specified VS branch

## Important Notes

- **Branch Management**: Keep test branches organized and clean up after testing is complete
- **Communication**: Coordinate with other teams if multiple test branches are being used simultaneously

## Troubleshooting

If you encounter issues during the process:

1. **Build Failures**: Check the build logs in Azure DevOps for specific error messages
2. **Permission Issues**: Ensure you have the necessary access rights for the repositories and pipelines
4. **Workload Set Versioning**: The workload set created will match the SDK band specified in the `Versions.props` file.

## Support

For additional support or questions about this process, please reach out to the .NET SDK team on our Teams chat.
