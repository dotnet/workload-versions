# param ([Parameter(Mandatory=$true)] [SecureString] $gitHubPat, [Parameter(Mandatory=$true)] [SecureString] $azDevPat, [Parameter(Mandatory=$true)] [SecureString] $password)
# param ([Parameter(Mandatory=$true)] [string] $workloadOutputPath, [Parameter(Mandatory=$true)] [string] $msBuildToolsPath, [SecureString] $gitHubPat, [SecureString] $azDOPat)
# param ([Parameter(Mandatory=$true)] [string] $workloadOutputPath, [Parameter(Mandatory=$true)] [string] $msBuildToolsPath, [string] $gitHubPat, [string] $azDOPat)
param ([Parameter(Mandatory=$true)] [string] $workloadOutputPath, [SecureString] $gitHubPat, [SecureString] $azDOPat)

# Local Build
# Local build requires the installation of DARC. See: https://github.com/dotnet/arcade/blob/main/Documentation/Darc.md#setting-up-your-darc-client
$darc = 'darc'
$ciArguments = ''
$ci = $gitHubPat -and $azDOPat

# CI Build
if ($ci) {
  # Darc access copied from: eng/common/post-build/publish-using-darc.ps1
  $disableConfigureToolsetImport = $true
  . $PSScriptRoot\common\tools.ps1

  $darc = Get-Darc
  $gitHubPatPlain = ConvertFrom-SecureString -SecureString $gitHubPat -AsPlainText
  $azDOPatPlain = ConvertFrom-SecureString -SecureString $azDOPat -AsPlainText
# $passwordPlain = ConvertFrom-SecureString -SecureString $password -AsPlainText
  $ciArguments = "--ci --github-pat '$gitHubPatPlain' --azdev-pat '$azDOPatPlain'"
#     --password $passwordPlain
  # $ciArguments = "--ci --github-pat $gitHubPat --azdev-pat $azDOPat"
}

# Reads the Version.Details.xml file and downloads the workload drops.
$versionDetailsPath = (Get-Item "$PSScriptRoot\Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Uri, Sha -Unique
$darcArguments = @"
gather-drop
--asset-filter 'Workload\.VSDrop.*'
--repo $($_.Uri)
--commit $($_.Sha)
--output-dir '$workloadOutputPath'
$ciArguments
--include-released
--skip-existing
--continue-on-error
--use-azure-credential-for-blobs
"@

$versionDetails | ForEach-Object {
  # & $darc gather-drop `
  #   --asset-filter 'Workload\.VSDrop.*' `
  #   --repo $_.Uri `
  #   --commit $_.Sha `
  #   --output-dir "$workloadOutputPath" `
  #   $ciArguments `
  #   --include-released `
  #   --skip-existing `
  #   --continue-on-error `
  #   --use-azure-credential-for-blobs
  & $darc $darcArguments
}

Write-Host 'Workload drops downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -File -Include 'Workload.VSDrop.*.zip' -Recurse | Select-Object -Expand FullName