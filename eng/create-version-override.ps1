# Using the downloaded workloads, this creates the VS drops to upload for VS insertion.
# It builds the Microsoft.NET.Workloads.Vsman.vsmanproj per workload ZIP, which creates the appropriate VSMAN file.

# $workloadPath: The path to the directory containing the workload ZIPs, usually the output path used by DARC in the download-workloads.ps1 script.
# - Example Value: "$(RepoRoot)artifacts\workloads"
# $msBuildToolsPath: The path to the MSBuild tools directory, generally $(MSBuildToolsPath) in MSBuild.
# - Example Value: 'C:\Program Files\Microsoft Visual Studio\2022\Preview\MSBuild\Current\Bin'

param ([bool] $createTestWorkloadSet = $false, [string] $sdkVersionMinor = '|default|', [string] $versionFeature = '|default|', [string] $versionPatch = '|default|', [string] $preReleaseVersionLabel = '|default|', [string] $preReleaseVersionIteration = '|default|')

$containsNonDefault = ($sdkVersionMinor, $versionFeature, $versionPatch, $preReleaseVersionLabel, $preReleaseVersionIteration | Where-Object { $_ -ne '|default|' }) -ne $null

if (-not $containsNonDefault -and -not $createTestWorkloadSet) {
    Write-Host "No version overrides to apply."
    exit 0
}

$xmlDoc = New-Object System.Xml.XmlDocument
$projectElement = $xmlDoc.CreateElement("Project")
$xmlDoc.AppendChild($rootElement)

$propertyGroup1Element = $xmlDoc.CreateElement("PropertyGroup")
$projectElement.AppendChild($propertyGroup1Element)

$propertyGroup2Element = $xmlDoc.CreateElement("PropertyGroup")
$projectElement.AppendChild($propertyGroup2Element)


$settingElement.SetAttribute("Name", "LogLevel")
$settingElement.InnerText = "Debug"

$xmlDoc.Save("D:\Workspace\TestMe.xml")



# <Project>
#   <PropertyGroup>
#     <VersionSDKMinor>3</VersionSDKMinor>
#     <VersionFeature>05</VersionFeature>
#     <VersionPatch>0</VersionPatch>
#     <PreReleaseVersionLabel>rc</PreReleaseVersionLabel>
#     <PreReleaseVersionIteration Condition="'$(StabilizePackageVersion)' != 'true'">1</PreReleaseVersionIteration>
#   </PropertyGroup>
#   <PropertyGroup>
#     <VersionPrefix>$(VersionMajor).$(VersionSDKMinor)$(VersionFeature).$(VersionPatch)</VersionPrefix>
#     <WorkloadsVersion>$(VersionMajor).$(VersionMinor).$(VersionSDKMinor)$(VersionFeature)</WorkloadsVersion>
#     <WorkloadsVersion Condition="'$(StabilizePackageVersion)' == 'true' and '$(VersionPatch)' != '0'">$(WorkloadsVersion).$(VersionPatch)</WorkloadsVersion>
#     <SdkFeatureBand>$(VersionMajor).$(VersionMinor).$(VersionSDKMinor)00</SdkFeatureBand>
#     <SdkFeatureBand Condition="'$(StabilizePackageVersion)' != 'true' and $(PreReleaseVersionLabel) != 'servicing'">$(SdkFeatureBand)-$(PreReleaseVersionLabel).$(PreReleaseVersionIteration)</SdkFeatureBand>
#     <!-- Conditional include -->
#     <PreReleaseVersionIteration Condition="'$(TestWorkloadVersion)' == 'true' and $(PreReleaseVersionLabel) != 'servicing'">$(PreReleaseVersionIteration).0</PreReleaseVersionIteration>
#     <PreReleaseVersionIteration Condition="'$(TestWorkloadVersion)' == 'true' and $(PreReleaseVersionLabel) == 'servicing'">0</PreReleaseVersionIteration>
#   </PropertyGroup>
# </Project>