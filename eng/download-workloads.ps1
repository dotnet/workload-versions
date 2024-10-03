# param ([Parameter(Mandatory=$true)] [SecureString] $gitHubPat, [Parameter(Mandatory=$true)] [SecureString] $azDevPat, [Parameter(Mandatory=$true)] [SecureString] $password)
param ([Parameter(Mandatory=$true)] [string] $workloadOutputPath, [Parameter(Mandatory=$true)] [string] $msBuildToolsPath, [SecureString] $gitHubPat, [SecureString] $azDOPat)

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
  $ciArguments = "--ci --github-pat $gitHubPatPlain --azdev-pat $azDOPatPlain"
#     --password $passwordPlain
}

# Reads the Version.Details.xml file and downloads the workload drops.
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

Write-Host 'Workload drops downloaded:'
# https://stackoverflow.com/a/9570030/294804
Get-ChildItem $workloadOutputPath -File -Include 'Workload.VSDrop.*.zip' -Recurse | Select-Object -Expand FullName

# Extracts the workload drop zips.
$workloads = Get-ChildItem $workloadOutputPath -Include 'Workload.VSDrop.*.zip' -Recurse
$workloadDropPath = (New-Item "$workloadOutputPath\drops" -Type Container -Force).FullName
$null = $workloads | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath "$workloadDropPath\$([IO.Path]::GetFileNameWithoutExtension($_.Name))" -Force }

# Write-Host 'Drop:'
# Get-ChildItem $workloadDropPath -Directory -Recurse | Select-Object -Expand FullName

# Extracts the workload drop metadata from the drop name and builds the .vsmanproj project.
# full: The full drop name, excluding the 'Workload.VSDrop.' prefix.
# short: The short name of the drop. Only contains the first word after 'Workload.VSDrop.'.
# type: Either 'pre.components', 'components', or 'packs'.
$dropInfoRegex = '^Workload\.VSDrop\.(?<full>(?<short>\w*)\..*?(?<type>(pre\.)?components$|packs$))'
Get-ChildItem -Path $workloadDropPath -Directory | ForEach-Object {
  $null = $_.Name -match $dropInfoRegex
  # $Matches.full + ';' + $Matches.short + ';' + $Matches.type.Replace('.', '')

  $assemblyName = "$($Matches.full)"
  $vsDropName = "Products/dotnet/workloads/$($assemblyName)/$(Get-Date -Format 'yyyyMMdd.hhmmss.fff')"
  $dropDir = "$($_.FullName)\"

  & "$msBuildToolsPath\MSBuild.exe" Microsoft.NET.Workloads.Vsman.vsmanproj /restore /t:Build `
    /p:VstsDropNames=$vsDropName `
    /p:VsixOutputPath=$dropDir `
    /p:AssemblyName=$assemblyName

  if ($ci) {
    $shortName = "$($Matches.short)"
    # Remove the '.' from 'pre.components'
    $dropType = $Matches.type.Replace('.', '')
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_name]$vsDropName"
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_dir]$dropDir"
  }

  Write-Host 'After upload, your workload drop will be available at:'
  Write-Host "https://devdiv.visualstudio.com/_apps/hub/ms-vscs-artifact.build-tasks.drop-hub-group-explorer-hub?name=$vsDropName"
}

# Clean up intermediate build files in the workload drop folders.
$null = Get-ChildItem -Path $workloadDropPath -Include *.json, *.vsmand, files.txt -Recurse | Remove-Item


# set DropName=Products/dotnet/workloads/%(WorkloadInfo.Identity)/$([System.DateTime]::Now.ToString("yyyyMMdd.hhmmss.fff")) &amp;&amp; ^
# set DropDir=$(WorkloadDropDirectory)Workload.VSDrop.%(WorkloadInfo.Identity)\ &amp;&amp; ^
# "$(MSBuildToolsPath)\MSBuild.exe" Microsoft.NET.Workloads.Vsman.vsmanproj /restore /t:Build ^
#   /p:VstsDropNames=%DropName% ^
#   /p:VsixOutputPath=%DropDir% ^
#   /p:AssemblyName=%(WorkloadInfo.Identity) &amp;&amp; ^
# echo ##vso[task.setvariable variable=%(WorkloadInfo.Short)_%(WorkloadInfo.Type)_name]%DropName% &amp;&amp; ^
# echo ##vso[task.setvariable variable=%(WorkloadInfo.Short)_%(WorkloadInfo.Type)_dir]%DropDir%