---
name: vs-workloads-approve-pr
description: Validates and merges VS insertion PRs in DevDiv Azure DevOps. Use after insertion PRs are created to complete the workflow.
---

# Approve and Merge VS Insertion PR

## Inputs
- **prId**: DevDiv PR ID to process
- **autoMerge**: Set autocomplete (default: true)
- **validateContent**: Check file counts (default: true)

## Workflow

- [ ] Get PR details and verify validity
- [ ] Validate file count matches expectations
- [ ] Set autocomplete or merge
- [ ] Report completion

## Get PR Details

Use `azure-devops-devdiv-repo_get_pull_request_by_id`:
```json
{
  "repositoryId": "a290117c-5a8a-40f7-bc2c-f14dbe3acf6d",
  "pullRequestId": <prId>,
  "includeLabels": true
}
```

### Verify:
- `status` = 1 (Active)
- `mergeStatus` = 3 (No conflicts)
- `createdBy.displayName` = "MicroBuildInsertionVS"

## Validate Content
- **Primary PRs**: 10 files (2 × 5 workloads)
- **Secondary PRs**: 5 files (1 × 5 workloads)

## Set Autocomplete

Use `azure-devops-devdiv-repo_update_pull_request`:
```json
{
  "repositoryId": "a290117c-5a8a-40f7-bc2c-f14dbe3acf6d",
  "pullRequestId": <prId>,
  "autoComplete": true,
  "deleteSourceBranch": true,
  "mergeStrategy": "Squash"
}
```

## Output

| PR ID | Target | Action | Status |
|-------|--------|--------|--------|
| 704945 | 18.3-staging | Autocomplete | ✅ |
| 704926 | rel/insiders | Skip | ⏸️ User |

Link: `https://dev.azure.com/devdiv/DevDiv/_git/VS/pullrequest/<prId>`

## Key IDs
- **VS Repo**: `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`
- **DevDiv Project**: `0bdbc590-a062-4c3f-b0f6-9383f67865ee`

## Troubleshooting
- **mergeStatus ≠ 3**: Conflicts exist, needs manual resolution
- **Autocomplete not working**: Check required reviewers/policies
