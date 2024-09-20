# Release Process Documentation

Based on https://github.com/dotnet/sdk/issues/41607

## Ideal Process

> [!NOTE]
> This process may vary based on the workload owners.

> [!NOTE]
> Most of this process today is done through disparate builds in each workload repo and this repo (or manually). Below is outlining our desired goal.

1. **Publishing Release-Ready Versions**
    - Each workload owner publishes release-ready versions to the `dotnet8-workloads` and `dotnet9-workloads` channels.

2. **Creating Workload Set Repo PRs**
    - Workload set repository pull requests (PRs) are created based on the release channel.

3. **Review and Merge PRs**
    - A person reviews the PR, approves it, merges it, and a build is triggered automatically.

5. **Build Process**
    - There are a few phases to the build process:
        1. Create a stable and unstable version of the workload set (a stable version is only needed in servicing).
            - 9.0.102-servicing.12345.6
            - 9.0.102
        2. Publish the unstable version to the workloads feed.
        3. The process is different depending on if we're in servicing/golive.
            1. If we're **not** in servicing/golive:
                - Publish runtime, emsdk, maui, and aspire to the workloads feed.
            2. If we're in servicing/golive:
                - Only publish maui and the unstable workload set to the workloads feed.
                - Additionally, create a stable workloads feed and publish the runtime, emsdk, maui, aspire, and stable workload to that feed.
                  - To enable this step, the .NET staging pipeline will have to be modified to publish the runtime and emsdk builds to the appropriate workloads channels. Today, that publishing is done in the runtime public build.
        4. Create a vsdrop for each workload.

6. **Creating a VS PR**
    - Creates a Visual Studio (VS) PR with the workloads JSON file updated.

7. **Testing and Merging**
    - Test the VS PR, sign off, and merge the workload set and all workloads together.

8. **Publish to nuget.org** (on release day)
    - Publish packs for all workloads
    - Query nuget.org until the packs are available
    - Publish manifests for all workloads
    - Query nuget.org until the manifests are available
    - Publish the wokload set

## Additional Details

### Approvals

In the above steps, step 3 will require approval in GitHub. Additionally, steps 5.2, 5.3, 6, and 8 should each require approval in the workload staging pipeline. 

Basically, everything should happen automatically once merged but we want to control whether we publish the workloads to the feeds, to VS, and to nuget.org so we don't publish by default.

### We have a preview workloads feed for each major version of .NET
- dotnet8-workloads https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet8-workloads/nuget/v3/index.json
- dotnet9-workloads https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet9-workloads/nuget/v3/index.json
