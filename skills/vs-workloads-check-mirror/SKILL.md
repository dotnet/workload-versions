---
name: vs-workloads-check-mirror
description: Checks for pending GitHub PRs on workload-versions branch and verifies mirror sync to Azure DevOps. Use before triggering VS workloads insertion pipeline.
---

# Check GitHub PRs and Mirror Sync

## Inputs
- **sourceBranch**: Branch to check (e.g., `release/10`)
- **expectedCommit** (optional): Specific commit SHA to wait for

## Workflow

- [ ] Check open PRs on GitHub targeting sourceBranch
- [ ] If PRs need merging: verify checks, approve, merge
- [ ] Poll dnceng AzDO every 5 min until commit mirrors
- [ ] Report when ready for pipeline trigger

## Check Open PRs

Use `github-mcp-server-list_pull_requests`:
```json
{
  "owner": "dotnet",
  "repo": "workload-versions", 
  "base": "<sourceBranch>",
  "state": "open"
}
```

### If PRs exist:
1. Check status with `github-mcp-server-pull_request_read` (method: `get_status`)
2. Verify checks pass (ignore "placeholder" failures)
3. Check `mergeable_state`: `clean` = ready, `blocked` = needs approval
4. Merge when ready

## Verify Mirror Sync

Use `dnceng-azure-devop-repo_search_commits`:
```json
{
  "project": "internal",
  "repository": "dotnet-workload-versions",
  "version": "<sourceBranch>",
  "top": 5
}
```

**Polling**: Every 5 min, typical sync 2-10 min, max wait 30 min.

## Output

Report:
- Open PRs found: X
- PRs merged: Y  
- Mirror verified: ✓/✗
- Latest AzDO commit: `<sha>` - `<message>`
