$ErrorActionPreference = 'Stop'

$darcCalls = [Collections.Generic.List[object]]::new()
function darc {
  param([string[]] $Arguments)

  $darcCalls.Add($Arguments)
  $outputPath = $Arguments[([Array]::IndexOf($Arguments, '--output-dir') + 1)]
  $assetFilter = $Arguments[([Array]::IndexOf($Arguments, '--asset-filter') + 1)]
  if ($assetFilter -eq '^[^/]+$') {
    New-Item -Path (Join-Path $outputPath 'test.nupkg') -ItemType File -Force | Out-Null
  }
  else {
    New-Item -Path (Join-Path $outputPath "Workload.VSDrop.test.$($darcCalls.Count).zip") -ItemType File | Out-Null
  }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) "download-workloads-tests-$([Guid]::NewGuid())"
try {
  New-Item -Path $testRoot -ItemType Directory | Out-Null
  $scriptPath = Join-Path $testRoot 'download-workloads.ps1'
  Copy-Item "$PSScriptRoot\..\download-workloads.ps1" $scriptPath
  Set-Content -Path (Join-Path $testRoot 'Version.Details.xml') -Value @'
<Dependencies>
  <ProductDependencies>
    <Dependency Name="Test.Workload" Version="1.0.0">
      <Uri>https://example.invalid/test</Uri>
      <Sha>test-commit</Sha>
    </Dependency>
  </ProductDependencies>
</Dependencies>
'@
  foreach ($includeNonShipping in @($false, $true)) {
    $darcCalls.Clear()
    $workloadPath = Join-Path $testRoot "$includeNonShipping\workloads"
    $nupkgPath = Join-Path $testRoot "$includeNonShipping\packages"
    New-Item -Path $workloadPath, $nupkgPath -ItemType Directory -Force | Out-Null

    & $scriptPath `
      -workloadPath $workloadPath `
      -workloadListJson '["test"]' `
      -includeNonShipping $includeNonShipping `
      -downloadWorkloadNupkgs $true `
      -workloadNupkgPath $nupkgPath | Out-Null

    foreach ($outputPath in @($workloadPath, $nupkgPath)) {
      $calls = @($darcCalls | Where-Object { $_ -contains $outputPath })
      if ($calls.Count -eq 0) {
        throw "No DARC calls were made for '$outputPath'."
      }
      foreach ($call in $calls) {
        if (@($call | Where-Object { [string]::IsNullOrEmpty($_) }).Count -ne 0) {
          throw "DARC received an empty argument for '$outputPath'."
        }
        $flagCount = @($call | Where-Object { $_ -eq '--non-shipping' }).Count
        if ($flagCount -ne [int]$includeNonShipping) {
          throw "Unexpected --non-shipping argument count for '$outputPath': $flagCount."
        }
      }
    }
  }
}
finally {
  if (Test-Path $testRoot) {
    Remove-Item -LiteralPath $testRoot -Recurse -Force
  }
}

Write-Host 'Workload download argument tests passed.'
