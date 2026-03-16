# This downloads workload NuGet packages using DARC.
# Similar to download-workloads.ps1, but downloads .nupkg files from the specified workload repos.
# In CI, we need to pass PATs to this, so it runs in Azure Pipelines only (not through MSBuild).
# For local builds, some preconfiguration is necessary. Check the README.md for details.

# $workloadNugetPath: The path to the directory as output for the workload NuGet packages. This is --output-dir in the DARC command.
# - Example Value: "$(RepoRoot)artifacts\workload-nugets"
# $gitHubPat: The GitHub PAT to use for DARC (CI build only). See workload-build.yml for converting the PAT to SecureString.
# $azDOPat: The Azure DevOps PAT to use for DARC (CI build only). See workload-build.yml for converting the PAT to SecureString.
# $workloadListJson: The JSON string of the list of workload names to filter which repos to download NuGet packages from.
# - Only dependencies whose Name contains one of the provided workload names (case-insensitive) will be processed.
# - Example Value: '["maui","android","iOS"]'

param ([Parameter(Mandatory=$true)] [string] $workloadNugetPath, [SecureString] $gitHubPat, [SecureString] $azDOPat, [string] $workloadListJson = '')

### Local Build ###
# Local build requires the installation of DARC. See: https://github.com/dotnet/arcade/blob/main/Documentation/Darc.md#setting-up-your-darc-client
$darc = 'darc'
$ciArguments = @()
$ci = $gitHubPat -and $azDOPat

### CI Build ###
if ($ci) {
  # Darc access copied from: eng/common/post-build/publish-using-darc.ps1
  $disableConfigureToolsetImport = $true
  . $PSScriptRoot\common\tools.ps1

  $darc = Get-Darc
  $gitHubPatPlain = ConvertFrom-SecureString -SecureString $gitHubPat -AsPlainText
  $azDOPatPlain = ConvertFrom-SecureString -SecureString $azDOPat -AsPlainText
  $ciArguments = @(
    '--ci'
    '--github-pat'
    $gitHubPatPlain
    '--azdev-pat'
    $azDOPatPlain
  )
}

# Reads the Version.Details.xml file to get the workload builds.
$versionDetailsPath = (Get-Item "$PSScriptRoot\Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Name, Version, Uri, Sha, BarId -Unique

# Filter the workload builds to only process the specified workloads.
if ($workloadListJson) {
  $workloadList = ConvertFrom-Json -InputObject $workloadListJson
  # Using Length accounts for arrays (multiple workloads provided) and strings (single workload provided).
  if ($workloadList.Length -ne 0) {
    $versionDetails = $versionDetails | Where-Object {
      $depName = $_.Name
      ($workloadList | Where-Object { $depName -imatch $_ }).Count -gt 0
    }
  }
}

# Asset filter for .nupkg files.
$assetFilter = '.*\.nupkg$'
Write-Host "assetFilter: $assetFilter"

# Runs DARC against each workload build to download the NuGet packages (if applicable based on the filter).
$versionDetails | ForEach-Object {
  Write-Host "Dependency name: $($_.Name)"
  Write-Host "Dependency version: $($_.Version)"
  $darcArguments = @(
    'gather-drop'
    '--asset-filter'
    $assetFilter
    '--output-dir'
    $workloadNugetPath
    '--include-released'
    '--skip-existing'
    '--continue-on-error'
    '--use-azure-credential-for-blobs'
  )

  $buildDropArguments = @(
    '--repo'
    $_.Uri
    '--commit'
    $_.Sha
  )

  if ($_.BarId) {
    $buildDropArguments = @(
      '--id'
      $_.BarId
    )
  }

  Write-Host "darcArguments: $($darcArguments | Join-String -Separator ' ')"
  Write-Host "buildDropArguments: $($buildDropArguments | Join-String -Separator ' ')"

  & $darc ($darcArguments + $buildDropArguments + $ciArguments)
}

Write-Host 'Workload NuGet packages downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadNugetPath -File -Include '*.nupkg' -Recurse | Select-Object -Expand FullName
