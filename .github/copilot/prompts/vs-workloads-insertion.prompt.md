# VS Workloads Insertion

Follow the [Release Process](../../../doc/release-process.md) for monthly,
workload-only OOB or SDK-hotfix insertions. Use the focused skills below rather
than repeating their procedures.

## Workflow

| Step | Skill | Required result |
|------|-------|-----------------|
| 1. Plan | [workload-release-day](../../skills/workload-release-day/SKILL.md) | Confirmed release matrix: sources/builds, SDK outputs, branding, phases, publication and VS scope. Hotfix owner approval overrides monthly tracker inference. |
| 2. Prepare and verify | [vs-workloads-check-mirror](../../skills/vs-workloads-check-mirror/SKILL.md), using [workload-versions-check](../../skills/workload-versions-check/SKILL.md) | Approved final SHA, public or internal-only, with dependencies, upstream builds and feeds verified. |
| 3. Queue | [vs-workloads-trigger-pipeline](../../skills/vs-workloads-trigger-pipeline/SKILL.md) | Owner-confirmed settings; pipeline from `eng`, approved source SHA and exact workload/target subset. |
| 4. Monitor | [vs-workloads-monitor-build](../../skills/vs-workloads-monitor-build/SKILL.md) | Separate stage/publication results and links to new or cumulative VS PRs. |
| 5. Hand off | [vs-workloads-approve-pr](../../skills/vs-workloads-approve-pr/SKILL.md) | Latest PR contents/checks validated for a person to approve and merge. |

Ask for missing inputs before queuing. Carry the confirmed matrix, source SHA
and run/PR links between skills; do not infer normal monthly defaults for a
hotfix. Repeat source checks only if the source changes or evidence is incomplete.

## Handoff rules

- Do not approve, enable autocomplete or merge VS PRs. The pipeline itself sets
  `InsertAutoComplete: true`; disclose it before queuing and report the actual
  PR setting. This workflow does not enforce manual-only completion.
- Validate cumulative JSON entries/drop URLs, not file counts or just the
  original build title. Primary contributions include packs and (pre)components;
  secondary contributions include packs only.
- An existing-PR/no-change warning or failed Publish stage does not establish
  insertion success/failure. Verify actual PR/target state before retrying;
  never rerun the whole pipeline just to clear a warning or check.

Pipeline: https://dev.azure.com/dnceng/internal/_build?definitionId=1298
