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
$gitHubPatPlain = ConvertFrom-SecureString -SecureString $gitHubPat -AsPlainText
$azDevPatPlain = ConvertFrom-SecureString -SecureString $azDevPat -AsPlainText
$passwordPlain = ConvertFrom-SecureString -SecureString $password -AsPlainText
$versionDetails | ForEach-Object {
  & $darc gather-drop `
    --asset-filter 'Workload\.VSDrop.*' `
    --repo $_.Uri `
    --commit $_.Sha `
    --output-dir $workloadOutputPath `
    --ci `
    --include-released `
    --continue-on-error `
    --use-azure-credential-for-blobs `
    --github-pat $gitHubPatPlain `
    --azdev-pat $azDevPatPlain `
    --password $passwordPlain
}

Write-Host 'Downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -File -Recurse | Select-Object -Expand FullName

$workloads = Get-ChildItem $workloadOutputPath -Include 'Workload.VSDrop*' -Recurse
$dropPath = (New-Item "$workloadOutputPath\drops" -Type Container -Force).FullName
$workloads | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath "$dropPath\$([IO.Path]::GetFileNameWithoutExtension($_.Name))" }
# $workloads | Move-Item -Destination $dropPath

Write-Host 'Drop:'
Get-ChildItem $dropPath -Directory -Recurse | Select-Object -Expand FullName