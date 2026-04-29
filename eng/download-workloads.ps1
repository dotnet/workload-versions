# This downloads the workloads using DARC.
# In CI, we need to pass PATs to this, so it runs in Azure Pipelines only (not through MSBuild).
# For local builds, some preconfiguration is necessary. Check the README.md for details.

# $workloadPath: The path to the directory as output for the workload ZIPs. This is --output-dir in the DARC command for the workload drop .zip downloads.
# - Example Value: "$(RepoRoot)artifacts\workloads"
# $gitHubPat: The GitHub PAT to use for DARC (CI build only). See workload-build.yml for converting the PAT to SecureString.
# $azDOPat: The Azure DevOps PAT to use for DARC (CI build only). See workload-build.yml for converting the PAT to SecureString.
# $workloadListJson: The JSON string of the list of workload drop names to download. If not provided, all workloads found in Version.Details.xml will be downloaded.
# - See the workloadDropNames parameter in official.yml for the list generally passed to this script.
# - Example Value: '["iOS","android","maui"]'
# $usePreComponents:
# - If $true, includes *pre.components.zip drops and excludes *components.zip drops.
# - If $false, excludes *pre.components.zip drops and includes *components.zip drops.
# $includeNonShipping:
# - If $true, includes workloads that are in the 'non-shipping' folder.
# - If $false, excludes workloads that are in the 'non-shipping' folder.
# $downloadWorkloadNupkgs:
# - If $true, includes downloading the workload .nupkg files.
# - If $false, excludes downloading the workload .nupkg files.
# $workloadNupkgExcludeListJson: The JSON string of the list of workload NuGet packages to exclude from downloading. This only applies if $downloadWorkloadNupkgs is $true.
# - See the workloadNupkgExcludeList parameter in official.yml for the list generally passed to this script.
# - Example Value: '["emsdk","mono"]'
# $workloadNupkgPath: The path to the directory for workload .nupkg downloads. This is --output-dir in the DARC command for the .nupkg downloads.
# - Example Value: "$(RepoRoot)artifacts\packages\workloadNupkgs"

param (
  [Parameter(Mandatory=$true)] [string] $workloadPath,
  [SecureString] $gitHubPat,
  [SecureString] $azDOPat,
  [string] $workloadListJson = '',
  [bool] $usePreComponents = $false,
  [bool] $includeNonShipping = $false,
  [bool] $downloadWorkloadNupkgs = $false,
  [string] $workloadNupkgExcludeListJson = '',
  [string] $workloadNupkgPath = '',
)

## Initialize ##
if (-not $workloadListJson) {
  $workloadListJson = '[]';
}
if (-not $workloadNupkgExcludeListJson) {
  $workloadNupkgExcludeListJson = '[]';
}
if (-not $workloadNupkgPath) {
  $workloadNupkgPath = "$workloadPath/packages/workloadNupkgs";
}

$nonShippingFlag = ''
if ($includeNonShipping) {
  $nonShippingFlag = '--non-shipping'
}

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
$versionDetailsPath = (Get-Item "$PSScriptRoot/Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Name, Version, Uri, Sha, BarId -Unique

# Construct the asset filter to only download the required workload drops.
$workloadFilter = ''
$workloadList = ConvertFrom-Json -InputObject $workloadListJson
# Using Length accounts for arrays (multiple workloads provided) and strings (single workload provided).
if ($workloadList.Length -ne 0) {
  $workloadFilter = "($($workloadList | Join-String -Separator '|'))"
}

# Note: The $ at the end of these filters are required for the positive/negative lookbehinds to function.
# Exclude pre.components.zip.
$componentFilter = '(?<!pre\.components\.zip)$'
if ($usePreComponents) {
  # Exclude .components.zip but include pre.components.zip.
  $componentFilter = '((?<!\.components\.zip)|(?<=pre\.components\.zip))$'
}
$assetFilter = "Workload\.VSDrop\.$workloadFilter.*$componentFilter"
Write-Host "assetFilter: $assetFilter"

# Runs DARC against each workload build to download the drops (if applicable based on the filter).
$versionDetails | ForEach-Object {
  Write-Host "Dependency name: $($_.Name)"
  Write-Host "Dependency version: $($_.Version)"

  $darcArguments = @(
    'gather-drop'
    '--asset-filter'
    $assetFilter
    '--output-dir'
    $workloadPath
    '--include-released'
    '--skip-existing'
    '--continue-on-error'
    '--use-azure-credential-for-blobs'
    $nonShippingFlag
  )

  $darcBuildArguments = @(
    '--repo'
    $_.Uri
    '--commit'
    $_.Sha
  )

  if ($_.BarId) {
    $darcBuildArguments = @(
      '--id'
      $_.BarId
    )
  }

  Write-Host "darcArguments: $($darcArguments | Join-String -Separator ' ')"
  Write-Host "darcBuildArguments: $($darcBuildArguments | Join-String -Separator ' ')"

  & $darc ($darcArguments + $darcBuildArguments + $ciArguments)
}

Write-Host 'Workload drops downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadPath -File -Include 'Workload.VSDrop.*.zip' -Recurse | Select-Object -Expand FullName

# Download workload .nupkg files if enabled.
if ($downloadWorkloadNupkgs) {
  # Build the list of workloads to download nupkgs for, excluding items in the exclude list.
  $nupkgExcludeList = ConvertFrom-Json -InputObject $workloadNupkgExcludeListJson
  $filteredWorkloadDropNames = ConvertFrom-Json -InputObject $workloadListJson | Where-Object { $nupkgExcludeList -notcontains $_ }

  # Asset filter for .nupkg files, excluding .symbols.nupkg.
  $nupkgAssetFilter = '(?<!\.symbols\.nupkg)(\.nupkg)$'

  $filteredWorkloadDropNames | ForEach-Object {
    # Check if the workload drop path contains any files with this workload name in the filename.
    $dropName = $_
    $workloadDrops = Get-ChildItem $workloadPath -File -Recurse | Where-Object { $_.Name -match $dropName }
    if ($workloadDrops) {
      Write-Host "Downloading .nupkgs for workload: $dropName"

      $workloadDrops | ForEach-Object {
        $nupkgDarcArguments = @(
          'gather-drop'
          '--asset-filter'
          $nupkgAssetFilter
          '--output-dir'
          $workloadNupkgPath
          '--include-released'
          '--skip-existing'
          '--continue-on-error'
          '--use-azure-credential-for-blobs'
          $nonShippingFlag
        )

        $nupkgDarcBuildArguments = @(
          '--repo'
          $_.Uri
          '--commit'
          $_.Sha
        )

        if ($_.BarId) {
          $nupkgDarcBuildArguments = @(
            '--id'
            $_.BarId
          )
        }

        Write-Host "nupkgDarcArguments: $($nupkgDarcArguments | Join-String -Separator ' ')"
        Write-Host "nupkgDarcBuildArguments: $($nupkgDarcBuildArguments | Join-String -Separator ' ')"

        & $darc ($nupkgDarcArguments + $nupkgDarcBuildArguments + $ciArguments)
      }
    }
  }

  Write-Host 'Workload .nupkgs downloaded:'
  Get-ChildItem $workloadNupkgPath -File -Include '*.nupkg' -Recurse | Select-Object -Expand FullName
}