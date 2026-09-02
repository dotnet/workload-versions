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
- [ ] Validate runtime and emsdk version coherency in dependency PRs
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
1. Inspect the PR diff before checking or approving it.
2. If the runtime minor/servicing version changes, verify that emsdk changes to the same version in that PR:
   - `Microsoft.NETCore.App.Ref` and `Microsoft.NET.Workload.Emscripten.Current.Manifest-*` in `eng/Version.Details.xml` must move together.
   - `MicrosoftNETCoreAppRefPackageVersion` and the corresponding `MicrosoftNETWorkloadEmscriptenCurrentManifest*PackageVersion` in `eng/Versions.props` must move together.
   - Example: runtime `8.0.30 -> 8.0.31` requires emsdk `8.0.30 -> 8.0.31`.
3. If runtime changes without the matching emsdk change, **do not approve, merge, or trigger the pipeline**. Report the mismatch and require a corrected dependency-flow PR.
4. Check status with `github-mcp-server-pull_request_read` (method: `get_status`).
5. Verify checks pass (ignore "placeholder" failures).
6. Check `mergeable_state`: `clean` = ready, `blocked` = needs approval.
7. Merge when ready.

## Verify Mirror Sync

Use `dnceng-azure-devops-repo_search_commits`:
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
- Runtime/emsdk coherency: ✓/✗
- PRs merged: Y  
- Mirror verified: ✓/✗
- Latest AzDO commit: `<sha>` - `<message>`
