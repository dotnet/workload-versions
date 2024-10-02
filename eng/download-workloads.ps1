# param ([Parameter(Mandatory=$true)] [SecureString] $gitHubPat, [Parameter(Mandatory=$true)] [SecureString] $azDevPat, [Parameter(Mandatory=$true)] [SecureString] $password)
param ([Parameter(Mandatory=$true)] [string] $workloadOutputPath, [SecureString] $gitHubPat, [SecureString] $azDOPat)

# Local usage of this script
$darc = 'darc'
$ciArguments = ''

# CI usage of this script
if ($gitHubPat -and $azDOPat) {
  # Darc access copied from: eng/common/post-build/publish-using-darc.ps1
  $ci = $true
  $disableConfigureToolsetImport = $true
  . $PSScriptRoot\common\tools.ps1

  $darc = Get-Darc
  $gitHubPatPlain = ConvertFrom-SecureString -SecureString $gitHubPat -AsPlainText
  $azDOPatPlain = ConvertFrom-SecureString -SecureString $azDOPat -AsPlainText
# $passwordPlain = ConvertFrom-SecureString -SecureString $password -AsPlainText
  $ciArguments = "--ci --github-pat $gitHubPatPlain --azdev-pat $azDOPatPlain"
#     --password $passwordPlain
}

# Reads the Version.Details.xml file and downloads the workload drops
$versionDetailsPath = (Get-Item "$PSScriptRoot\Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Uri, Sha -Unique
$versionDetails | ForEach-Object {
  & $darc gather-drop `
    --asset-filter 'Workload\.VSDrop.*' `
    --repo $_.Uri `
    --commit $_.Sha `
    --output-dir $workloadOutputPath `
    $ciArguments `
    --include-released `
    --skip-existing `
    --continue-on-error `
    --use-azure-credential-for-blobs
}

Write-Host 'Downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -File -Recurse | Select-Object -Expand FullName

# Extracts the workload drops
$workloads = Get-ChildItem $workloadOutputPath -Include 'Workload.VSDrop.*.zip' -Recurse
$dropPath = (New-Item "$workloadOutputPath\drops" -Type Container -Force).FullName
$workloads | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath "$dropPath\$([IO.Path]::GetFileNameWithoutExtension($_.Name))" -Force }

Write-Host 'Drop:'
Get-ChildItem $dropPath -Directory -Recurse | Select-Object -Expand FullName