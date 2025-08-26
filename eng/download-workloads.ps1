# This downloads the workloads using DARC.
# In CI, we need to pass PATs to this, so it runs in Azure Pipelines only (not through MSBuild).
# For local builds, some preconfiguration is necessary. Check the README.md for details.

# $workloadPath: The path to the directory as output for the workload ZIPs. This is --output-dir in the DARC command.
# - Example Value: "$(RepoRoot)artifacts\workloads"
# $gitHubPat: The GitHub PAT to use for DARC (CI build only). See workload-build.yml for converting the PAT to SecureString.
# $azDOPat: The Azure DevOps PAT to use for DARC (CI build only). See workload-build.yml for converting the PAT to SecureString.
# $workloadListJson: The JSON string of the list of workload drop names to download. If not provided, all workloads found in Version.Details.xml will be downloaded.
# - See the workloadDropNames parameter in official.yml for the list generally passed to this script.
# - Example Value: '{["emsdk","mono"]}'
# $usePreComponents:
# - If $true, includes *pre.components.zip drops and excludes *components.zip drops.
# - If $false, excludes *pre.components.zip drops and includes *components.zip drops.
# $includeNonShipping:
# - If $true, includes workloads that are in the 'non-shipping' folder.
# - If $false, excludes workloads that are in the 'non-shipping' folder.

param ([Parameter(Mandatory=$true)] [string] $workloadPath, [SecureString] $gitHubPat, [SecureString] $azDOPat, [string] $workloadListJson = '', [bool] $usePreComponents = $false, [bool] $includeNonShipping = $false)

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
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Uri, Sha -Unique

# Construct the asset filter to only download the required workload drops.
$workloadFilter = ''
if ($workloadListJson) {
  $workloadList = ConvertFrom-Json -InputObject $workloadListJson
  if ($workloadList.Count -ne 0) {
    $workloadFilter = "($($workloadList | Join-String -Separator '|'))"
  }
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

$nonShippingFlag = ''
if ($includeNonShipping) {
  $nonShippingFlag = '--non-shipping'
}

# Runs DARC against each workload build to download the drops (if applicable based on the filter).
$versionDetails | ForEach-Object {
  $darcArguments = @(
    'gather-drop'
    '--asset-filter'
    $assetFilter
    '--repo'
    $_.Uri
    '--id 280810'
    '--commit'
    $_.Sha
    '--output-dir'
    $workloadPath
    '--include-released'
    '--skip-existing'
    '--continue-on-error'
    '--use-azure-credential-for-blobs'
    $nonShippingFlag
  )

  & $darc ($darcArguments + $ciArguments)
}

Write-Host 'Workload drops downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadPath -File -Include 'Workload.VSDrop.*.zip' -Recurse | Select-Object -Expand FullName