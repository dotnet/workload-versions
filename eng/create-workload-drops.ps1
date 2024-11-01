param ([Parameter(Mandatory=$true)] [string] $workloadPath, [Parameter(Mandatory=$true)] [string] $msBuildToolsPath)

# Extracts the workload drop zips.
$workloads = Get-ChildItem $workloadPath -Include 'Workload.VSDrop.*.zip' -Recurse
$workloadDropPath = (New-Item "$workloadPath\drops" -Type Container -Force).FullName
$null = $workloads | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath "$workloadDropPath\$([IO.Path]::GetFileNameWithoutExtension($_.Name))" -Force }

# Extracts the workload drop metadata from the drop name and builds the .vsmanproj project.
# - full: The full drop name, excluding the 'Workload.VSDrop.' prefix.
# - short: The short name of the drop. Only contains the first word after 'Workload.VSDrop.'.
# - type: Either 'pre.components', 'components', 'packs', or 'multitarget'.
$dropInfoRegex = '^Workload\.VSDrop\.(?<full>(?<short>\w*)\..*?(?<type>(pre\.)?components$|packs$|multitarget$))'
$primaryVSComponentJsonValues = ''
$secondaryVSComponentJsonValues = ''
Get-ChildItem -Path $workloadDropPath -Directory | ForEach-Object {
  $null = $_.Name -match $dropInfoRegex

  $assemblyName = "$($Matches.full)"
  $vsDropName = "Products/dotnet/workloads/$($assemblyName)/$(Get-Date -Format 'yyyyMMdd.hhmmss.fff')"
  $dropDir = "$($_.FullName)\"

  & "$msBuildToolsPath\MSBuild.exe" Microsoft.NET.Workloads.Vsman.vsmanproj /restore /t:Build `
    /p:AssemblyName=$assemblyName `
    /p:VstsDropNames=$vsDropName `
    /p:VsixOutputPath=$dropDir

  # While in CI, set the variables necessary for uploading the VS drop.
  if ($env:TF_BUILD) {
    $shortName = "$($Matches.short)"
    # Remove the '.' from 'pre.components'
    $dropType = $Matches.type.Replace('.', '')
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_name]$vsDropName"
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_dir]$dropDir"
    # Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_full]$assemblyName"

    # Each vsman file is comma-separated. First .vsman is destination and the second is source.
    $vsComponentValue = "$assemblyName.vsman=https://vsdrop.corp.microsoft.com/file/v1/$vsDropName;$assemblyName.vsman,"
    # All VS components are added to the primary VS component JSON string.
    $primaryVSComponentJsonValues += $vsComponentValue

    # Secondary VS components do not include (pre)components drop types.
    if ($dropType -ne 'components' -and $dropType -ne 'precomponents') {
      $secondaryVSComponentJsonValues += $vsComponentValue
    }
  }

  Write-Host 'After upload, your workload drop will be available at:'
  Write-Host "https://devdiv.visualstudio.com/_apps/hub/ms-vscs-artifact.build-tasks.drop-hub-group-explorer-hub?name=$vsDropName"
}

# Clean up intermediate build files in the workload drop folders.
$null = Get-ChildItem -Path $workloadDropPath -Include *.json, *.vsmand, files.txt -Recurse | Remove-Item

# Write the primary and secondary component strings for the vsman files to a variable for the pipeline to use for the VS insertion step.
if ($primaryVSComponentJsonValues) {
  # Remove the trailing comma.
  $primaryVSComponentJsonValues = $primaryVSComponentJsonValues -replace '.$'
  Write-Host "##vso[task.setvariable variable=PrimaryVSComponentJsonValues]$primaryVSComponentJsonValues"
}
if ($secondaryVSComponentJsonValues) {
  # Remove the trailing comma.
  $secondaryVSComponentJsonValues = $secondaryVSComponentJsonValues -replace '.$'
  Write-Host "##vso[task.setvariable variable=SecondaryVSComponentJsonValues]$secondaryVSComponentJsonValues"
}