function ConvertTo-WorkloadRepositoryUri {
  param([Parameter(Mandatory=$true)] [string] $Repository)

  ($Repository.TrimEnd('/') -replace '\.git$', '') -replace '^https://dnceng\.visualstudio\.com/(?:DefaultCollection/)?', 'https://dev.azure.com/dnceng/'
}

function Get-WorkloadRepositoryDropNames {
  param([Parameter(Mandatory=$true)] [string] $Repository)

  switch -Regex (ConvertTo-WorkloadRepositoryUri $Repository) {
    '^https://github\.com/(dotnet/macios|xamarin/xamarin-macios)$' { return 'iOS' }
    '^https://github\.com/(dotnet/android|xamarin/xamarin-android)$' { return 'android' }
    '^https://github\.com/dotnet/maui$' { return 'maui' }
    '^https://github\.com/dotnet/runtime$' { return 'mono' }
    '^https://github\.com/dotnet/emsdk$' { return 'emsdk' }
    '^https://github\.com/dotnet/dotnet$' { return 'mono', 'emsdk' }
    '^https://dev\.azure\.com/dnceng/internal/_git/dotnet-(runtime|emsdk|dotnet)$' {
      switch ($Matches[1]) {
        'runtime' { return 'mono' }
        'emsdk' { return 'emsdk' }
        'dotnet' { return 'mono', 'emsdk' }
      }
    }
  }
}

function Test-WorkloadDependencyRequested {
  param(
    [Parameter(Mandatory=$true)] $Dependency,
    [string[]] $WorkloadNames = @()
  )

  if ($WorkloadNames.Count -eq 0) {
    return $true
  }

  $dropNames = @(Get-WorkloadRepositoryDropNames -Repository $Dependency.Uri)
  # Unknown repositories must retain the existing gather behavior.
  return $dropNames.Count -eq 0 -or @($dropNames | Where-Object { $WorkloadNames -contains $_ }).Count -gt 0
}

function Resolve-WorkloadBarId {
  param(
    [Parameter(Mandatory=$true)] $Dependency,
    [string] $Darc = 'darc',
    [string[]] $CiArguments = @()
  )

  if ($Dependency.BarId) {
    return $Dependency.BarId
  }

  $queryArguments = @(
    'get-build'
    '--repo'
    $Dependency.Uri
    '--commit'
    $Dependency.Sha
    '--extended'
    '--output-format'
    'json'
  )
  $queryArguments += $CiArguments
  $output = & $Darc @queryArguments
  if ($LASTEXITCODE) {
    throw "Darc build lookup failed for $($Dependency.Uri)@$($Dependency.Sha) (exit code $LASTEXITCODE)."
  }

  try {
    $builds = @(ConvertFrom-Json -InputObject ($output -join [Environment]::NewLine) -ErrorAction Stop)
  }
  catch {
    throw "Darc returned invalid build JSON for $($Dependency.Uri)@$($Dependency.Sha)."
  }

  foreach ($build in $builds) {
    if (-not $build -or "$($build.id)" -notmatch '^[1-9][0-9]*$' -or $build.commit -ne $Dependency.Sha) {
      throw "Darc returned an invalid build record for $($Dependency.Uri)@$($Dependency.Sha)."
    }
    $repositories = @($build.gitHubRepository, $build.azureDevOpsRepository) |
      Where-Object { $_ } | ForEach-Object { ConvertTo-WorkloadRepositoryUri $_ }
    if ($repositories -notcontains (ConvertTo-WorkloadRepositoryUri $Dependency.Uri)) {
      throw "Darc returned a build for a different repository than $($Dependency.Uri)@$($Dependency.Sha)."
    }
  }

  if ($builds.Count -eq 1) {
    return $builds[0].id
  }

  $dropNames = @(Get-WorkloadRepositoryDropNames -Repository $Dependency.Uri)
  $isMauiRepository = @($dropNames | Where-Object { $_ -in 'maui', 'android', 'iOS' }).Count -gt 0
  if ($isMauiRepository) {
    $workloadBuilds = @($builds | Where-Object {
      @($_.channels | Where-Object { $_.name -match '^\.NET \d+(?:\.\d+)* Workloads?(?: |$)' }).Count -gt 0
    })
    if ($workloadBuilds.Count -eq 1) {
      Write-Host "Selected BAR ID $($workloadBuilds[0].id) from its Workload channel membership."
      return $workloadBuilds[0].id
    }
  }

  $candidates = @($builds | ForEach-Object {
    $channels = @($_.channels | ForEach-Object { $_.name }) -join ', '
    if (-not $channels) {
      $channels = '(none)'
    }
    "BAR ID $($_.id), build $($_.azureDevOpsBuildNumber), channels: $channels"
  }) -join '; '
  if (-not $candidates) {
    $candidates = '(none)'
  }
  throw "Cannot uniquely resolve a BAR build for $($Dependency.Uri)@$($Dependency.Sha). Candidates: $candidates. Inspect these builds (and the release tracker for runtime/emsdk), then set the intended BarId in eng/Version.Details.xml on the source branch."
}

Export-ModuleMember -Function Test-WorkloadDependencyRequested, Resolve-WorkloadBarId
