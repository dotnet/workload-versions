# `tools.ps1` checks $ci to perform some actions. Since the post-build scripts don't necessarily execute in the same agent that run the build.ps1/sh script this variable isn't automatically set.
$ci = $true
$disableConfigureToolsetImport = $true
. $PSScriptRoot\eng\common\tools.ps1

$darc = Get-Darc

$versionDetailsPath = (Get-Item "$PSScriptRoot\Version.Details.xml").FullName
$versionDetailsXml = [Xml.XmlDocument](Get-Content $versionDetailsPath)

$versionDetails = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Select-Object -Property Uri, Sha -Unique
# $workloadInfo = $versionDetails | Where-Object {
#   ($_.Uri -Like '*runtime*') -Or
#   ($_.Uri -Like '*emsdk*') -Or
#   ($_.Uri -Like '*aspire*') -Or
#   ($_.Uri -Like '*xamarin-android*') -Or
#   ($_.Uri -Like '*xamarin-macios*') -Or
#   ($_.Uri -Like '*maui*')
# }

# $runtime = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object -Property Uri -Like '*runtime*'
# $emsdk = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object -Property Uri -Like '*emsdk*'
# $aspire = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object -Property Uri -Like '*aspire*'
# $android = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object -Property Uri -Like '*xamarin-android*'
# $macios = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object -Property Uri -Like '*xamarin-macios*'
# $maui = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object -Property Uri -Like '*maui*'

# $workloadInfo = $versionDetailsXml.Dependencies.ProductDependencies.Dependency | Where-Object {
#   ($_.Uri -Like '*runtime*') -Or
#   ($_.Uri -Like '*emsdk*') -Or
#   ($_.Uri -Like '*aspire*') -Or
#   ($_.Uri -Like '*xamarin-android*') -Or
#   ($_.Uri -Like '*xamarin-macios*') -Or
#   ($_.Uri -Like '*maui*')
# }



$workloadOutputPath = $PSScriptRoot\..\artifacts\workloads
$versionDetails | & $darc gather-drop --include-released --repo $_.Uri --commit $_.Sha --output-dir $workloadOutputPath

# if ($LastExitCode -ne 0) {
#   Write-Host "Problems using Darc to promote build ${buildId} to default channels. Stopping execution..."
#   exit 1
# }

# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -Recurse | Select-Object -Expand FullName