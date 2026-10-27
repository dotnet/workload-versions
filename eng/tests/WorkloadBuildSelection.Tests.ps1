$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../WorkloadBuildSelection.psm1" -Force

function Assert-Equal {
  param($Expected, $Actual, [string] $Message)

  if ($Expected -ne $Actual) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function Assert-Throws {
  param([scriptblock] $Action, [string] $Pattern)

  try {
    & $Action
  }
  catch {
    if ($_.Exception.Message -notmatch $Pattern) {
      throw "Expected error matching '$Pattern', got '$($_.Exception.Message)'."
    }
    return
  }
  throw "Expected error matching '$Pattern'."
}

function New-Dependency {
  param([string] $Repository = 'https://github.com/dotnet/macios', [string] $BarId = '')

  [pscustomobject]@{
    Name = 'Microsoft.NET.Sdk.iOS.Manifest-10.0.100'
    Uri = $Repository
    Sha = 'test-commit'
    BarId = $BarId
  }
}

function New-Build {
  param([int] $Id, [string[]] $Channels = @(), [string] $Repository = 'https://github.com/dotnet/macios')

  [pscustomobject]@{
    id = $Id
    commit = 'test-commit'
    gitHubRepository = $Repository
    azureDevOpsBuildNumber = '20261016.4'
    channels = @($Channels | ForEach-Object { [pscustomobject]@{ name = $_ } })
  }
}

$global:workloadTestDarcCalls = [Collections.Generic.List[object]]::new()
$global:workloadTestDarcExitCode = 0
$global:workloadTestDarcOutput = '[]'
function global:Test-WorkloadDarc {
  $global:workloadTestDarcCalls.Add(@($args))
  $global:LASTEXITCODE = $global:workloadTestDarcExitCode
  $global:workloadTestDarcOutput
}

try {
  $dependency = New-Dependency -BarId '336957'
  Assert-Equal '336957' (Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc) 'Explicit IDs must win.'
  Assert-Equal 0 $global:workloadTestDarcCalls.Count 'Explicit IDs must not trigger a lookup.'

  $dependency = New-Dependency
  $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @(
    (New-Build 336963 @('.NET 10 Workload Release', '.NET 11 Workload Release'))
    (New-Build 336957 @('.NET 10.0.1xx SDK'))
  ) -Depth 5
  Assert-Equal 336963 (Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc) 'One candidate in any Workload channel must win.'
  $query = $global:workloadTestDarcCalls[0]
  Assert-Equal 'get-build' $query[0] 'Use the build query rather than parsing a gather error.'
  Assert-Equal $dependency.Uri $query[2] 'Query the dependency repository.'
  Assert-Equal $dependency.Sha $query[4] 'Query the exact commit.'

  foreach ($repo in @('https://github.com/dotnet/android', 'https://github.com/dotnet/maui', 'https://github.com/xamarin/xamarin-macios')) {
    $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @(
      (New-Build 1 @('.NET 9 Workload Release') $repo)
      (New-Build 2 @() $repo)
    ) -Depth 5
    Assert-Equal 1 (Resolve-WorkloadBarId (New-Dependency $repo) -Darc Test-WorkloadDarc) 'MAUI repository forms must use channel disambiguation.'
  }

  $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @((New-Build 3)) -Depth 5
  Assert-Equal 3 (Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc) 'A single build does not require channel membership.'
  $global:workloadTestDarcOutput = '[]'
  Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'Candidates: \(none\)'

  foreach ($channels in @(@('.NET 10.0.1xx SDK'), @('.NET 10 Workload Release'), @('Unrelated Workload Nightly'))) {
    $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @(
      (New-Build 1 $channels)
      (New-Build 2 $channels)
    ) -Depth 5
    Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'BAR ID 1.*BAR ID 2.*Version.Details.xml'
  }

  foreach ($repo in @('https://github.com/dotnet/runtime', 'https://github.com/dotnet/emsdk', 'https://dev.azure.com/dnceng/internal/_git/dotnet-dotnet')) {
    $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @(
      (New-Build 1 @('.NET 10 Workload Release') $repo)
      (New-Build 2 @() $repo)
    ) -Depth 5
    Assert-Throws { Resolve-WorkloadBarId (New-Dependency $repo) -Darc Test-WorkloadDarc } 'Cannot uniquely resolve.*release tracker'
    $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @((New-Build 1 @() $repo)) -Depth 5
    Assert-Equal 1 (Resolve-WorkloadBarId (New-Dependency $repo) -Darc Test-WorkloadDarc) 'Unambiguous non-MAUI builds must still work.'
  }

  $internalBuild = New-Build 4 @() ''
  $internalBuild | Add-Member azureDevOpsRepository 'https://dev.azure.com/dnceng/internal/_git/dotnet-runtime'
  $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @($internalBuild) -Depth 5
  Assert-Equal 4 (Resolve-WorkloadBarId (New-Dependency 'https://dnceng.visualstudio.com/internal/_git/dotnet-runtime') -Darc Test-WorkloadDarc) 'Equivalent Azure DevOps host names must remain supported.'

  $global:workloadTestDarcOutput = 'not json'
  Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'invalid build JSON'
  $global:workloadTestDarcOutput = '{"unexpected":42}'
  Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'invalid build record'
  $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @((New-Build 1 @() 'https://github.com/dotnet/maui')) -Depth 5
  Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'different repository'
  $wrongCommit = New-Build 1
  $wrongCommit.commit = 'another-commit'
  $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @($wrongCommit) -Depth 5
  Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'invalid build record'
  $global:workloadTestDarcExitCode = 1
  Assert-Throws { Resolve-WorkloadBarId $dependency -Darc Test-WorkloadDarc } 'lookup failed.*exit code 1'
  $global:workloadTestDarcExitCode = 0

  foreach ($repo in @('https://github.com/dotnet/maui', 'https://github.com/dotnet/android', 'https://github.com/dotnet/macios', 'https://github.com/xamarin/xamarin-macios')) {
    Assert-Equal $false (Test-WorkloadDependencyRequested (New-Dependency $repo) @('mono', 'emsdk')) 'Runtime-only requests must skip MAUI repositories.'
    Assert-Equal $true (Test-WorkloadDependencyRequested (New-Dependency $repo)) 'An empty workload list means all workloads.'
  }
  foreach ($repo in @('https://github.com/dotnet/dotnet', 'https://dev.azure.com/dnceng/internal/_git/dotnet-dotnet', 'https://dnceng.visualstudio.com/internal/_git/dotnet-dotnet')) {
    foreach ($workload in @('mono', 'emsdk')) {
      Assert-Equal $true (Test-WorkloadDependencyRequested (New-Dependency $repo) @($workload)) 'VMR dependencies can supply either runtime or emsdk.'
    }
  }
  Assert-Equal $true (Test-WorkloadDependencyRequested (New-Dependency 'https://example.invalid/unknown') @('mono')) 'Unknown repositories must not be silently skipped.'

  $testRoot = Join-Path ([IO.Path]::GetTempPath()) "workload-build-selection-$([Guid]::NewGuid())"
  $engPath = Join-Path $testRoot 'eng'
  $workloadPath = Join-Path $testRoot 'workloads'
  $null = New-Item $engPath, $workloadPath -ItemType Directory
  Copy-Item "$PSScriptRoot/../download-workloads.ps1", "$PSScriptRoot/../WorkloadBuildSelection.psm1" $engPath
  @'
<Dependencies><ProductDependencies>
  <Dependency Name="Microsoft.NET.Sdk.iOS.Manifest-10.0.100" Version="27.1.10018">
    <Uri>https://github.com/dotnet/macios</Uri><Sha>test-commit</Sha>
  </Dependency>
  <Dependency Name="Microsoft.NET.Sdk.tvOS.Manifest-10.0.100" Version="27.1.10018">
    <Uri>https://github.com/dotnet/macios</Uri><Sha>test-commit</Sha>
  </Dependency>
  <Dependency Name="Microsoft.NET.Sdk.Maui.Manifest-10.0.100" Version="10.0.110">
    <Uri>https://github.com/dotnet/maui</Uri><Sha>another-commit</Sha>
  </Dependency>
</ProductDependencies></Dependencies>
'@ | Set-Content (Join-Path $engPath 'Version.Details.xml')

  $global:workloadTestDarcOutput = ConvertTo-Json -InputObject @(
    (New-Build 336963 @('.NET 10 Workload Release'))
    (New-Build 336957)
  ) -Depth 5
  $global:workloadTestDarcCalls.Clear()
  $global:workloadTestFailGather = ''
  function global:darc {
    $arguments = @($args | ForEach-Object { $_ })
    if ($arguments[0] -eq 'get-build') {
      Test-WorkloadDarc @arguments
      return
    }

    $global:workloadTestDarcCalls.Add($arguments)
    $filter = $arguments[[Array]::IndexOf($arguments, '--asset-filter') + 1]
    if ($global:workloadTestFailGather -eq 'all' -or ($global:workloadTestFailGather -eq 'packages' -and $filter -eq '^[^/]+$')) {
      $global:LASTEXITCODE = 1
      return
    }
    $global:LASTEXITCODE = 0
    $outputPath = $arguments[[Array]::IndexOf($arguments, '--output-dir') + 1]
    $null = New-Item $outputPath -ItemType Directory -Force
    $fileName = 'Workload.VSDrop.iOS.net.10.0-10.0.100.packs.zip'
    if ($filter -eq '^[^/]+$') {
      $fileName = 'test-workload.nupkg'
    }
    [IO.File]::WriteAllText((Join-Path $outputPath $fileName), 'test asset')
  }

  try {
    & (Join-Path $engPath 'download-workloads.ps1') -workloadPath $workloadPath -workloadListJson '["iOS"]' -downloadWorkloadNupkgs $true
    Assert-Equal 3 $global:workloadTestDarcCalls.Count 'Deduplicate manifests and skip unrelated repositories before gathering ZIPs and packages.'
    foreach ($gather in @($global:workloadTestDarcCalls[1], $global:workloadTestDarcCalls[2])) {
      Assert-Equal 'gather-drop' $gather[0] 'Both downloads must gather by the resolved build.'
      Assert-Equal 336963 $gather[[Array]::IndexOf($gather, '--id') + 1] 'ZIPs and packages must share the selected BAR ID.'
      Assert-Equal $false ($gather -contains '--repo') 'Do not repeat an ambiguous repo/commit lookup.'
    }

    $global:workloadTestDarcCalls.Clear()
    $global:workloadTestFailGather = 'all'
    Assert-Throws {
      & (Join-Path $engPath 'download-workloads.ps1') -workloadPath $workloadPath -workloadListJson '["iOS"]'
    } 'workload download failed.*336963'
    Assert-Equal 2 $global:workloadTestDarcCalls.Count 'A failed gather must stop downloading immediately.'

    $global:workloadTestDarcCalls.Clear()
    $global:workloadTestFailGather = 'packages'
    $freshWorkloadPath = Join-Path $testRoot 'package-failure'
    $null = New-Item $freshWorkloadPath -ItemType Directory
    Assert-Throws {
      & (Join-Path $engPath 'download-workloads.ps1') -workloadPath $freshWorkloadPath -workloadListJson '["iOS"]' -downloadWorkloadNupkgs $true
    } 'package download failed.*336963'
    Assert-Equal 3 $global:workloadTestDarcCalls.Count 'Package failures must propagate after successful ZIP gathering.'

    $fixture = [xml](Get-Content (Join-Path $engPath 'Version.Details.xml') -Raw)
    foreach ($entry in $fixture.Dependencies.ProductDependencies.Dependency | Select-Object -First 2) {
      $entry.SetAttribute('BarId', '336957')
    }
    $fixture.Save((Join-Path $engPath 'Version.Details.xml'))
    $global:workloadTestDarcCalls.Clear()
    $global:workloadTestFailGather = ''
    & (Join-Path $engPath 'download-workloads.ps1') -workloadPath $workloadPath -workloadListJson '["iOS"]'
    Assert-Equal 1 $global:workloadTestDarcCalls.Count 'Repeated explicit IDs must be gathered once without a query.'
    $gather = $global:workloadTestDarcCalls[0]
    Assert-Equal 336957 $gather[[Array]::IndexOf($gather, '--id') + 1] 'The explicit ID must override channel selection.'

    $fixture.Dependencies.ProductDependencies.Dependency[1].SetAttribute('BarId', '336963')
    $fixture.Save((Join-Path $engPath 'Version.Details.xml'))
    $global:workloadTestDarcCalls.Clear()
    & (Join-Path $engPath 'download-workloads.ps1') -workloadPath $workloadPath -workloadListJson '["iOS"]'
    Assert-Equal 2 $global:workloadTestDarcCalls.Count 'Distinct explicit IDs for the same commit must remain distinct.'
    Assert-Equal 2 @($global:workloadTestDarcCalls | ForEach-Object { $_[[Array]::IndexOf($_, '--id') + 1] } | Select-Object -Unique).Count 'Both explicit IDs must be gathered.'
  }
  finally {
    Remove-Item Function:\darc
    Remove-Variable workloadTestFailGather -Scope Global
    Remove-Item $testRoot -Recurse -Force
  }

  Write-Host 'Workload build selection tests passed.'
}
finally {
  Remove-Item Function:\Test-WorkloadDarc
  Remove-Variable workloadTestDarcCalls, workloadTestDarcExitCode, workloadTestDarcOutput -Scope Global
}
