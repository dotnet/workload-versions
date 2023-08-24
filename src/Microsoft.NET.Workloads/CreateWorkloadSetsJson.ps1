# Licensed to the .NET Foundation under one or more agreements. The .NET Foundation licenses this file to you under the MIT license. See the LICENSE.md file in the project root for more information.

# Creates a workloadsets.json file based on a list of workload tuples (name, feature band, version).

param ([Parameter(Mandatory=$true)] [string[]] $workloadTupleList, [Parameter(Mandatory=$true)] [string] $outputPath)

Write-Host 'Inputs:'
Write-Host "workloadTupleList: $workloadTupleList"
Write-Host "outputPath: $outputPath"

$manifestXml = [Xml.XmlDocument](Get-Content $manifestPath)
$manifestXml.PackageManifest.Installation.SetAttribute('Experimental', 'false')
$manifestXml.Save($manifestPath)