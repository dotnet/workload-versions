param ([Parameter(Mandatory=$true)] [string] $workloadPath, [Parameter(Mandatory=$true)] [string] $msBuildToolsPath)

# Extracts the workload drop zips.
$workloads = Get-ChildItem $workloadPath -Include 'Workload.VSDrop.*.zip' -Recurse
$workloadDropPath = (New-Item "$workloadPath\drops" -Type Container -Force).FullName
$null = $workloads | ForEach-Object { Expand-Archive -Path $_.FullName -DestinationPath "$workloadDropPath\$([IO.Path]::GetFileNameWithoutExtension($_.Name))" -Force }

# Extracts the workload drop metadata from the drop name and builds the .vsmanproj project.
# - full: The full drop name, excluding the 'Workload.VSDrop.' prefix.
# - short: The short name of the drop. Only contains the first word after 'Workload.VSDrop.'.
# - type: Either 'pre.components', 'components', or 'packs'.
$dropInfoRegex = '^Workload\.VSDrop\.(?<full>(?<short>\w*)\..*?(?<type>(pre\.)?components$|packs$))'
$primaryVSComponentJsonValues = ''
$secondaryVSComponentJsonValues = ''
$hashAlgorithm = [System.Security.Cryptography.SHA256]::Create()
Get-ChildItem -Path $workloadDropPath -Directory | ForEach-Object {
  $null = $_.Name -match $dropInfoRegex
  $assemblyName = "$($Matches.full)"
  $dropDir = "$($_.FullName)\"

  # Hash the files within the drop folder to create a unique identifier that represents this workload drop.
  # Example: 1E3EA4FE202394037253F57436A6EAD5DE1359792B618B9072014A98563A30FB
  $fileHashes = [byte[]]@()
  $dropFiles = Get-ChildItem -Path $dropDir | Sort-Object
  $null = $dropFiles | Get-Content -Encoding Byte -Raw | ForEach-Object { $fileHashes += $hashAlgorithm.ComputeHash($_) }
  $dropHash = [System.BitConverter]::ToString($hashAlgorithm.ComputeHash([byte[]]$fileHashes)).Replace('-','')

  $vsDropName = "Products/dotnet/workloads/$assemblyName/$dropHash"
  # Reads the first line out of the .metadata file in the workload's output folder and sets it to the workload version.
  $workloadVersion = Get-Content "$dropDir.metadata" -First 1
  # This requires building via MSBuild.exe as there are .NET Framework dependencies necessary for building the .vsmanproj.
  # Additionally, even using the MSBuild task won't work as '/restore' must be used for it to restore properly when building the .vsmanproj.
  & "$msBuildToolsPath\MSBuild.exe" Microsoft.NET.Workloads.Vsman.vsmanproj /restore /t:Build `
    /p:AssemblyName=$assemblyName `
    /p:VstsDropNames=$vsDropName `
    /p:VsixOutputPath=$dropDir `
    /p:WorkloadVersion=$workloadVersion

  # While in CI, set the variables necessary for uploading the VS drop.
  if ($env:TF_BUILD) {
    $shortName = "$($Matches.short)"
    # Remove the '.' from 'pre.components'
    $dropType = $Matches.type.Replace('.', '')
    $dropUrl = "https://vsdrop.microsoft.com/file/v1/$vsDropName;$assemblyName.vsman"

    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_name]$vsDropName"
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_dir]$dropDir"
    # Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_full]$assemblyName"
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_url]$dropUrl"

    # Each vsman file is comma-separated. First .vsman is destination and the second is source.
    # $vsComponentValue = "$assemblyName.vsman{$workloadVersion}=$dropUrl,"
    $vsComponentValue = "$assemblyName.vsman=$dropUrl,"
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