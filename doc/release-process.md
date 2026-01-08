# Release Process Documentation

Based on https://github.com/dotnet/sdk/issues/41607

## Current Process

This section details the current process for releasing workloads.

1. **Identify the current versions of the workloads you want to ship**
2. **Identify an existing PR that makes those changes**
3. **Update the branding in the Version.props file for the release**
    - If it's a monthly release, update the VersionFeature to match the SDK release and set VersionPatch to 0
    - If it's an in-between release, increment the VersionPatch value
    - Note, if you are prepping 9 release, make sure you update all impacted branches since we are shipping multiple .NET9 SDKs from one branch
4. **Merge the change**
5. **Wait for the change to flow internally**
    - You can check the branch history internally to see if you change made it
7. **Queue a build**
    - Target the branch you are shipping from
    - Only select both the checkbox for a stable version and publish to the feed if you have high confidence that the branding and versions are correct.
      - Without the stable box selected, you will get a -servicing version of the stable ID workload which can be used for testing and saved on the feed
      - You can select stable and not publish to the feed and download the package artifacts locally for testing
8. **Verify the versions**
    - Go to the release-tracker (an internal website)
    - Compare the version in the `release/8.0.4xx`, `release/9.0.1xx`, and `release/10.0.1xx` branches to the manifest for each of the versions listed in the release tracker
    - A shorthand is to check the SDK version in the branch as that should be sufficient, but comparing the commit SHA to the manifest is an exact match
    - Note that release tracker will show the latest staging which in rare instances may not be correct. You can click the builds node in the release tracker tool to see all staged builds for a release if you aren't sure.
9. **Test the build**
    - start a sandbox
    - install the SDK band you intend to test
    - create a test folder
      - cd \
      - mkdir test
      - cd test
      - dotnet new nugetconfig
    - if you published to a feed
      - dotnet nuget add source https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet9-workloads/nuget/v3/index.json
    - if you didn't publish to a feed
      - copy the packageartifacts into c:\packages
      - dotnet nuget add source c:\packages
    - dotnet workload update --version <version>
      - note that if you are testing before release day, you may have to find and add additional feeds for the various manifest.
    - testing the manifests is typically enough 
10. **Approve the 'publish on NuGet.org' stage in the AzDO pipeline**

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

4. **Build Process**
    - There are a few phases to the build process:
        1. Create a stable and unstable version of the workload set (a stable version is only needed in servicing).
            - 9.0.102-servicing.12345.6
            - 9.0.102
        2. Publish the unstable version to the workloads feed.
        3. The process is different depending on if we're in servicing/golive.
            1. If we're **not** in servicing/golive:
                - Publish runtime, emsdk, and maui to the workloads feed.
            2. If we're in servicing/golive:
                - Only publish maui and the unstable workload set to the workloads feed.
                - Additionally, create a stable workloads feed and publish the runtime, emsdk, maui, and stable workload to that feed.
                  - To enable this step, the .NET staging pipeline will have to be modified to publish the runtime and emsdk builds to the appropriate workloads channels. Today, that publishing is done in the runtime public build.
        4. Create a vsdrop for each workload.

5. **Creating a VS PR**
    - Creates a Visual Studio (VS) PR with the workloads JSON file updated.

6. **Testing and Merging**
    - Test the VS PR, sign off, and merge the workload set and all workloads together.

7. **Publish to nuget.org** (on release day)
    - Publish packs for all workloads
    - Query nuget.org until the packs are available
    - Publish manifests for all workloads
    - Query nuget.org until the manifests are available
    - Publish the workload set

## Additional Details

### Approvals

In the above steps, step 3 will require approval in GitHub. Additionally, steps 4.b, 4.c, 5, and 7 should each require approval in the workload staging pipeline (specifically any step that does publishing to feeds, NuGet, or VS should require an approval within the pipeline). The reason for this is so we can have the pipeline run automatically on all PRs but only publish the changes we want to. Workload partners may have changes they want to publish internally for testing but not go to NuGet or VS, teams may have changes they want to publish on NuGet.org but not publish to VS, etc.

Basically, everything should happen automatically once merged but we want to control whether we publish the workloads to the feeds, to VS, and to nuget.org so we don't publish by default.

### We have a preview workloads feed for each major version of .NET
- dotnet8-workloads https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet8-workloads/nuget/v3/index.json
- dotnet9-workloads https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet9-workloads/nuget/v3/index.json
