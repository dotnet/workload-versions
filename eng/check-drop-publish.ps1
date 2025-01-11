# Based on the MicroBuildUploadVstsDropFolder task logic. See: https://devdiv.visualstudio.com/Engineering/_git/MicroBuild?path=%2Fsrc%2FTasks%2FUploadDrop%2Fplugin.ps1
# General drop service docs: https://eng.ms/docs/cloud-ai-platform/devdiv/one-engineering-system-1es/1es-docs/azure-artifacts/drop-service/azure-artifacts-drop

param ([Parameter(Mandatory=$true)] [string] $workloadId, [Parameter(Mandatory=$true)] [string] $workloadPath, [Parameter(Mandatory=$true)] [string] $workloadName, [Parameter(Mandatory=$true)] [SecureString] $token, [Parameter(Mandatory=$true)] [string] $vstsDropFolder)

# If the drop folder doesn't exist (not downloaded via DARC), the drop cannot be published.
if (-not (Test-Path -Path $workloadPath)) {
  Write-Host "##vso[task.setvariable variable=PublishWorkloadDrop]False"
  Write-Host "Drop '$workloadId' was not downloaded via DARC. Skipping VS drop publish..."
  return
}

Import-Module "$vstsDropFolder/Engineering.PowerShell.Vsts.Drop.psd1"
# Default value within: https://devdiv.visualstudio.com/Engineering/_git/MicroBuild?path=/src/Tasks/UploadDrop/task.json
$serviceUri = 'https://devdiv.artifacts.visualstudio.com'
$tokenPlain = ConvertFrom-SecureString -SecureString $token -AsPlainText
$server = Get-VstsDropServer -Url $serviceUri -TraceToHost ActivityTracing -PatAuth $tokenPlain
# Returns a JSON string. If the drop exists, an array with a single object is returned. If the drop does not exist, an empty array is returned.
$dropJson = $server.Client.List($workloadName) | ConvertFrom-Json
if ($dropJson.Count -ne 0) {
  Write-Host "##vso[task.setvariable variable=PublishWorkloadDrop]False"
  Write-Host "Drop '$workloadId' has already been published. Skipping VS drop publish..."
  return
}

Write-Host "PublishWorkloadDrop: True"
Write-Host "##vso[task.setvariable variable=PublishWorkloadDrop]True"