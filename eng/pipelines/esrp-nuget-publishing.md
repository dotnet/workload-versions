# Official NuGet publishing

The `eng` branch's `official.yml` builds and signs the selected `sourceBranch`,
then publishes its `Artifacts` pipeline artifact. NuGet.org publishing uses the
ESRP Release process ported from dotnet/maui commit
`56741504f9432a6284e80cb1685ae50cd95dd37c` on
`mattleibow-nuget-publishing-diagnostics`. That implementation is also present
on the inspected MAUI `main` commit
`c7e8239c3c0e40b9f65ce0ea5cd4782b780119bc`; the publishing files have no
tip-to-tip differences.

`publishToNuGet` remains `false` by default. When enabled, the existing
`DotNet-SDK-Workloads` environment gate still protects the production deployment.
ESRP's approval workflow is additional to that gate. `publishToAzDO` retains its
existing `1ES.PublishNuget@1` task and feed parameter.

## Release parameters

| Parameter | Default | Requirement |
|---|---|---|
| `nugetOrganization` | `dotnetframework` | An ESRP-onboarded NuGet organization owning every selected package; verify ownership, including optional workload packages. |
| `esrpServiceConnection` | `DotNetBuildESRP` | An authorized ESRP service connection supporting managed identity. |
| `esrpOwners` | `$(Build.RequestedForEmail)` | Comma-separated individual Microsoft aliases or email addresses. |
| `esrpApprovers` | `\|default\|` | Must be replaced with destination-team approvers; no MAUI team defaults are copied. At least one approver must be neither an owner nor the requester. |

Aliases are trimmed, lowercased and expanded to `@microsoft.com`. Owners and the
requester are excluded from approvers with a warning. A requester without an
individual Microsoft email address is rejected. Format validation does not
establish directory membership or rule out distribution lists.

## Package and authentication boundaries

The step template recursively selects `artifacts/packages/**/*.nupkg`, preserving
the previous publishing scope, including workload packages selected by
`downloadWorkloadNupkgs`, `workloadDropNames`, `workloadNupkgExcludeList` and
`includeNonShippingWorkloads`. It copies those packages into a unique, flat
directory under `Agent.TempDirectory`. Empty selections and duplicate filenames
fail before submission; helper scripts, JSON manifests, `.snupkg` and other sidecars are not
submitted. The downloaded artifact is not modified, so the AzDO publication
continues to use the original packages.

Unlike MAUI's BAR-based release preparation, this pipeline already has a signed
build artifact. It does not import MAUI's repository inference, pack/manifest
stages, already-published-package filtering, recovery skip lists, or NuGet
availability polling. Every selected package is submitted; ESRP must complete
successfully. Operators must verify public availability afterward.
The staging and ESRP steps share the deployment job; submission runs only after
successful staging. There is no upstream filtering or `NuGetPackagesToPublish`
skip variable, so missing packages fail rather than silently skipping publication.

The template's vault, authentication-signing certificate, client and tenant
defaults are the source's .NET ESRP configuration, not credentials or evidence
of destination authorization. They are template parameters so they can be
adapted if the destination requires a different configuration. ESRP performs
distribution, not package signing; the existing real-signing build is unchanged.
The old `nuget.org (dotnetframework)` API-key service connection is no longer
used for NuGet.org publication. No proxy environment values are logged.

## Prerequisites and manual validation

Before enabling NuGet.org publication, confirm that `EsrpRelease@14` is available
in the destination project, the pipeline is authorized to use the selected ESRP
service connection, and its managed identity can use the configured
`DotNetEngKeyVault` / `DotNet-ESRP-AuthSignCert` authentication configuration.
Verify the client and tenant configuration, ESRP organization onboarding,
package ownership, participant eligibility, and agent access to ESRP and its
authentication dependencies. The source YAML does not provision these services.

First queue a build with `publishToNuGet: false` and inspect the signed packages
and optional workload selection in `Artifacts`. For an approved release, queue
with `publishToNuGet: true`, supply independent destination approvers, review the
environment approval and staged package count, complete ESRP approvals, and
confirm task completion and public NuGet.org availability. The publishing job
allows 90 minutes, including ESRP completion; keep approvals within that limit.
Exercise AzDO-only and combined publication as appropriate. Do not treat a
non-publishing build as proof of ESRP authorization or successful distribution.

The offline staging regression test is
`pwsh -NoProfile -File eng/tests/EsrpNuGetPublish.Tests.ps1`. It does not contact
ESRP, authenticate, sign packages, or publish anything. Both public and official
builds run it after the `eng` checkout is overlaid on the source checkout.
