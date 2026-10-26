---
name: vs-workloads-monitor-build
description: Tracks workload build, insertion and publication outcomes and locates new or cumulative VS PRs.
---

# Monitor Workloads Builds and Insertions

## Inputs

Run IDs and the approved matrix: source SHAs, expected versions, workloads,
publication destinations and VS target roles.

## 1. Monitor each run

Inspect resources, parameters, timeline, attempts and relevant logs:

- Verify resolved `eng`/`source` SHAs and generated identities/versions.
- Insertion and Publish each depend on Build, not each other. A failed overall
  run may already have created a VS PR.
- Report approval waits separately from failures. AzDO/NuGet publishing share
  the `DotNet-SDK-Workloads` approval.
- Find the first failing task; later missing-artifact/SBOM errors may be secondary.

Poll about every 10-15 minutes and report meaningful changes. Approval waits
make fixed completion estimates unreliable.

## 2. Find insertion PRs

Use insertion logs for links and topic/target branches. Search active **and
completed** PRs in DevDiv's VS repository:
`a290117c-5a8a-40f7-bc2c-f14dbe3acf6d`.
The insertion author is `MicroBuildInsertionVS`
(`558012ed-704d-617d-868c-985c8dbc9b16`).

The default topic, `temp/DotNet-Cli/<target>/yyyy-MM`, accepts updates from
several builds/.NET versions. Match the latest iteration, target and drop URLs
to all contributions, not just the author, title or original build link.

For `TF401179`/existing-PR/no-change messages, verify the required update in the
PR or target; the message alone is not a pass. If `createVSInsertion=false`,
report insertion as not requested regardless of stale target parameters.

## 3. Validate and report

Use `vs-workloads-approve-pr` to validate contents and hand off to a person.
Report each run/stage and target PR with links, source SHA/PR iteration,
expected contribution, actual state and blockers. Keep publication results
separate from VS state.

Before recovery, inspect existing artifacts/PRs and stage attempts. Retry only
failed work where supported and authorized, not a whole run just to clear a
warning or check. Changed source/branding may need a new run; link the old one.
