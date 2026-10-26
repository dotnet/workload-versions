---
name: vs-workloads-check-mirror
description: Prepares and verifies public mirrored or internal-only workload sources, including hotfix branches and dependency PRs, before workload builds or VS insertion.
---

# Prepare and Verify Workload Sources

Follow the source-preparation section of the
[Release Process](../../../doc/release-process.md).

## Inputs

- **sourceMode**: `public-mirror` or `internal-only`, explicitly approved.
- **sourceBranch**, **expectedCommit**: authoritative branch and approved SHA.
- **prepareBranch**: whether to create/update a source, rather than just consume it.
- **baselineCommit**, **upstreamBuilds**, **dependencyScope**: required when
  preparing a branch; approved baseline, SDK/VMR/BAR provenance and workloads.

Discover installed GitHub/Azure DevOps tool schemas before using them; do not
assume old operation aliases. GitHub CLI is also suitable for public PRs.
The internal source repository is `dnceng/internal/dotnet-workload-versions`.

## Prepare a Source

1. Confirm the source mode, branch, baseline and dependency builds with the owner.
   Do not silently substitute current branch heads or the newest tracker build.
2. If creating an internal-only branch, resolve and verify the approved baseline
   SHA in the internal repository, check whether the branch already exists, then
   create it from that SHA. Never reset or overwrite an existing branch.
3. Read the selected upstream build's dependency manifest/provenance and use
   dependency-flow tooling (DARC) to prepare the update. Consult the installed
   tool's help/schema for the update operation and build selector.
4. Review `eng/Version.Details.xml`, `eng/Versions.props` and `NuGet.config`
   together. Update version properties, IDs, URI, SHA, explicit BAR ID and feeds
   coherently; preserve unrelated dependencies and upstream version values.
5. Create the dependency PR in the authoritative repository: GitHub for public
   sources, Azure DevOps for internal-only sources. Report its diff, checks and
   provenance for owner review. Do not automatically approve or merge; use the
   normal authorized review/merge process and verify the resulting commit.

Preparing an isolated RC hotfix does not require retargeting normal monthly
subscriptions. Selective mono/emsdk ID transitions may leave mobile/MAUI IDs at
the previous RC.

## Validate the Final Commit

Use `workload-versions-check` against the resulting immutable SHA, not just a PR
diff or branch head. For servicing lines using runtime and emsdk versions,
require matching versions in the final XML and corresponding properties.

A runtime version change must have the matching emsdk version in the resulting
source. A legitimate same-version runtime rebuild can change its SHA/feed and
SDK provenance without changing emsdk. Validate the approved upstream build;
do not require every individual PR to change both dependencies or identical
SHAs across different repositories.

If DARC finds several BAR builds for one SHA, stop and identify the approved
build. Add the verified `BarId` to the applicable dependencies through a reviewed
update. Even a narrow workload-drop selection can resolve other dependencies.
Do not guess a BAR ID or treat downstream missing-artifact errors as root cause.

## Resolve the Internal Source

- **Public mirror:** verify the authorized GitHub merge and check internal
  branch history for that exact commit. Poll at reasonable intervals (for
  example five minutes); after an agreed timeout report the mirror blocker
  rather than queuing stale source.
- **Internal-only:** verify the approved commit and completed dependency PR
  directly in Azure DevOps. Do not search for a required GitHub counterpart or
  wait for a mirror that does not apply.

Check required policies and checks rather than blanket-ignoring failures named
"placeholder". Missing permissions, failed checks, an unresolved dependency
mismatch, or a different final SHA blocks readiness.

## Output

Report source mode/repository/branch, baseline and final SHA, dependency PR links,
upstream build IDs, coherency/feed/BAR validation, mirror status or
`not applicable`, and remaining blockers. Pass this exact final SHA to the
pipeline skill.
