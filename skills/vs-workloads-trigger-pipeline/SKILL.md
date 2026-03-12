---
name: vs-workloads-trigger-pipeline
description: Triggers the dotnet-workload-versions-official-ci pipeline for VS insertion. Use to start a VS workloads insertion build. For release day (NuGet publishing), use workload-release-day skill instead.
---

# Trigger VS Workloads Pipeline (VS Insertion)

> **Note**: This skill is for **VS insertion** workflows. For Patch Tuesday release day workload sets that publish to NuGet.org (without VS insertion), use the `workload-release-day` skill instead.

## Inputs
- **sourceBranch**: Workload-versions branch (e.g., `release/10`)
- **primaryVsInsertionBranches**: Branches getting 2 changes per workload
- **secondaryVsInsertionBranches**: Branches getting 1 change per workload

## Workflow

- [ ] Validate inputs and branch names
- [ ] Trigger pipeline 1298 with correct parameters
- [ ] Report build ID and link

## Execute

Use `dnceng-azure-devop-pipelines_run_pipeline`:

```json
{
  "project": "internal",
  "pipelineId": 1298,
  "resources": {
    "pipelines": {},
    "repositories": {"self": {"refName": "refs/heads/eng"}}
  },
  "templateParameters": {
    "sourceBranch": "<user-specified>",
    "publishToAzDO": "true",
    "createVSInsertion": "true",
    "workloadDropNames": "- maui\n- iOS\n- Android\n- emsdk\n- mono",
    "primaryVsInsertionBranches": "- branch1\n- branch2",
    "secondaryVsInsertionBranches": "[]"
  }
}
```

## Critical Notes

1. **Pipeline branch**: MUST use `refs/heads/eng` in resources
2. **Branch format**: YAML array with `- ` prefix and `\n` separators
3. **Empty arrays**: Use `"[]"`
4. **Build duration**: ~100-110 minutes

## Output

Report:
- Build ID: `<id>`
- Link: `https://dev.azure.com/dnceng/internal/_build/results?buildId=<id>`

## Example

Input: "release/10 to rel/insiders and main as primary"

```json
{
  "templateParameters": {
    "sourceBranch": "release/10",
    "primaryVsInsertionBranches": "- rel/insiders\n- main",
    "secondaryVsInsertionBranches": "[]"
  }
}
```
