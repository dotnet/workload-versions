---
name: vs-workloads-monitor-build
description: Monitors a running workloads pipeline build and finds resulting VS insertion PRs in DevDiv. Use after triggering pipeline to track progress.
---

# Monitor VS Workloads Build

## Inputs
- **buildId**: The dnceng build ID to monitor
- **targetBranches**: VS branches to find PRs for

## Workflow

- [ ] Poll build status every 10-15 min
- [ ] Wait for VS Insertion stage (~90 min)
- [ ] Search for insertion PRs in DevDiv
- [ ] Match PRs to expected target branches
- [ ] Report findings

## Check Build Status

Use `dnceng-azure-devop-pipelines_get_build_status`:
```json
{
  "project": "internal",
  "buildId": <buildId>
}
```

**Stages**: Build Repo → SDL → Publish Assets → VS Insertion

**Total time**: ~100-110 minutes

## Find VS Insertion PRs

Use `azure-devops-devdiv-repo_list_pull_requests_by_repo_or_project`:
```json
{
  "repositoryId": "a290117c-5a8a-40f7-bc2c-f14dbe3acf6d",
  "created_by_user": "MicroBuildInsertionVS",
  "status": "Active"
}
```

Match PRs by:
- Title contains build number (e.g., `eng:20260202.1`)
- `targetRefName` matches expected branches

## Expected File Counts
- **Primary branch**: 10 files (2 per workload × 5)
- **Secondary branch**: 5 files (1 per workload × 5)

## Output

| PR ID | Target Branch | Build | Link |
|-------|---------------|-------|------|
| 704945 | rel/insiders | 20260202.1 | [Link](url) |

## Key IDs
- **VS Repo**: `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`
- **MicroBuildInsertionVS**: `558012ed-704d-617d-868c-985c8dbc9b16`

## Notes
"Active pull request already exists" warnings are **normal** when multiple builds target same branches.
