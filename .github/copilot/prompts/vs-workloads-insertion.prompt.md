# VS Workloads Insertion

Prepare and validate .NET workload insertions using the authoritative
[Release Process](../../../doc/release-process.md). Support monthly, targeted
workload-only OOB and SDK-hotfix releases. End with a validated handoff for a
person to approve and merge VS PRs; never approve, enable autocomplete or merge.

## Focused Skills

| Skill | Responsibility |
|-------|----------------|
| `workload-release-day` | Approved release/output/phase matrix and publication plan |
| `vs-workloads-check-mirror` | Prepare/verify public mirrored or internal-only sources |
| `workload-versions-check` | Immutable dependency version, ID, feed and build-provenance checks |
| `vs-workloads-trigger-pipeline` | Confirm settings and queue approved VS insertions |
| `vs-workloads-monitor-build` | Independent stage monitoring and cumulative PR discovery |
| `vs-workloads-approve-pr` | Read-only semantic validation and human handoff |

Discover the installed GitHub, dnceng and DevDiv tool schemas before use.
Do not assume deprecated MCP operation aliases or guessed status enums.

## 1. Confirm the Release Matrix

Ask for missing information before queuing:

- Release mode/date and approving owner.
- Source repository/mode, branch, approved baseline if creating it, final SHA
  and upstream SDK/VMR/BAR build provenance.
- Every target SDK band and expected workload-set version/pattern, explicit SDK
  minor/feature/patch overrides, effective prerelease label/iteration and
  stabilize flag.
- Exact workload subset (`emsdk`, `mono`, `iOS`, `android`, `maui`).
- Per-output primary VS targets (packs and (pre)components) and secondary VS
  targets (**packs only**); either list can be empty.
- Validation/final phase, test-mode flag, AzDO feed/flag and NuGet flag.

For hotfixes, the release-owner-approved matrix supersedes next-Patch-Tuesday
lookup. Do not infer five builds, all workloads or normal monthly VS targets.
One source can produce multiple SDK-band outputs with different overrides.
Workload-only revisions such as `10.0.402.1` differ from SDK-hotfix outputs such
as `10.0.114`; `setVersionPatch` is not a runtime patch number.

## 2. Prepare and Verify Sources

Use `vs-workloads-check-mirror` and `workload-versions-check`.

For public sources, review the needed GitHub dependency PRs and verify the
authorized merge has mirrored to the internal repository. For internal-only
hotfixes, create the approved branch from the exact baseline when requested,
prepare dependency updates and internal Azure DevOps PRs, and verify the
resulting approved commit directly. No GitHub counterpart is required.

Review XML, properties and NuGet feeds together. Require coherent final
runtime/emsdk versions where they share a servicing line, while allowing
approved same-version SHA-only rebuilds. Validate upstream URI/SHA/BAR ID and
preserve unaffected workloads. Selective RC ID changes do not automatically
advance workload-set branding.

Do not automatically approve/merge dependency PRs or ignore failed policies.
Unverified provenance, mirror/source mismatch or ambiguous BAR build blocks
readiness.

## 3. Confirm and Queue

Use pipeline `1298`, project `dnceng/internal`, with pipeline resource
`refs/heads/eng` and separate `sourceBranch`. Pin the approved `source` resource
SHA when supported, then verify both resolved resource SHAs after queuing.

Use `vs-workloads-trigger-pipeline`; confirm the complete matrix first. Set
branding and target lists explicitly. Keep NuGet disabled for insertion-only
validation unless explicitly approved. Preview/RC final publication still
requires prerelease branding. `createTestWorkloadSet` is a special versioning
mode, not a requirement for release-candidate testing.

The current pipeline requests `InsertAutoComplete: true`. Disclose this before
queuing and identify the human reviewer. This workflow's read-only PR handoff
does not override that setting or enforce manual-only completion.

## 4. Monitor Independent Outcomes

Use `vs-workloads-monitor-build` for all matrix runs. Build precedes Insertion
and Publish, but those two stages are independent. Publication approval/checks
can wait or fail after a VS PR was created. Report stage attempts, first failing
task, approval state and actual publication results instead of assuming serial
stages or a fixed duration.

When VS insertion is disabled, stale drop/target parameters are inactive.

## 5. Reconcile Cumulative VS PRs

VS repository: `a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`, DevDiv.
Insertion author: `MicroBuildInsertionVS`
(`558012ed-704d-617d-868c-985c8dbc9b16`).

Use insertion logs and actual topic/target branches to find active or completed
PRs. The default monthly topic can accumulate several .NET versions and builds.
Do not match solely by author, title or original build link.

For existing-PR/no-change warnings, inspect the latest PR iteration and target
state. Verify the required contribution actually arrived; the warning alone
is not a pass or a reason to rerun the entire pipeline.

## 6. Validate and Hand Off

Use `vs-workloads-approve-pr` to validate selected workload/version entries,
drop URLs, expected primary/secondary role, all contributing build/source SHAs,
unaffected content and current policies. **Validate entries, not changed-file
counts**: many workloads can share one JSON file.

Report each run's source SHA, effective branding, stage/publication results,
PR link/iteration, verified cumulative contributions, blockers and actual
autocomplete state. A person approves and merges. If the PR changes after
validation, revalidate the new iteration before reporting readiness.

## Recovery

- Ambiguous SHA-to-BAR lookup: obtain the approved build ID and update explicit
  `BarId` through a reviewed source change, even if the dependency is outside
  the selected VS workload subset.
- Failed/partial run: inspect existing artifacts, PRs and stage attempts before
  retrying only the failed work when supported and authorized.
- Changed source/branding: confirm a revised matrix and track the replacement
  run; do not silently reuse stale output.
- Missing VS target: discover the actual branch and obtain owner confirmation
  rather than substituting a normal monthly branch.

Pipeline: https://dev.azure.com/dnceng/internal/_build?definitionId=1298
