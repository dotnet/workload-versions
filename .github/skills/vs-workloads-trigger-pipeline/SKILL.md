---
name: vs-workloads-trigger-pipeline
description: Queues VS insertions with approved source, branding, workload subset and primary/secondary targets, including internal-only hotfixes.
---

# Trigger a VS Workloads Insertion

## Before queuing

Use the approved matrix from `workload-release-day` and source SHA verified by
`vs-workloads-check-mirror`. Confirm:

- Expected version and explicit branding overrides.
- Selected `workloadDropNames`: a subset of `emsdk`, `mono`, `iOS`, `android`, `maui`.
- Primary targets: packs and (pre)components; secondary targets: **packs only**.
  Set both lists explicitly; either may be empty, but do not assign both roles
  to the same target in one run.
- AzDO feed/flag, test mode and NuGet flag. Keep NuGet off for validation unless
  the owner explicitly approves publication.

Confirm actual target branches and the complete settings with the owner.
The pipeline sets `InsertAutoComplete: true`: disclose this and identify the
human reviewer. The skill does not approve or merge; manual-only enforcement
requires a separate pipeline/policy change.

## Queue

Use pipeline `1298` in `dnceng/internal` and the
[request format](../workload-release-day/SKILL.md#queue-pipeline-1298).
Keep the approved source pin and branding; set these additional/replacement
parameters from the matrix:

```json
{
  "templateParameters": {
    "createVSInsertion": true,
    "workloadDropNames": "- emsdk\n- mono",
    "primaryVsInsertionBranches": "- <approved-primary-target>",
    "secondaryVsInsertionBranches": "[]"
  }
}
```

The example selects mono/emsdk only. Replace it with the approved subset, not
all workloads by default. Follow the tool's list format: YAML strings use
`- ` prefixes/newline separators, and `[]` for empty lists.

Verify both resolved resource SHAs; a source-SHA mismatch blocks acceptance.
Pass the run ID/link, SHAs, parameters, expected version and target/role matrix
to `vs-workloads-monitor-build`.
