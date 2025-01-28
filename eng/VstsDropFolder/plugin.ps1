[CmdletBinding()]param()
. $PSScriptRoot\Telemetry\telemetry.ps1
Trace-VstsEnteringInvocation $MyInvocation

$StagingFolder = Get-VstsTaskVariable -Name 'Build.StagingDirectory' -Default (Get-VstsTaskVariable -Name 'System.DefaultWorkingDirectory' -Require)

function Get-DropServer {
    Import-Module "$PSScriptRoot\Engineering.PowerShell.Vsts.Drop.psd1"
    $serviceUri = Get-VstsInput -Name DropServiceUri -Require
    $token = Get-VstsInput -Name AccessToken
    if (-not $token) {
        return Get-VstsDropServer -Url $serviceUri -TraceToHost ActivityTracing
    }
    return Get-VstsDropServer -Url $serviceUri -TraceToHost ActivityTracing -PatAuth $token
}

function Out-BuildDetails([string[]]$manifestPaths, [string]$publishUrl) {
    $manifestUrls = @()
    $border = '-' * 100
    $buildDetails = @($border, 'Manifest Url(s):', $border)
    $manifestPaths | ForEach-Object { $manifestUrls += "$publishUrl$($_.Replace('\', '/'))`n" }
    $buildDetails += @($manifestUrls, $border)
    $buildDetails | Write-Host
    return $manifestUrls
}

function Out-BuildSummary([string[]]$manifestUrls) {
    $markdownFolder = Join-Path $StagingFolder (Join-Path 'MicroBuild' 'Output')
    New-Item -ItemType Directory -Force -Path $markdownFolder | Out-Null
    $markdownFile = Join-Path $markdownFolder 'ManifestUrls.md'
    $manifestUrls | Set-Content $markdownFile
    Write-VstsAddAttachment -Type "Distributedtask.Core.Summary" -Name "Published manifest urls" -Path $markdownFile
}

$DropFolder = Get-VstsInput -Name DropFolder -Require
$DropName = Get-VstsInput -Name DropName
if (-not $DropName) {
    # If SwixBuildPlugin is installed that should have set the MicroBuild.ManifestDropName variable
    try {
        $DropName = Get-VstsTaskVariable -Name "MicroBuild.ManifestDropName" -Require
    }
    catch [System.Exception] {
        Write-Error "Cannot upload drop: DropName value is missing."
    }
}

if (-not (Test-Path $DropFolder)) {
    Write-Error "Cannot upload drop: $DropFolder is missing."
}


Write-Telemetry "DropName" $DropName
Write-TelemetryMetricStartSeconds "Upload Drop"

$ConsoleLogger = New-Object System.Diagnostics.ConsoleTraceListener
$Server = Get-DropServer
$Server.TraceSource.Listeners.Add($ConsoleLogger)
$SkipUploadIfExists = Get-VstsInput -Name 'SkipUploadIfExists' -AsBool
Write-Host "SkipUploadIfExists: $SkipUploadIfExists"
Write-Host "DropName: $DropName"
if ($SkipUploadIfExists) {
    # Returns a JSON string. If the drop exists, an array is returned. Must check the name of each drop in the array to see if it's an exact match for the drop we're trying to publish.
    $dropJsonString = $server.Client.List($DropName)
    Write-Host "dropJsonString: $dropJsonString"
    $dropJson = $dropJsonString | ConvertFrom-Json
    Write-Host "dropJson: $dropJson"
    Write-Host "dropJsonType: $($dropJson.GetType())"
    Write-Host "dropJsonCount: $($dropJson.Count)"
    Write-Host "CountCheck: $($dropJson.Count -ne 0)"
    if ($dropJson.Count -ne 0) {
        $dropJson | ForEach-Object {
            Write-Host "Name: $($_.Name)"
            Write-Host "NameCheck: $($_.Name -eq $DropName)"
            if ($_.Name -eq $DropName) {
                Write-Host "Drop '$DropName' has already been published. Skipping VS drop publish..."
                Write-Telemetry "DropSkipped" "True"
                Write-TelemetryMetricFinishSeconds "Upload Drop"
                return
            }
        }
    }
}

$RetentionDays = Get-VstsInput -Name 'DropRetentionDays'
if (-not $RetentionDays) {
    Write-Warning "DropRetentionDays not set. Defaulting to 10 years (3650 days). Please reduce drop retention period to 183 days if possible. Please refer to this link for more details: https://dev.azure.com/devdiv/DevDiv/_wiki/wikis/DevDiv.wiki/35351/Retain-Drops"
    $RetentionDays = "3650"
}
if ([int]$RetentionDays -lt 90)
{
    Write-Warning "DropRetentionDays is less than 90 days. Setting DropRetentionDays to 90. Please refer to this link for more details: https://dev.azure.com/devdiv/DevDiv/_wiki/wikis/DevDiv.wiki/35351/Retain-Drops"
    $RetentionDays = 90
}
$Drop = $Server.CreateDrop($DropName, (Get-Date).AddDays([int]$RetentionDays))
$Drop.UploadDirectory($DropFolder)
$Drop.FinalizeDrop()

# If we detect that one or more VS manifests were uploaded, output their urls
$DropRoot = "$([IO.Path]::GetFullPath($DropFolder).TrimEnd('\'))\"
$Manifests = Get-ChildItem "$DropRoot*.vsman" -Recurse
if ($Manifests.Count -gt 0) {
    $ManifestPaths = $Manifests.FullName | ForEach-Object { $_.Remove(0, $DropRoot.Length) }
    $ManifestUrls = Out-BuildDetails $ManifestPaths "$(Get-VstsInput -Name 'VSDropServiceUri' -Require)/$DropName;"
    Out-BuildSummary $ManifestUrls
}
Write-Telemetry "DropRetentionDays" $RetentionDays
Write-TelemetryMetricFinishSeconds "Upload Drop"
