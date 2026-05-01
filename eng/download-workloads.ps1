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
  [string] $workloadListJson = '[]',
  [bool] $usePreComponents = $false,
  [bool] $includeNonShipping = $false,
  [bool] $downloadWorkloadNupkgs = $false,
  [string] $workloadNupkgExcludeListJson = '[]',
  [string] $workloadNupkgPath = ''
)

## Initialize ##
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
# DropNames is not a value in the Version.Details.xml. We end up adding the drop name(s) after downloading the drops.
$versionDetailsUnfiltered = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Name, Version, Uri, Sha, BarId, DropNames
# Only unique entries are needed (based on Sha). If BarId is present, those entries are kept instead of BarId-less entries.
$versionDetails = $versionDetailsUnfiltered | Group-Object -Property Sha | ForEach-Object {
  $entries = $_.Group | Where-Object { $_.BarId }
  if (-not $entries) {
    $entries = $_.Group | Select-Object -First 1
  }
  $entries
}

# Construct the asset filter to only download the required workload drops.
$workloadFilter = ''
$workloadList = ConvertFrom-Json -InputObject $workloadListJson
# Using Length accounts for arrays (multiple workloads provided) and strings (single workload provided).
if ($workloadList.Length -ne 0) {
  $workloadFilter = "($($workloadList | Join-String -Separator '|'))"
}

# Note: The $ at the end of these filters are required for the positive/negative lookbehinds to function in DARC.
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

  # Prior to running, we want to compare the contents of the output folder to see if the drop was acquired.
  $workloadDropsBefore = Get-ChildItem $workloadPath -File -Recurse
  if (-not $workloadDropsBefore) {
    $workloadDropsBefore = @()
  }

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

  # Check if a workload drop was downloaded.
  $workloadDropsAfter = Get-ChildItem $workloadPath -File -Recurse
  if (-not $workloadDropsAfter) {
    $workloadDropsAfter = @()
  }

  $fileDelta = Compare-Object -ReferenceObject $workloadDropsBefore -DifferenceObject $workloadDropsAfter
  if ($fileDelta) {
    $workloadDropFileNames = $fileDelta.InputObject.Name
    # Get the drop name(s) by extracting the name out of the downloaded files.
    # DropNames are needed for the workload .nupkg download process below.
    $_.DropNames = $workloadDropFileNames | ForEach-Object { if ($_ -match 'Workload\.VSDrop\.([^.]+)\.') { $Matches[1] } } | Select-Object -Unique
    Write-Host "DropNames: $($_.DropNames -join ', ')"
  }
}

Write-Host 'Workload drops downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadPath -File -Include 'Workload.VSDrop.*.zip' -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName

# Download workload .nupkg files if enabled.
if ($downloadWorkloadNupkgs) {
  # Build the list of workloads to download nupkgs for, excluding items in the exclude list.
  $nupkgExcludeList = ConvertFrom-Json -InputObject $workloadNupkgExcludeListJson
  $filteredWorkloadDropNames = ConvertFrom-Json -InputObject $workloadListJson | Where-Object { $nupkgExcludeList -notcontains $_ }

  # Asset filter for .nupkg files, excluding .symbols.nupkg.
  # Note: The $ at the end of these filters are required for the positive/negative lookbehinds to function in DARC.
  $nupkgAssetFilter = '^.*\.nupkg(?<!\.symbols\.nupkg)$'

  $filteredWorkloadDropNames | ForEach-Object {
    $dropName = $_
    $versionDetail = $versionDetails | Where-Object { $_.DropNames -contains $dropName } | Select-Object -First 1
    if (-not $versionDetail) {
      Write-Host "No version detail found for drop name: $dropName. Skipping .nupkg download for this workload."
      return
    }

    Write-Host "Downloading .nupkgs for workload: $dropName"
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
      $versionDetail.Uri
      '--commit'
      $versionDetail.Sha
    )

    if ($versionDetail.BarId) {
      $nupkgDarcBuildArguments = @(
        '--id'
        $versionDetail.BarId
      )
    }

    Write-Host "nupkgDarcArguments: $($nupkgDarcArguments | Join-String -Separator ' ')"
    Write-Host "nupkgDarcBuildArguments: $($nupkgDarcBuildArguments | Join-String -Separator ' ')"

    & $darc ($nupkgDarcArguments + $nupkgDarcBuildArguments + $ciArguments)
  }

  Write-Host 'Workload .nupkgs downloaded:'
  Get-ChildItem $workloadNupkgPath -File -Include '*.nupkg' -Recurse -ErrorAction SilentlyContinue | Select-Object -Expand FullName
}