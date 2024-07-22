# Darc access copied from: eng/common/post-build/publish-using-darc.ps1
$ci = $true
$disableConfigureToolsetImport = $true
. $PSScriptRoot\common\tools.ps1

$darc = Get-Darc

$versionDetailsPath = (Get-Item "$PSScriptRoot\Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)
$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Uri, Sha -Unique

$workloadOutputPath = "$PSScriptRoot\..\artifacts\workloads"
$versionDetails | ForEach-Object { & $darc gather-drop --include-released --repo $_.Uri --commit $_.Sha --output-dir $workloadOutputPath }

# if ($LastExitCode -ne 0) {
#   Write-Host "Problems using Darc to promote build ${buildId} to default channels. Stopping execution..."
#   exit 1
# }

Write-Host 'Downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -Recurse | Select-Object -Expand FullName



# $workloads = Get-ChildItem $workloadOutputPath -Filter 'Workload.VSDrop*' -Recurse
$workloads = Get-ChildItem $workloadOutputPath -Include 'Workload.VSDrop*' -Recurse
$dropPath = (New-Item "$workloadOutputPath\drops" -Type Container -Force).FullName
$workloads | Move-Item -Destination $dropPath

Write-Host 'Drop:'
Get-ChildItem $dropPath -Recurse | Select-Object -Expand FullName

# $workloads | Copy-Item -Destination $dropPath
# $workloads | Copy-Item -Destination "$dropPath\$($_.Name)"
# $workloads | Move-Item -Destination $dropPath
# $workloads | ForEach-Object { Copy-Item -Path $_.FullName -Destination $dropPath -Force }