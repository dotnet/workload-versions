$ErrorActionPreference = 'Stop'

function Assert-Equal {
  param($Expected, $Actual, [string] $Message)
  if ($Expected -ne $Actual) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function Assert-Throws {
  param([scriptblock] $Action, [string] $ExpectedMessage)
  try {
    & $Action | Out-Null
  }
  catch {
    if ($_.Exception.Message -notlike "*$ExpectedMessage*") {
      throw "Expected error containing '$ExpectedMessage', got '$($_.Exception.Message)'."
    }
    return
  }
  throw "Expected error containing '$ExpectedMessage'."
}

$template = Get-Content "$PSScriptRoot/../pipelines/templates/steps/esrp-nuget-publish.yml" -Raw
$match = [regex]::Match($template, '(?ms)^- pwsh: \|\r?\n(?<script>.*?)^  displayName:')
if (-not $match.Success) {
  throw 'Could not extract the checked-in ESRP staging script.'
}
$stageScript = [scriptblock]::Create(($match.Groups['script'].Value -replace '(?m)^    ', ''))

function Invoke-Staging {
  $output = @(& $stageScript 6>&1 3>&1)
  $result = @{}
  foreach ($line in $output) {
    if ([string] $line -match '^##vso\[task\.setvariable variable=([^\]]+)\](.*)$') {
      $result[$Matches[1]] = $Matches[2]
    }
  }
  $result
}

$environmentNames = @('PACKAGES_PATH', 'NUGET_ORGANIZATION', 'ESRP_OWNERS', 'ESRP_APPROVERS', 'RELEASE_REQUESTER', 'AGENT_TEMPDIRECTORY')
$savedEnvironment = @{}
foreach ($name in $environmentNames) {
  $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("esrp-staging-tests-" + [guid]::NewGuid().ToString('N'))

try {
  $env:PACKAGES_PATH = Join-Path $testRoot 'packages'
  $env:AGENT_TEMPDIRECTORY = Join-Path $testRoot 'temp'
  $shipping = Join-Path $env:PACKAGES_PATH 'shipping'
  $workloads = Join-Path $env:PACKAGES_PATH 'workloadNupkgs/nested'
  New-Item -ItemType Directory -Path $shipping, $workloads, $env:AGENT_TEMPDIRECTORY | Out-Null
  $setPackage = Join-Path $shipping 'Microsoft.NET.Workloads.1.0.0.nupkg'
  $workloadPackage = Join-Path $workloads 'Workload.1.0.0.nupkg'
  Set-Content -LiteralPath $setPackage -Value 'workload set fixture'
  Set-Content -LiteralPath $workloadPackage -Value 'downloaded workload fixture'
  Set-Content -LiteralPath (Join-Path $shipping 'Workload.1.0.0.snupkg') -Value 'symbols sidecar'
  Set-Content -LiteralPath (Join-Path $shipping 'expected-packages.json') -Value '{}'
  Set-Content -LiteralPath (Join-Path $shipping 'helper.ps1') -Value 'throw'
  $env:NUGET_ORGANIZATION = 'dotnetframework'
  $env:ESRP_OWNERS = ' Owner.One, owner-two@microsoft.com, OWNER.ONE@microsoft.com '
  $env:ESRP_APPROVERS = 'owner.one, REQUESTER@microsoft.com, Independent, independent@microsoft.com'
  $env:RELEASE_REQUESTER = ' Requester@MICROSOFT.COM '

  $result = Invoke-Staging
  Assert-Equal 'owner.one@microsoft.com,owner-two@microsoft.com' $result.EsrpResolvedOwners 'Owners were not normalized and deduplicated.'
  Assert-Equal 'independent@microsoft.com' $result.EsrpResolvedApprovers 'Approvers were not normalized, excluded and deduplicated.'
  $submission = $result.EsrpNuGetSubmissionPath
  Assert-Equal $env:AGENT_TEMPDIRECTORY (Split-Path $submission -Parent) 'Submission is not in the agent temp directory.'
  $stagedFiles = @(Get-ChildItem -LiteralPath $submission -File -Recurse)
  Assert-Equal 2 $stagedFiles.Count 'Only the two recursively selected nupkgs should be staged.'
  foreach ($file in $stagedFiles) {
    Assert-Equal $submission $file.DirectoryName 'Submission must be flat.'
    Assert-Equal '.nupkg' $file.Extension 'A sidecar was staged.'
  }
  Assert-Equal (Get-Content $setPackage -Raw) (Get-Content (Join-Path $submission (Split-Path $setPackage -Leaf)) -Raw) 'Workload set content changed.'
  Assert-Equal (Get-Content $workloadPackage -Raw) (Get-Content (Join-Path $submission (Split-Path $workloadPackage -Leaf)) -Raw) 'Downloaded workload content changed.'
  Assert-Equal $true (Test-Path -LiteralPath $setPackage) 'Staging modified the artifact.'
  $second = Invoke-Staging
  Assert-Equal $false ($submission -eq $second.EsrpNuGetSubmissionPath) 'Submissions must have unique directories.'

  $env:ESRP_APPROVERS = 'owner.one, requester'
  Assert-Throws { Invoke-Staging } 'neither a release owner nor the requester'
  foreach ($invalid in @('|default|', '', 'outside@example.com', 'alias,', 'first last')) {
    $env:ESRP_APPROVERS = $invalid
    Assert-Throws { Invoke-Staging } 'comma-separated individual Microsoft'
  }
  $env:ESRP_APPROVERS = 'independent'
  $env:ESRP_OWNERS = ''
  Assert-Throws { Invoke-Staging } 'comma-separated individual Microsoft'
  $env:ESRP_OWNERS = 'owner'
  foreach ($invalid in @('', 'requester@example.com', '$(Build.RequestedForEmail)')) {
    $env:RELEASE_REQUESTER = $invalid
    Assert-Throws { Invoke-Staging } 'requester must have an individual Microsoft email'
  }
  $env:RELEASE_REQUESTER = 'requester@microsoft.com'
  foreach ($invalid in @('', ' ', 'skip')) {
    $env:NUGET_ORGANIZATION = $invalid
    Assert-Throws { Invoke-Staging } 'organization onboarded to ESRP'
  }
  $env:NUGET_ORGANIZATION = 'dotnetframework'

  $duplicate = Join-Path $workloads (Split-Path $setPackage -Leaf)
  Copy-Item -LiteralPath $setPackage -Destination $duplicate
  Assert-Throws { Invoke-Staging } 'Duplicate NuGet package filenames'
  Remove-Item -LiteralPath $duplicate
  $env:PACKAGES_PATH = Join-Path $testRoot 'empty'
  New-Item -ItemType Directory -Path $env:PACKAGES_PATH | Out-Null
  Assert-Throws { Invoke-Staging } 'No NuGet packages remain'
  $env:PACKAGES_PATH = Join-Path $testRoot 'missing'
  Assert-Throws { Invoke-Staging } 'does not exist'

  $official = Get-Content "$PSScriptRoot/../pipelines/official.yml" -Raw
  if ($official -notmatch '(?s)- name: publishToNuGet\s+displayName:[^\r\n]+\s+type: boolean\s+default: false') {
    throw 'NuGet publication must remain opt-in.'
  }
  if ($official -match 'publishFeedCredentials|nuGetFeedType: external') {
    throw 'The legacy NuGet.org API-key publishing path must be removed.'
  }
  if ($official -notmatch 'publishVstsFeed: \$\{\{ parameters.azDOPublishFeed \}\}' -or
      $official -notmatch 'packagesToPush: \$\(System.DefaultWorkingDirectory\)/artifacts/packages/\*\*/\*\.nupkg') {
    throw 'The independent AzDO publishing path must remain unchanged.'
  }
  if ($official -notmatch '(?s)if eq\(parameters.publishToNuGet, true\).*?- template: /eng/pipelines/templates/steps/esrp-nuget-publish.yml@self') {
    throw 'ESRP must remain inside the opt-in NuGet publishing branch.'
  }
  foreach ($binding in @(
    'nugetOrganization: ${{ parameters.nugetOrganization }}',
    'serviceConnection: ${{ parameters.esrpServiceConnection }}',
    'owners: ${{ parameters.esrpOwners }}',
    'approvers: ${{ parameters.esrpApprovers }}'
  )) {
    if (-not $official.Contains($binding)) {
      throw "Missing ESRP caller binding: $binding"
    }
  }
  foreach ($buildTemplate in @('jobs/workload-build.yml', 'stages/workload-public-build.yml')) {
    $build = Get-Content "$PSScriptRoot/../pipelines/templates/$buildTemplate" -Raw
    if (-not $build.Contains('pwsh: eng/tests/EsrpNuGetPublish.Tests.ps1')) {
      throw "The offline ESRP test must run in $buildTemplate."
    }
  }
  foreach ($required in @(
    'task: EsrpRelease@14', 'usemanagedidentity: true', 'intent: PackageDistribution',
    'contenttype: NuGet', 'waitforreleasecompletion: true',
    'folderlocation: $(EsrpNuGetSubmissionPath)', 'owners: $(EsrpResolvedOwners)',
    'approvers: $(EsrpResolvedApprovers)'
  )) {
    if (-not $template.Contains($required)) {
      throw "Missing ESRP task setting: $required"
    }
  }
  Write-Host 'ESRP NuGet staging and pipeline wiring tests passed.'
}
finally {
  foreach ($name in $environmentNames) {
    [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name])
  }
  if (Test-Path -LiteralPath $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}
