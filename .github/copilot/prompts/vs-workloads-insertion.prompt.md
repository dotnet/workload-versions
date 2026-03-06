# VS Workloads Insertion

Guide the user through preparing and executing a workloads insertion into Visual Studio.

## Related Skills

This workflow can be executed using these focused skills in `skills/`:

| Skill | Purpose |
|-------|---------|
| `vs-workloads-check-mirror` | Check GitHub PRs and verify mirror sync |
| `vs-workloads-trigger-pipeline` | Trigger the CI pipeline with correct parameters |
| `vs-workloads-monitor-build` | Monitor build progress and find insertion PRs |
| `vs-workloads-approve-pr` | Validate and merge VS insertion PRs |

## Overview

This prompt helps automate the process of inserting .NET workloads (maui, iOS, Android, emsdk, mono) into Visual Studio branches. The process involves:
1. Checking for pending PRs in the workload-versions GitHub repo
2. Running the workloads CI pipeline in dnceng Azure DevOps
3. Monitoring for VS insertion PRs in DevDiv Azure DevOps
4. Validating and approving the VS insertion PRs

## Key Information

### Pipeline Details
- **Pipeline ID**: 1298
- **Pipeline Name**: `dotnet-workload-versions-official-ci`
- **Project**: `internal` (dnceng Azure DevOps)
- **Pipeline Branch**: Always run from `refs/heads/eng` branch
- **Source Branch Parameter**: User specifies (e.g., `release/10`, `release/9.0.1xx`)

### Workloads (5 total)
- maui
- iOS
- Android
- emsdk
- mono

### VS Repository (DevDiv)
- **Repository ID**: `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`
- **Repository Name**: VS
- **Project**: DevDiv
- **Project ID**: `0bdbc590-a062-4c3f-b0f6-9383f67865ee`

### VS Insertion PR Author
- **User**: `MicroBuildInsertionVS`
- **GUID**: `558012ed-704d-617d-868c-985c8dbc9b16`

### Common VS Insertion Branch Patterns
- `rel/insiders` - VS Insiders branch
- `main` - VS main branch
- `team/dotnetdevexcli/insertion/sdk/rel/d{version}_{buildId}` - SDK staging branches
- `team/dotnetdevexcli/insertion/sdk/main_{buildId}` - Main staging branches

## Workflow Steps

### Step 1: Gather User Input
Ask the user for:
1. **Source branch** from workload-versions repo (e.g., `release/10`, `release/9.0.1xx`)
2. **Workloads to insert** (default: all 5 - maui, iOS, Android, emsdk, mono)
3. **VS target branches** - which branches to insert into
4. **Primary vs Secondary** - Primary branches get 2 sets of changes per workload (pack + component), secondary get 1

### Step 2: Check GitHub PRs
Check for open PRs in `dotnet/workload-versions` targeting the source branch:
- Use `github-mcp-server-list_pull_requests` with `base` filter
- If PRs exist that are needed, check their status, approve if green, and merge
- Wait for changes to mirror to dnceng AzDO (typically a few minutes)

### Step 3: Verify Mirror Status
Check that the source branch is mirrored to dnceng Azure DevOps:
- Use `dnceng-azure-devop-repo_search_commits` to verify latest commits are present
- Repository: `dotnet-workload-versions`, Project: `internal`
- **Poll every 5 minutes** until the expected commit appears (typically takes 2-10 minutes)

### Step 4: Find VS Insertion Branches (if needed)
If user needs to find available VS branches:
- Use `azure-devops-devdiv-repo_list_branches_by_repo` with repository ID `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`
- Filter patterns: `team/dotnetdevexcli/insertion/sdk`, `rel/insiders`, `main`

### Step 5: Run the Pipeline
Queue the workloads CI pipeline with correct parameters:

```
Tool: dnceng-azure-devop-pipelines_run_pipeline
Parameters:
  - project: "internal"
  - pipelineId: 1298
  - resources: {"pipelines": {}, "repositories": {"self": {"refName": "refs/heads/eng"}}}
  - templateParameters:
      - sourceBranch: "<user-specified branch, e.g., release/10>"
      - publishToAzDO: "true"
      - createVSInsertion: "true"
      - workloadDropNames: "- maui\n- iOS\n- Android\n- emsdk\n- mono"
      - primaryVsInsertionBranches: "- <branch1>\n- <branch2>"  # Branches with 2 changes per workload
      - secondaryVsInsertionBranches: "[]"  # Or list of branches with 1 change per workload
```

**IMPORTANT**: 
- The pipeline MUST run from `refs/heads/eng` branch (use `resources.repositories.self.refName`)
- `primaryVsInsertionBranches` = branches that get BOTH pack and component updates (2 changes per workload)
- `secondaryVsInsertionBranches` = branches that get only component updates (1 change per workload)
- Branch lists use YAML array format with `- ` prefix and `\n` separators

### Step 6: Monitor Build
The build typically takes **~100-110 minutes** to complete:
- Use `dnceng-azure-devop-pipelines_get_build_status` to check progress
- Build ID is returned when pipeline is queued
- Key stages: Build Repo → SDL → Publish Assets → VS Insertion
- Poll every 10-15 minutes during the build

### Step 7: Check for VS Insertion PRs
After the build's VS Insertion stage starts (~90+ minutes), PRs are created in DevDiv:
- Use `azure-devops-devdiv-repo_list_pull_requests_by_repo_or_project`
- Filter by `created_by_user` with MicroBuildInsertionVS or search by target branch
- PRs will target the branches specified in the pipeline parameters
- **Note**: You may see "TF401179: An active pull request already exists" warnings in build logs - this is **normal** when multiple builds target the same branches simultaneously

### Step 8: Validate VS PR Content
For each VS insertion PR:
- **Primary branch PRs**: Expect 2 file changes per workload (pack entry + component entry)
- **Secondary branch PRs**: Expect 1 file change per workload
- Check PR description links back to the originating pipeline build
- Use `azure-devops-devdiv-repo_get_pull_request_by_id` for details

### Step 9: Approve and Merge VS PRs
Once validated:
- Approve the PR
- Set autocomplete or merge directly
- Use `azure-devops-devdiv-repo_update_pull_request` to manage PR state

## Example Execution

User request: "Insert all workloads from release/10 into rel/insiders and main as primary branches"

Pipeline parameters:
```json
{
  "sourceBranch": "release/10",
  "publishToAzDO": "true",
  "createVSInsertion": "true",
  "workloadDropNames": "- maui\n- iOS\n- Android\n- emsdk\n- mono",
  "primaryVsInsertionBranches": "- rel/insiders\n- main",
  "secondaryVsInsertionBranches": "[]"
}
```

## Reference Documentation
- Release process: https://github.com/dotnet/workload-versions/blob/main/doc/release-process.md
- Pipeline: https://dev.azure.com/dnceng/internal/_build?definitionId=1298

## Multi-Insertion Scenarios

It's common to run multiple insertion builds simultaneously for different SDK versions. For example:

| Build | Source Branch | Primary Branches | Secondary Branches |
|-------|--------------|------------------|-------------------|
| 1 | release/10 | 18.3-staging, rel/insiders, main | [] |
| 2 | release/9.0.1xx | [] | rel/insiders, main |
| 3 | release/8.0.4xx | [] | rel/insiders, main |

**Tips for multi-insertion:**
- Trigger all builds in parallel to save time (each takes ~100 minutes)
- Track build IDs separately for each insertion
- Some builds may show "active pull request exists" warnings - this is normal
- Monitor all builds and validate PRs as they complete

## Skill vs Prompt Considerations

This prompt provides **reference documentation** for the VS workloads insertion workflow. For fully automated execution with:
- Automatic polling and state management
- Multi-build orchestration
- Conditional PR approval logic

Consider creating a **skill** that can maintain state across the ~2 hour workflow and handle edge cases automatically. The prompt remains valuable as documentation and for guided manual execution.

## Troubleshooting

### Pipeline fails to start
- Ensure you're specifying `resources.repositories.self.refName: "refs/heads/eng"` - the pipeline YAML only exists on the eng branch

### Build cancelled or needs to be restarted
- Use `dnceng-azure-devop-pipelines_update_build_stage` with `status: "Cancel"` and stage name `__default`
- Queue a new build with corrected parameters

### GitHub PR blocked
- If `mergeable_state` shows "blocked", the PR likely needs approval
- Use `github-mcp-server-pull_request_read` with `method: "get_status"` to check CI status
- A "placeholder" or required check that shows as "failure" is often expected - check if it's actually blocking

### Multiple builds targeting same branches
- When running multiple insertion builds (e.g., different SDK versions), some may show "active pull request already exists" warnings
- This is **expected behavior** - only one PR can exist per source→target branch combination
- PRs are updated or created based on the order builds complete

### Can't find VS insertion branches
- Search for `team/dotnetdevexcli/insertion/sdk` pattern
- Common direct branches: `rel/insiders`, `main`, `rel/d{version}`
