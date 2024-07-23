param ([Parameter(Mandatory=$true)] [SecureString] $gitHubPat, [Parameter(Mandatory=$true)] [SecureString] $azDevPat, [Parameter(Mandatory=$true)] [SecureString] $password)

# Darc access copied from: eng/common/post-build/publish-using-darc.ps1
$ci = $true
$disableConfigureToolsetImport = $true
. $PSScriptRoot\common\tools.ps1

$darc = Get-Darc

$versionDetailsPath = (Get-Item "$PSScriptRoot\Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Uri, Sha -Unique

$workloadOutputPath = "$PSScriptRoot\..\artifacts\workloads"
$versionDetails | ForEach-Object {
  & $darc gather-drop `
    --ci `
    --use-azure-credential-for-blobs `
    --repo $_.Uri `
    --commit $_.Sha `
    --output-path $workloadOutputPath `
    --include-released `
    --continue-on-error `
    --github-pat $gitHubPat `
    --azdev-pat $azDevPat `
    --password $password
}

Write-Host 'Downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -Recurse | Select-Object -Expand FullName

$workloads = Get-ChildItem $workloadOutputPath -Include 'Workload.VSDrop*' -Recurse
$dropPath = (New-Item "$workloadOutputPath\drops" -Type Container -Force).FullName
$workloads | Move-Item -Destination $dropPath

Write-Host 'Drop:'
Get-ChildItem $dropPath -Recurse | Select-Object -Expand FullName