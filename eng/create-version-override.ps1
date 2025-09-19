# Creates a Version.Overrides.props file to override version components for the workload set creation.

# $createTestWorkloadSet:
# - If $true, adds PreReleaseVersionIteration overrides for creating a test workload set.
# - If $false, does not add any PreReleaseVersionIteration overrides.
# $versionSdkMinor: Adds the VersionSdkMinor property to the Version.Overrides.props file with the provided value.
# - Example Value: '2'
# $versionFeature: Adds the VersionFeature property to the Version.Overrides.props file with the provided value.
# - Example Value: '01'
# $versionPatch: Adds the VersionPatch property to the Version.Overrides.props file with the provided value.
# - Example Value: '4'
# $preReleaseVersionLabel: Adds the PreReleaseVersionLabel property to the Version.Overrides.props file with the provided value.
# - Example Value: 'preview'
# $preReleaseVersionIteration: Adds the PreReleaseVersionIteration property to the Version.Overrides.props file with the provided value.
# - Example Value: '1'

param ([bool] $createTestWorkloadSet = $false, [string] $versionSdkMinor = '|default|', [string] $versionFeature = '|default|', [string] $versionPatch = '|default|', [string] $preReleaseVersionLabel = '|default|', [string] $preReleaseVersionIteration = '|default|')

$containsNonDefault = ($sdkVersionMinor, $versionFeature, $versionPatch, $preReleaseVersionLabel, $preReleaseVersionIteration | Where-Object { $_ -ne '|default|' }) -ne $null

if (-not $containsNonDefault -and -not $createTestWorkloadSet) {
  Write-Host 'No version overrides to apply.'
  exit 0
}

$xmlDoc = New-Object System.Xml.XmlDocument
$project = $xmlDoc.CreateElement('Project')
$propertyGroup1 = $xmlDoc.CreateElement('PropertyGroup')

if ($versionSdkMinor -ne '|default|') {
  $versionSdkMinorElem = $xmlDoc.CreateElement('VersionSdkMinor')
  $versionSdkMinorElem.InnerText = $versionSdkMinor
  $null = $propertyGroup1.AppendChild($versionSdkMinorElem)
  Write-Host "Setting VersionSdkMinor to $versionSdkMinor."
}

if ($versionFeature -ne '|default|') {
  $versionFeatureElem = $xmlDoc.CreateElement('VersionFeature')
  $versionFeatureElem.InnerText = $versionFeature
  $null = $propertyGroup1.AppendChild($versionFeatureElem)
  Write-Host "Setting VersionFeature to $versionFeature."
}

if ($versionPatch -ne '|default|') {
  $versionPatchElem = $xmlDoc.CreateElement('VersionPatch')
  $versionPatchElem.InnerText = $versionPatch
  $null = $propertyGroup1.AppendChild($versionPatchElem)
  Write-Host "Setting VersionPatch to $versionPatch."
}

if ($preReleaseVersionLabel -ne '|default|') {
  $preReleaseVersionLabelElem = $xmlDoc.CreateElement('PreReleaseVersionLabel')
  $preReleaseVersionLabelElem.InnerText = $preReleaseVersionLabel
  $null = $propertyGroup1.AppendChild($preReleaseVersionLabelElem)
  Write-Host "Setting PreReleaseVersionLabel to $preReleaseVersionLabel."
}

if ($preReleaseVersionIteration -ne '|default|') {
  $preReleaseVersionIterationElem = $xmlDoc.CreateElement('PreReleaseVersionIteration')
  $null = $preReleaseVersionIterationElem.SetAttribute('Condition', "'`$(StabilizePackageVersion)' != 'true'")
  $preReleaseVersionIterationElem.InnerText = $preReleaseVersionIteration
  $null = $propertyGroup1.AppendChild($preReleaseVersionIterationElem)
  Write-Host "Setting PreReleaseVersionIteration to $preReleaseVersionIteration."
}

$null = $project.AppendChild($propertyGroup1)
$propertyGroup2 = $xmlDoc.CreateElement('PropertyGroup')

$versionPrefix = $xmlDoc.CreateElement('VersionPrefix')
$versionPrefix.InnerText = '$(VersionMajor).$(VersionSdkMinor)$(VersionFeature).$(VersionPatch)'
$null = $propertyGroup2.AppendChild($versionPrefix)

$workloadsVersion1 = $xmlDoc.CreateElement('WorkloadsVersion')
$workloadsVersion1.InnerText = '$(VersionMajor).$(VersionMinor).$(VersionSdkMinor)$(VersionFeature)'
$null = $propertyGroup2.AppendChild($workloadsVersion1)

$workloadsVersion2 = $xmlDoc.CreateElement('WorkloadsVersion')
$null = $workloadsVersion2.SetAttribute('Condition', "'`$(StabilizePackageVersion)' == 'true' and '`$(VersionPatch)' != '0'")
$workloadsVersion2.InnerText = '$(WorkloadsVersion).$(VersionPatch)'
$null = $propertyGroup2.AppendChild($workloadsVersion2)

$sdkFeatureBand1 = $xmlDoc.CreateElement('SdkFeatureBand')
$sdkFeatureBand1.InnerText = '$(VersionMajor).$(VersionMinor).$(VersionSdkMinor)00'
$null = $propertyGroup2.AppendChild($sdkFeatureBand1)

$sdkFeatureBand2 = $xmlDoc.CreateElement('SdkFeatureBand')
$null = $sdkFeatureBand2.SetAttribute('Condition', "'`$(StabilizePackageVersion)' != 'true' and '`$(PreReleaseVersionLabel)' != 'servicing'")
$sdkFeatureBand2.InnerText = '$(SdkFeatureBand)-$(PreReleaseVersionLabel).$(PreReleaseVersionIteration)'
$null = $propertyGroup2.AppendChild($sdkFeatureBand2)

if ($createTestWorkloadSet) {
  $preReleaseVersionIteration1 = $xmlDoc.CreateElement('PreReleaseVersionIteration')
  $null = $preReleaseVersionIteration1.SetAttribute('Condition', "'`$(PreReleaseVersionLabel)' != 'servicing'")
  $preReleaseVersionIteration1.InnerText = '$(PreReleaseVersionIteration).0'
  $null = $propertyGroup2.AppendChild($preReleaseVersionIteration1)

  $preReleaseVersionIteration2 = $xmlDoc.CreateElement('PreReleaseVersionIteration')
  $null = $preReleaseVersionIteration2.SetAttribute('Condition', "'`$(PreReleaseVersionLabel)' == 'servicing'")
  $preReleaseVersionIteration2.InnerText = '0'
  $null = $propertyGroup2.AppendChild($preReleaseVersionIteration2)
  Write-Host 'Setting PreReleaseVersionIteration for test workload set.'
}

$null = $project.AppendChild($propertyGroup2)
$null = $xmlDoc.AppendChild($project)

$versionOverridesPath = Join-Path -Path $PSScriptRoot -ChildPath 'Version.Overrides.props'
$null = $xmlDoc.Save($versionOverridesPath)