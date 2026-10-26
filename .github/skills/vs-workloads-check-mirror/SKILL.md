---
name: vs-workloads-check-mirror
description: Prepares and verifies public mirrored or internal-only workload sources and dependency PRs before builds.
---

# Prepare and Verify Workload Sources

## Inputs

Confirm source mode (`public-mirror` or `internal-only`), branch and approved
SHA. If preparing a branch, also require the approved baseline SHA, upstream
builds and workload scope.

The build's internal repository is
`dnceng/internal/dotnet-workload-versions`.

## 1. Prepare changes, if requested

1. For a new internal-only branch, verify the baseline and create the branch at
   that SHA. Do not overwrite an existing branch.
2. Read the approved upstream SDK/VMR build manifest. Use
   `darc update-dependencies`; check its current help for selecting that build.
3. Review `eng/Version.Details.xml`, `eng/Versions.props` and `NuGet.config`
   together. Preserve unrelated dependencies and actual upstream version values.
4. Create the dependency PR in GitHub for public sources or Azure DevOps for
   internal-only sources. Report the diff/checks for owner review; do not
   automatically approve or merge.

Do not retarget monthly subscriptions for an isolated hotfix.

## 2. Verify the approved commit

- **Public mirror:** verify the authorized GitHub merge appears in internal
  branch history. Poll about every five minutes; report a blocker after the
  agreed timeout rather than build stale source.
- **Internal-only:** verify the approved commit and completed PR directly in
  Azure DevOps. No GitHub branch or mirror wait is required.

Run `workload-versions-check` at that SHA for dependency/feed checks, including
runtime/emsdk coherency and same-version rebuilds. If a SHA resolves to multiple
BAR builds, identify the approved build and add its `BarId` through a reviewed
update. Do not guess the ID, even for dependencies outside the VS subset.

Required checks/policies must pass; do not blanket-ignore "placeholder"
failures. Missing access, failed checks, dependency mismatches or a different
source SHA blocks readiness.

## Output

Report source mode/repository/branch, baseline/final SHA, PR links, upstream
build IDs, dependency-check results, mirror status (or `not applicable`) and
blockers. Pass the approved final SHA to the pipeline skill.
