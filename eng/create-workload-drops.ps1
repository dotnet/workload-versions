# Using the downloaded workloads, this creates the VS drops to upload for VS insertion.
# It builds the Microsoft.NET.Workloads.Vsman.vsmanproj per workload ZIP, which creates the appropriate VSMAN file.

# $workloadPath: The path to the directory containing the workload ZIPs, usually the output path used by DARC in the download-workloads.ps1 script.
# - Example Value: "$(RepoRoot)artifacts\workloads"
# $msBuildToolsPath: The path to the MSBuild tools directory, generally $(MSBuildToolsPath) in MSBuild.
# - Example Value: 'C:\Program Files\Microsoft Visual Studio\2022\Preview\MSBuild\Current\Bin'

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
Get-ChildItem -Path $workloadDropPath -Directory | ForEach-Object {
  $null = $_.Name -match $dropInfoRegex
  $assemblyName = "$($Matches.full)"
  $dropDir = "$($_.FullName)\"

  # Hash the files within the drop folder to create a unique identifier that represents this workload drop.
  # Example: 1E3EA4FE202394037253F57436A6EAD5DE1359792B618B9072014A98563A30FB
  # See: https://learn.microsoft.com/powershell/module/microsoft.powershell.utility/get-filehash#example-4-compute-the-hash-of-a-string
  $contentStream = [System.IO.MemoryStream]::new()
  $writer = [System.IO.StreamWriter]::new($contentStream)
  $dropFilePaths = (Get-ChildItem -Path $dropDir | Sort-Object).FullName
  # Hash each file individually, then write the hashes to the stream to create a combined hash.
  $dropFileHashes = (Get-FileHash -Path $dropFilePaths).Hash
  $null = $dropFileHashes | ForEach-Object { $writer.Write($_) }
  $writer.Flush()
  $contentStream.Position = 0
  $dropHash = (Get-FileHash -InputStream $contentStream).Hash
  $writer.Close()

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

    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_name;isoutput=true]$vsDropName"
    Write-Host "##vso[task.setvariable variable=$($shortName)_$($dropType)_dir;isoutput=true]$dropDir"

    $dropUrl = "https://vsdrop.microsoft.com/file/v1/$vsDropName;$assemblyName.vsman"
    # Each vsman file is comma-separated. First .vsman is destination and the second is source.
    $vsComponentValue = "$assemblyName.vsman{$workloadVersion}=$dropUrl,"
    # All VS components are added to the primary VS component JSON string.
    $primaryVSComponentJsonValues += $vsComponentValue

    # Secondary VS components do not include (pre)components drop types.
    if ($dropType -ne 'components' -and $dropType -ne 'precomponents') {
      $secondaryVSComponentJsonValues += $vsComponentValue
    }
  }
}

# Clean up intermediate build files in the workload drop folders.
$null = Get-ChildItem -Path $workloadDropPath -Include *.json, *.vsmand, files.txt -Recurse | Remove-Item

# Write the primary and secondary component strings for the vsman files to a variable for the pipeline to use for the VS insertion step.
if ($primaryVSComponentJsonValues) {
  # Remove the trailing comma.
  $primaryVSComponentJsonValues = $primaryVSComponentJsonValues -replace '.$'
  Write-Host "##vso[task.setvariable variable=PrimaryVSComponentJsonValues;isoutput=true]$primaryVSComponentJsonValues"
}
if ($secondaryVSComponentJsonValues) {
  # Remove the trailing comma.
  $secondaryVSComponentJsonValues = $secondaryVSComponentJsonValues -replace '.$'
  Write-Host "##vso[task.setvariable variable=SecondaryVSComponentJsonValues;isoutput=true]$secondaryVSComponentJsonValues"
}