[CmdletBinding()]param()
. $PSScriptRoot\Telemetry\telemetry.ps1
Trace-VstsEnteringInvocation $MyInvocation

function Write-ErrorToTelemetryThenExitWithError([string]$message) {
    Write-Telemetry 'InsertionFatalError' $message
    # task will terminate on Write-Error call
    Write-Error "Cannot insert payload: $message"
}

function Write-WarningToTelemetryAndHost([string]$message) {
    # Using plural name for telemetry key because we could have multiple warnings
    Write-Telemetry "InsertionWarnings" $message
    Write-Warning $message
}

#region Strip default values from inputs, replace ';' with ',' for all splittables except ComponentJsonValues, split where needed, and trim resulting values
function Split-VstsInput([string]$inputName, [string]$defaultValue, [bool]$replaceSemicolons = $true) {
    $inputValue = (Get-VstsInput -Name $inputName) -replace [Text.RegularExpressions.Regex]::Escape($defaultValue)
    if ($replaceSemicolons) {
        $inputValue = $inputValue -replace ';', ','
    }
    return @($inputValue.Trim(' ', ',') -split ',' | ForEach-Object { $_.Trim() })
}

function Get-AccessTokenFromFederatedServiceConnection([string] $ServiceConnectionId, [string] $ClientId, [string] $TenantId)
{
    $uri = "${env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI}${env:SYSTEM_TEAMPROJECTID}/_apis/distributedtask/hubs/build/plans/${env:SYSTEM_PLANID}/jobs/${env:SYSTEM_JOBID}/oidctoken?serviceConnectionId=${ServiceConnectionId}&api-version=7.1-preview.1"

    $invokeOidcTokenAPI = @{
        'Uri' = $uri
        'Method' = 'POST'
        'Headers' = @{
            'Authorization' = "Bearer $($env:SYSTEM_ACCESSTOKEN)"
        }
        'ContentType' = 'application/json'
    }

    $oidcToken = (Invoke-RestMethod @invokeOidcTokenAPI).oidctoken

    $oauthTokenAPIBody = @{
        client_id = $ClientId
        scope = "499b84ac-1321-427f-aa17-267ca6975798/.default"     # 499b84ac is the ADO scope...
        client_assertion_type = "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
        client_assertion = $oidcToken
        grant_type = "client_credentials"
    }

    $tokenEndpointUrl = "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token"
    $response = Invoke-RestMethod -Uri $tokenEndpointUrl -Method Post -Body $oauthTokenAPIBody -ContentType "application/x-www-form-urlencoded"

    return $response.access_token
}


$TargetBranch = ((Get-VstsInput -Name TargetBranch) -replace '\$\(InsertTargetBranch\)').Trim()
$ComponentJsonValues = Split-VstsInput 'ComponentJsonValues' '$(InsertJsonValues)' $false
$DefaultConfigValues = Split-VstsInput 'DefaultConfigValues' '$(InsertConfigValues)'
$PackagePropsValues = Split-VstsInput 'PackagePropsValues' '$(InsertPropsValues)'
$AssemblyVersionsValues = Split-VstsInput 'AssemblyVersionsValues' '$(InsertVersionsValues)'
$RevisionTxtFiles = Split-VstsInput 'RevisionTextFiles' '$(InsertRevisionFiles)'
$ComponentSWRFiles = Split-VstsInput 'ComponentSWRFiles' '$(InsertComponentSWRFiles)'
$CustomScriptExecutionCommand = ((Get-VstsInput -Name CustomScriptExecutionCommand) -replace '\$\(InsertCustomScriptExecutionCommand\)').Trim()
$AccessToken = ((Get-VstsInput -Name InsertionAccessToken) -replace '\$\(InsertAccessToken\)').Trim()
$TopicBranch = ((Get-VstsInput -Name InsertionTopicBranch) -replace '\$\(InsertTopicBranch\)').Trim()
$PayloadName = ((Get-VstsInput -Name InsertionPayloadName) -replace '\$\(InsertPayloadName\)').Trim()
$PRTitle = ((Get-VstsInput -Name InsertionPRTitle) -replace '\$\(InsertPRTitle\)').Trim()
$Description = ((Get-VstsInput -Name InsertionDescription) -replace '\$\(InsertDescription\)').Trim()
$BuildPolicies = ((Get-VstsInput -Name InsertionBuildPolicies) -replace '\$\(InsertBuildPolicies\)').Trim()
$WaitMinutes = ((Get-VstsInput -Name InsertionWaitMinutes) -replace '\$\(InsertWaitMinutes\)').Trim()
$MergeStrategy = ((Get-VstsInput -Name AutoCompleteMergeStrategy) -replace '\$\(AutoCompleteMergeStrategy\)').Trim()
$Reviewers = Split-VstsInput 'InsertionReviewers' '$(InsertReviewers)'
$TeamEmail = ((Get-VstsInput -Name TeamEmail) -replace '\$\(InsertTeamEmail\)').Trim()
$TeamName = ((Get-VstsInput -Name TeamName) -replace '\$\(InsertTeamName\)').Trim()
$ServiceConnection = Get-VstsInput -Name ConnectedServiceName
#endregion

$VstsEndpoint = Get-VstsEndpoint -Name SystemVssConnection -Require

#region Get required PR inputs
$AccountUri = Get-VstsInput -Name 'AccountUri' -Require
$TeamProject = Get-VstsInput -Name 'TeamProject' -Require
$Repository = Get-VstsInput -Name 'Repository' -Require
#endregion

#region Get optional PR inputs
$AddCommits = (Get-VstsInput -Name AddCommitsToPR -AsBool) -and (Get-VstsTaskVariable -Name 'InsertAddCommits' -AsBool -Default 'True')
$AddCommitAuthors = (Get-VstsInput -Name AddCommitAuthorsToPR -AsBool) -or (Get-VstsTaskVariable -Name 'InsertAddCommitAuthors' -AsBool)
$LinkWorkItems = (Get-VstsInput -Name LinkWorkItemsToPR -AsBool) -and (Get-VstsTaskVariable -Name 'InsertLinkWorkItems' -AsBool -Default 'True')
$AutoComplete = (Get-VstsInput -Name AutoCompletePR -AsBool) -or (Get-VstsTaskVariable -Name 'InsertAutoComplete' -AsBool)
$SkipCreatePR = Get-VstsInput -Name SkipCreatePR -AsBool
$AllowTopicBranchUpdate = (Get-VstsInput -Name AllowTopicBranchUpdate -AsBool) -or (Get-VstsTaskVariable -Name 'InsertAllowUpdates' -AsBool)
$DraftPR = (Get-VstsInput -Name DraftPR -AsBool) -or (Get-VstsTaskVariable -Name 'InsertDraft' -AsBool)
$CommitsFile = Get-VstsInput -Name CommitsFile
$CommitsUri = Get-VstsInput -Name CommitsUri
$AddPipelineUrl = Get-VstsTaskVariable -Name 'InsertAddPipelineUrl' -AsBool -Default 'True'
$ShallowClone = (Get-VstsInput -Name ShallowClone -AsBool) -or (Get-VstsTaskVariable -Name 'ShallowClone' -AsBool)
#endregion

#region Validate inputs
# It's legit to skip inserting payload by not specifying any required fields.
# This permits us to include this step in stack of steps and skip it
# if it's already been done.
if (-not (Test-Value $TargetBranch, $ComponentJsonValues, $DefaultConfigValues, $PackagePropsValues, $AssemblyVersionsValues, $RevisionTxtFiles, $ComponentSWRFiles, $CustomScriptExecutionCommand)) {
    Write-Warning 'Skipping insert payload: TargetBranch, ComponentJsonValues, DefaultConfigValues, PackagePropsValues, AssemblyVersionsValues, RevisionTxtFiles, ComponentSWRFiles, and CustomScriptExecutionCommand are not defined.'
    Write-VstsSetResult -Result 'Skipped'
    exit 0
}
if (-not (Test-Value $TargetBranch)) {
    Write-ErrorToTelemetryThenExitWithError 'TargetBranch is not defined.'
}
if (-not (Test-Value $ComponentJsonValues, $DefaultConfigValues, $PackagePropsValues, $AssemblyVersionsValues, $RevisionTxtFiles, $ComponentSWRFiles, $CustomScriptExecutionCommand)) {
    Write-ErrorToTelemetryThenExitWithError 'ComponentJsonValues, DefaultConfigValues, PackagePropsValues, AssemblyVersionsValues, RevisionTxtFiles, ComponentSWRFiles, and CustomScriptExecutionCommand are not defined. (At least one is needed.)'
}
if (Test-Value $ComponentJsonValues) {
    $ComponentJsonValues | ForEach-Object {
        if ($_ -notmatch '^\S+\s*(\{.+?\})?\s*=\s*https:[^;]+;\S+$') {
            Write-ErrorToTelemetryThenExitWithError "$ComponentJsonValues does not match the pattern 'fileName=url[,...]'."
        }
    }
}
if (Test-Value $DefaultConfigValues) {
    $DefaultConfigValues | ForEach-Object {
        if ($_ -notmatch '^\S+\s*=\s*\S+$') {
            Write-ErrorToTelemetryThenExitWithError "$DefaultConfigValues does not match the pattern 'packageId=version[,...]'."
        }
    }
}
if (Test-Value $PackagePropsValues) {
    $PackagePropsValues | ForEach-Object {
        if ($_ -notmatch '^\S+\s*=\s*\S+$') {
            Write-ErrorToTelemetryThenExitWithError "$PackagePropsValues does not match the pattern 'packageId=version[,...]'."
        }
    }
}
if (Test-Value $AssemblyVersionsValues) {
    $AssemblyVersionsValues | ForEach-Object {
        if ($_ -notmatch '^\S+\s*=\s*[\d\.]+$') {
            Write-ErrorToTelemetryThenExitWithError "$AssemblyVersionsValues does not match the pattern 'ConstName=version[,...]'."
        }
    }
}
if (Test-Value $ComponentSWRFiles) {
    $ComponentSWRFiles | ForEach-Object {
        if ($_ -notmatch '^\S+\s*(\{.+?\})?\s*=\s*\S+$') {
            Write-ErrorToTelemetryThenExitWithError "$ComponentSWRFiles does not match the pattern 'fileName=version[,...]'."
        }
    }
}
if (Test-Value $WaitMinutes) {
    if ($WaitMinutes -notmatch '^\d+$') {
        Write-ErrorToTelemetryThenExitWithError "`$(InsertWaitMinutes) must be a positive integer; value specified was '$WaitMinutes'."
    }
    if ($WaitMinutes -match '^0+$') {
        Write-Warning "Ignoring `$(InsertWaitMinutes) because value is 0."
        $WaitMinutes = $null
    }
}
if (Test-Value $CommitsFile) {
    if (-not (Test-Path $CommitsFile -PathType Leaf)) {
        Write-ErrorToTelemetryThenExitWithError "Commits file '$CommitsFile' is missing."
    }
}

if (Test-Value $ServiceConnection)
{
    $ServiceConnectionEndPoint = Get-VstsEndpoint -Name $ServiceConnection -Require
    $AuthScheme = $ServiceConnectionEndPoint.Auth.Scheme

    # We only support the Federated Service Connections
    if ($AuthScheme -ne "WorkloadIdentityFederation")
    {
        Write-ErrorToTelemetryThenExitWithError "Invalid Service Connection Scheme '$AuthScheme'.  Only Workload Identity Federated Service Connections are supported."
    }

    # We get an OAUTH token from the service connection and overwrite the $AccessToken.  Which means if there is an SC and a PAT, the SC will override the PAT.
    $AccessToken = Get-AccessTokenFromFederatedServiceConnection -ServiceConnectionId $ServiceConnection -ClientId $ServiceConnectionEndPoint.Auth.parameters.serviceprincipalid -TenantId $ServiceConnectionEndPoint.Auth.parameters.tenantid
}

if ($AccountUri -notmatch '^https://(dev.azure.com/)?devdiv') {
    if (-not (Test-Value $AccessToken)) {
        Write-ErrorToTelemetryThenExitWithError 'AccessToken must be provided for ADO accounts other than devdiv.'
    }
    if ($LinkWorkItems) {
        Write-Warning 'Cannot link work items to PR for ADO accounts other than devdiv.'
        $LinkWorkItems = $false
    }
    if ($AddCommits) {
        Write-Warning 'Cannot add commits to PR for ADO accounts other than devdiv.'
        $AddCommits = $false
    }
    if ($AddCommitAuthors) {
        Write-Warning 'Cannot add commit authors to PR for ADO accounts other than devdiv.'
        $AddCommitAuthors = $false
    }
}
if (-not (Test-Value $TeamEmail)) {
    Write-ErrorToTelemetryThenExitWithError 'TeamEmail is not defined.'
}
if (-not (Test-Value $TeamName)) {
    Write-ErrorToTelemetryThenExitWithError 'TeamName is not defined.'
}
if (-not (Test-Value $PayloadName)) {
    $PayloadName = $TeamName
}
#endregion

function Split-DevOpsUriForGitAuth {
    if ($AccessToken) {
        if (-not ($AccountUri -match '(https://)(.+)')) {
            Write-ErrorToTelemetryThenExitWithError "Account Uri ($AccountUri) does not match 'https://.+'."
        }
        return @($Matches[1], $Matches[2])
    }
    return $null
}

function Get-CloneCommand([string]$extraArguments) {
    $arguments = "--branch $TargetBranch $extraArguments"
    $devopsUri = Split-DevOpsUriForGitAuth
    if ($devopsUri) {
        $sections = @($devopsUri[0], 'PAT:', $AccessToken, '@', $devopsUri[1], '/', $TeamProject, '/_git/', $Repository)
        return "clone $(-join $sections) $arguments"
    }
    return "-c $AuthHeader clone $AccountUri/$TeamProject/_git/$Repository $arguments"
}

function Get-JobUri {
    if ((Get-VstsTaskVariable -Name 'System' -Require) -eq 'Build') {
        return Get-VstsTaskVariable -Name 'Build.BuildUri' -Require
    }
    return Get-VstsTaskVariable -Name 'Release.ReleaseUri' -Require
}

function Get-PullCommand {
    $devopsUri = Split-DevOpsUriForGitAuth
    if ($devopsUri) {
        $sections = @($devopsUri[0], 'PAT:', $AccessToken, '@', $devopsUri[1], '/', $TeamProject, '/_git/', $Repository)
        return "pull $(-join $sections) $(Get-TopicBranchName)"
    }
    return "-c $AuthHeader pull origin $(Get-TopicBranchName)"
}

function Get-PushCommand {
    $devopsUri = Split-DevOpsUriForGitAuth
    if ($devopsUri) {
        $sections = @($devopsUri[0], 'PAT:', $AccessToken, '@', $devopsUri[1], '/', $TeamProject, '/_git/', $Repository)
        return "push $(-join $sections) $(Get-TopicBranchName)"
    }
    return "-c $AuthHeader push -u origin $(Get-TopicBranchName)"
}

function Get-SparseFiles {
    $result = @()
    if ((Test-Value $ComponentJsonValues) -or (Test-Value $DefaultConfigValues) -or (Test-Value $PackagePropsValues)) {
        $result += '.corext/Configs/*'
    }
    if (Test-Value $AssemblyVersionsValues) {
        $result += 'src/ProductData/AssemblyVersions.tt'
    }
    if ((Test-Value $PackagePropsValues) -or (Test-Value $DefaultConfigValues)) {
        $result += '*.props', 'src/ConfigData/Packages/*'
    }
    $RevisionTxtFiles | ForEach-Object {
        if (Test-Value $_) {
            $result += $_ -replace '\\', '/'
        }
    }
    $ComponentSWRFiles | ForEach-Object {
        if (Test-Value $_) {
            $fileName, $version = $_ -split "="
            $result += $fileName -replace '\\', '/'
        }
    }
    return $result
}

function Get-TopicBranchName {
    if (Test-Value $TopicBranch) {
        return $TopicBranch
    }
    $definition = Get-VstsTaskVariable -Name 'Build.DefinitionName' -Require
    $jobNumber = Get-VstsTaskVariable -Name 'Release.ReleaseName' -Default (Get-VstsTaskVariable -Name 'Build.BuildNumber' -Require)
    $tryNumber = Get-VstsTaskVariable -Name 'Release.AttemptNumber' -Default '1'
    return "temp/$TeamName/$definition-$jobNumber-$tryNumber" -replace '[\s\\]+', '-'
}

function Invoke-GitCommand ([string]$arguments, [bool]$requireExitCodeZero = $true) {
    for ($attempt = 1; $attempt -le 5; $attempt++) {
        try {
            Invoke-VstsTool -FileName git.exe -Arguments $arguments -RequireExitCodeZero:$requireExitCodeZero
            break
        }
        catch {
            if ($attempt -eq 5) {
                Write-ErrorToTelemetryThenExitWithError $_
            }
            $sleepSeconds = 5 * $attempt
            Write-WarningToTelemetryAndHost "$_ (Retrying in $sleepSeconds seconds...)"
            Start-Sleep -Seconds $sleepSeconds
        }
    }
    if ($arguments -like "checkout *") {
        Invoke-GitCommand (Get-PullCommand) -requireExitCodeZero:$false
    }
}

function Invoke-PullRequest {
    function IsIgnorableWarning([string]$message) {
        # These warnings are linked to https://dev.azure.com/devdiv/DevDiv/_workitems/edit/2301745 and will be ignored until we have time to investigate
        $ignorableWarningPatterns = @(
            "Cannot.+from vstfs:///.+/\d+: ArgumentException : 'https://github.com/.+' does not look like an Azure DevOps url",
            "Cannot extract commit details from vstfs:///.+/\d+: VssServiceException : You do not have permission to perform this action",
            "Exception creating pull request: VssServiceException : TF\d+: The pull request cannot be edited due to its state",
            "Exception updating pull request: VssServiceException : The reviewer '.+' does not have permission to view this pull request",
            "Exception updating pull request: VssUnauthorizedException : VS\d+: You are not authorized to access",
            "Exception updating pull request: AggregateException : One or more errors occurred",
            "Exception linking work item #\d+: RuleValidationException"
        )
        foreach ($pattern in $ignorableWarningPatterns) {
            if ($message -match $pattern) {
                return $true
            }
        }
        return $false
    }

    $arguments = @(
        "--account $AccountUri",
        "--project $TeamProject",
        "--repo $Repository",
        "--source ""$(Get-TopicBranchName)""",
        "--target ""$TargetBranch"""
    )
    if ($Description) {
        $arguments += "--description ""$Description"""
    }
    if ($BuildPolicies) {
        $arguments += "--buildpolicy ""$BuildPolicies"""
    }
    if ($Reviewers) {
        $arguments += "--reviewers ""$($Reviewers -join ',')"""
    }
    if ($AddCommits -or $LinkWorkItems -or $AddCommitAuthors) {
        $arguments += "--joburi $(Get-JobUri)"
    }
    if ($AddCommits) {
        $arguments += "--joburi-commits"
        if ($CommitsFile) {
            $arguments += "--joburi-commitsfile $CommitsFile"
        }
        if (-not $CommitsUri) {
            $CommitsUri = Get-VstsTaskVariable -Name 'Build.Repository.Uri'
        }
        if ($CommitsUri) {
            $arguments += "--joburi-commitsurl $CommitsUri"
        }
    }
    if ($AddCommitAuthors) {
        $arguments += "--joburi-authors"
    }
    if ($LinkWorkItems) {
        $arguments += "--joburi-items"
    }
    if ($AutoComplete) {
        $arguments += "--autocomplete"
        if ($MergeStrategy) {
            $arguments += "--mergestrategy $MergeStrategy"
        }
    }
    if ($WaitMinutes) {
        $arguments += "--waitcomplete-minutes $WaitMinutes"
    }
    if ($AccessToken) {
        $arguments += "--token ""$AccessToken"" --tokentype PAT"
    }
    else {
        $arguments += "--token $($VstsEndpoint.Auth.Parameters.AccessToken)"
    }
    if ($AllowTopicBranchUpdate) {
        $arguments += "--allowalreadyexists"
    }
    if ($DraftPR) {
        $arguments += "--draft"
    }
    if($AddPipelineUrl) {
        $arguments += "--pipeurl"
    }
    if($PRTitle) {
        $arguments += "--title ""$PRTitle"""
    }
    else {
        $arguments += "--title ""Insert $PayloadName Payload into $TargetBranch"""
    }

    $parameters = @{
        FileName = "$PSScriptRoot\SubmitPullRequest.exe"            # Source code: https://dev.azure.com/devdiv/DevDiv/_git/PostBuildSteps?path=/src/SubmitPullRequest
        Arguments = ($arguments -join ' ')
    }
    Invoke-VstsTool @parameters 2>&1 | ForEach-Object {
        if ($_ -is [System.Management.Automation.ErrorRecord]) {
            Write-ErrorToTelemetryThenExitWithError $_.Exception.Message
        }
        elseif ($_ -match '^WARNING: .+') {
            if (IsIgnorableWarning $_) {
              Write-Host $_
            }
            else {
              Write-WarningToTelemetryAndHost $_
            }
        }
        else {
            Write-Host $_
            if ($_ -match 'https:.+?/pullrequest/\d+') {
                $stagingFolder = Get-VstsTaskVariable -Name 'Build.StagingDirectory' -Default (Get-VstsTaskVariable -Name 'System.DefaultWorkingDirectory' -Require)
                $markdownFolder = Join-Path $stagingFolder (Join-Path 'MicroBuild' 'Output')
                New-Item -ItemType Directory -Force -Path $markdownFolder | Out-Null
                $markdownFile = Join-Path $markdownFolder 'PullRequestUrl.md'
                $Matches[0] | Set-Content $markdownFile
                Write-VstsAddAttachment -Type "Distributedtask.Core.Summary" -Name "Insertion pull request" -Path $markdownFile
                Write-Telemetry "PullRequestUrl" $Matches[0]
            }
        }
    }
    if ($LASTEXITCODE -ne 0) {
        Write-VstsSetResult -Result SucceededWithIssues
    }
}

function Update-ComponentsJson {
    $componentJsonPath = Join-Path $PWD '.corext\Configs\components.json'
    if (Test-Value $ComponentJsonValues) {
        $jsonInfos = @(); $jsonFolder = Split-Path $componentJsonPath -Parent
        $jsonInfo = ConvertTo-JsonInfo $componentJsonPath
        if ($jsonInfo.Quantity -gt 0) {
            $jsonInfos += $jsonInfo
        }
        foreach ($import in $jsonInfo.Imports) {
            $importPath = Join-Path $jsonFolder $import
            if (Test-Path $importPath -PathType Leaf) {
                $jsonInfos += ConvertTo-JsonInfo $importPath
            }
            else {
                Write-Warning "Cannot find $componentJsonPath import file $importPath"
            }
        }
        $startProtocol = [Net.ServicePointManager]::SecurityProtocol
        $ComponentJsonValues | ForEach-Object {
            $updated = $false
            #if filename has version extract it and also extract filename and url
            if ($_ -match  '^(\S+?)\s*(\{.+?\})?\s*=\s*(\S+)') {
                $fileName = $Matches[1].Trim()
                $version = $Matches[2] -replace '[{}]',''
                $url = $Matches[3].Trim()
                if ([string]::IsNullOrEmpty($version)) {
                    try {
                        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                        $downloadedFilePath = [IO.Path]::GetTempFileName()
                        $wc = New-Object System.Net.WebClient
                        # $wc.UseDefaultCredentials = $true

                        # $wcAccessToken = $AccessToken
                        # if (-not $wcAccessToken) {
                        #     $wcAccessToken = $VstsEndpoint.Auth.Parameters.AccessToken
                        # }
                        # $wcAccessToken = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes(":$wcAccessToken"))
                        # $wc.Headers.Add("Authorization", "Bearer $wcAccessToken")

                        $wcAccessToken = ConvertTo-SecureString -String $AccessToken -AsPlainText -Force
                        # $wc.Credentials = New-Object System.Net.NetworkCredential($null, $wcAccessToken)
                        $wc.Credentials = New-Object System.Management.Automation.PSCredential("PAT", $wcAccessToken)

                        $wc.DownloadFile($url, $downloadedFilePath)
                        $manifestJson = Get-Content -Raw $downloadedFilePath | ConvertFrom-Json
                        if ((Get-Member -InputObject $manifestJson -Name "info" -MemberType NoteProperty) -And (Get-Member -InputObject $manifestJson.info -Name "buildVersion" -MemberType NoteProperty)) {
                            $version = $manifestJson.info.buildVersion
                            Write-Host "Reading version from $url file"
                        }
                    }
                    catch [Exception] {
                        Write-Warning "Failed to parse the file $url as json. Exception: $_ "
                    }
                    finally {
                        [Net.ServicePointManager]::SecurityProtocol = $startProtocol
                        Remove-Item $downloadedFilePath -ErrorAction SilentlyContinue
                    }
                }
                if ($null -ne $version){
                    $version = $version.Trim()
                }
            }
            foreach ($jsonInfo in $jsonInfos) {
                $updated = Set-ComponentUrlAndVersion $jsonInfo $fileName $url $version
                if ($updated) {
                    break
                }
            }
            if (-not $updated) {
                Write-ErrorToTelemetryThenExitWithError "Did not find $fileName in $componentJsonPath or its imports."
            }
        }
        $jsonInfos | Where-Object Updated | ForEach-Object {
            Write-Host "Updating $($_.JsonPath)"
            Set-Content -Path $_.JsonPath -Value (ConvertTo-Json $_.JsonObject | Format-Json)
        }
    }
    else {
        Write-Host "Skipping update of $($componentJsonPath): No values supplied."
    }
}

function ConvertTo-JsonInfo {
    [OutputType('JsonInfo')]
    [CmdletBinding()]
    param (
        [string]$componentJsonPath
    )
    $jsonObject = Get-Content -Path $componentJsonPath -Raw | ConvertFrom-Json
    $components = $jsonObject.Components.PSObject.Properties
    return [PSCustomObject]@{
        PSTypeName = 'JsonInfo'
        JsonPath = $componentJsonPath
        JsonObject = $jsonObject
        Imports = $jsonObject.Imports
        Components = $components
        Quantity = $components | Measure-Object | Select-Object -ExpandProperty Count
        Updated = $false
    }
}

function Set-ComponentUrlAndVersion ([PSTypeName('JsonInfo')]$jsonInfo, [string]$fileName, [string]$url, [string]$version) {
    Write-Verbose "Checking $($jsonInfo.Quantity) components in $($jsonInfo.JsonPath) for $fileName"
    Write-Host "Checking $($jsonInfo.JsonPath) for $fileName"
    foreach ($component in $jsonInfo.Components) {
        if ($component.value.fileName -eq $fileName) {
            Write-Verbose "Checking $($jsonInfo.Quantity) components in $($jsonInfo.JsonPath) for $fileName succeeded"
            $component.value.url = $url
            if (![string]::IsNullOrWhiteSpace($version)){
                if (Get-Member -InputObject $component.value -Name "version" -MemberType NoteProperty) {
                    $component.value.version = $version
                }
                else {
                    $component.value | Add-Member -Name "version" -Value $version -MemberType NoteProperty
                }
            }
            $jsonInfo.Updated = $true
            return $true
        }
    }
    return $false
}

function Format-Json([Parameter(Mandatory, ValueFromPipeline)][string]$json) {
    $indent = 0
    ($json -Split '\n' | ForEach-Object {
        if ($_ -match '[\}\]]') {
            # This line contains  ] or }, decrement the indentation level
            $indent--
        }
        $line = (' ' * $indent * 2) + $_.TrimStart().Replace(':  ', ': ')
        if ($_ -match '[\{\[]') {
            # This line contains [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

# Returns an array of package configs paths listed in default.config (full paths), including the default.config path.
function Get-PackageConfigFiles([string] $defaultConfigPath) {
    $defaultConfigPath = Resolve-Path $defaultConfigPath
    [xml]$defaultConfigXml = Get-Content $defaultConfigPath
    if ($null -eq $defaultConfigXml.corext.additionalPackageConfigs -or $null -eq $defaultConfigXml.corext.additionalPackageConfigs.config) {
        return @($defaultConfigPath)
    }

    $packageConfigs = $defaultConfigXml.corext.additionalPackageConfigs.config
    $configsFolder = Split-Path ($defaultConfigPath) -Parent
    $packageConfigs = $packageConfigs | ForEach-Object { Join-Path $configsFolder $_.name }
    return @($packageConfigs) + $defaultConfigPath
}

function Update-DataFiles([string[]]$values, [string]$rootFile, [ScriptBlock]$getPaths, [ScriptBlock]$tryMatch, [ScriptBlock]$doUpdate, [string[]]$optionalValues = @()) {
    $result = @{Content=@{};Replace=@{}}

    function getContent($path) {
        if ($result.Replace[$path]) {
            return $result.Replace[$path]
        }
        if (-not $result.Content[$path]) {
            $result.Content[$path] = Get-Content $path
        }
        return $result.Content[$path]
    }
    
    if ((Test-Value $values) -or (Test-Value $optionalValues)) {
        # The packages below have special treatment; we don't want them pulled in as optional
        # because they're allowed to differ between default.config and packages.props/Directory.Packages.props
        $excludes = @('System.Collections.Immutable', 'System.Reflection.Metadata')
        $optional = @($optionalValues | Where-Object {$_} | Where-Object {
            $subject, $version = $_ -split '=' | ForEach-Object Trim
            # If the subject is in both lists, exclude it as it might have different
            # version values between config and props files. (Discouraged but there
            # are the 2 cases above at present and we want to allow for the possibility
            # in future if needed.)
            foreach ($value in $values) {
                if ($value -match "^\s*$subject\s*=") {
                    return $false
                }
            }
            return $true
        } | Where-Object {
            $subject, $version = $_ -split '=' | ForEach-Object Trim
            return $subject -notin $excludes
        })
        $allValues = @($values | Where-Object {$_}) + $optional
        $updates = @()
        foreach ($path in (&$getPaths)) {
            foreach ($value in ($allValues | Where-Object {$_ -notin $updates})) {
                $subject, $version = $value -split '=' | ForEach-Object Trim
                Write-Host "Checking $path for $subject"
                $content = getContent $path
                foreach ($index in 0 .. ($content.Length - 1)) {
                    if (&$tryMatch $content[$index] $subject) {
                        $update = &$doUpdate $content[$index] $version
                        if ($update -eq $content[$index]) {
                            Write-Host "Detected $subject is already at $version; skipping update"
                        }
                        else {
                            Write-Host "Updating $path with $subject $version"
                            $result.Replace[$path] = $content
                            $content[$index] = $update
                        }
                        $updates += $value
                        break
                    }
                }
            }
            if ($updates.Length -eq $allValues.Length) {
                break
            }
        }
        $missing = $values | Where-Object {$_ -notin $updates} | Where-Object {$_ -notin $optional}
        if ($missing) {
            Write-ErrorToTelemetryThenExitWithError "Did not find $($missing -join ' or ') in $rootFile or any related files."
        }
        elseif ($updates.Length -gt 0) {
            foreach ($path in $result.Replace.Keys) {
                Write-Host "Updating $path"
                Set-Content -Path $path -Value ($result.Replace[$path] | Out-String) -NoNewline
            }
        }
    }
    else {
        Write-Host "Skipping update of $rootFile or any related files: No values supplied."
    }
}

function Update-PackageConfigs([string]$defaultConfigPath) {
    $getPaths = { Get-PackageConfigFiles $defaultConfigPath }
    $doUpdate = { param([string]$textLine, [string]$version) $textLine -replace 'version=".+?"', "version=""$version""" }
    $tryMatch = { param([string]$textLine, [string]$package) $textLine -match "^\s+<package id=""$package""" }

    Update-DataFiles -values $DefaultConfigValues -rootFile $defaultConfigPath -getPaths $getPaths -tryMatch $tryMatch -doUpdate $doUpdate -optionalValues $PackagePropsValues
}

function Update-PackageProps([string]$packagePropsPath) {
    $packagePropsFilter = "$PWD\src\ConfigData\Packages\*.props"
    if ((Test-Path $packagePropsPath) -and (Test-Path $packagePropsFilter)) {
        $getPaths = { @(Get-ChildItem $packagePropsFilter -Recurse | ForEach-Object FullName) + $packagePropsPath }
        $doUpdate = { param([string]$textLine, [string]$version) $textLine -replace 'Version=".+?"', "Version=""$version""" }
        $tryMatch = { param([string]$textLine, [string]$package) $textLine -match """$package""" }
        
        Update-DataFiles -values $PackagePropsValues -rootFile $packagePropsPath -getPaths $getPaths -tryMatch $tryMatch -doUpdate $doUpdate -optionalValues $DefaultConfigValues
    }
    elseif (Test-Value $PackagePropsValues) {
        Write-ErrorToTelemetryThenExitWithError "Values were specified for $packagePropsPath and $packagePropsFilter but one or more of those files are missing."
    }
    else {
        Write-Host "Skipping updates to $packagePropsPath and ${packagePropsFilter}: files are missing and values not specified."
    }
}

function Update-AssemblyVersions([string]$assemblyVersionsPath) {
    $getPaths = { @($assemblyVersionsPath) }
    $doUpdate = { param([string]$textLine, [string]$version) $textLine -replace '"[\d\.]+";', """$version"";" }
    $tryMatch = { param([string]$textLine, [string]$component) $textLine -match "\s+const string $component\s+" }

    Update-DataFiles -values $AssemblyVersionsValues -rootFile $assemblyVersionsPath -getPaths $getPaths -doUpdate $doUpdate -tryMatch $tryMatch
}

function Update-RevisionTxtFiles {
    if (Test-Value $RevisionTxtFiles) {
        $RevisionTxtFiles | ForEach-Object {
            $fileName = Join-Path $PWD $_
            if (-not (Test-Path $fileName)) {
                Write-ErrorToTelemetryThenExitWithError "Did not find $fileName."
            }
            Write-Host "Updating $fileName"
            $content = Get-Content $fileName -Head 1
            Set-Content $fileName ([Convert]::ToInt32($content) + 1), (New-Guid)
        }
    }
    else {
        Write-Host "Skipping update of revision.txt files: No files specified."
    }
}

function Update-ComponentSWRFiles {
    if (Test-Value $ComponentSWRFiles) {
        Write-Host "Updating Component.swr file: $ComponentSWRFiles"
        $ComponentSWRFiles | ForEach-Object {
            $fileName, $version = $_ -split "="
            $fileName = Join-Path $PWD $fileName
            if (-not (Test-Path $fileName)) {
                Write-ErrorToTelemetryThenExitWithError "Did not find $fileName."
            }
            Write-Host "Updating $fileName"
            $content = Get-Content $fileName
            $replace = $content -replace 'version=([0-9].*)', "version=$version"
            $replace | Set-Content -Path $fileName
        }
    }
    else {
        Write-Host "Skipping update of component.swr files: No files specified."
    }
}

#region Write telemetry
Set-VstsTaskVariable 'MicroBuildEvent' 'Insertion' # Ensure telemetry for this step is reported as an insertion

Write-Telemetry "TargetBranch" $TargetBranch
if (Test-Value $ComponentJsonValues) {
    Write-Telemetry "ComponentJsonValues" ($ComponentJsonValues -join ',')
}
if (Test-Value $DefaultConfigValues) {
    Write-Telemetry "DefaultConfigValues" ($DefaultConfigValues -join ',')
}
if (Test-Value $PackagePropsValues) {
    Write-Telemetry "PackagePropsValues" ($PackagePropsValues -join ',')
}
if (Test-Value $AssemblyVersionsValues) {
    Write-Telemetry "AssemblyVersionsValues" ($AssemblyVersionsValues -join ',')
}
if (Test-Value $RevisionTxtFiles) {
    Write-Telemetry "RevisionTxtFiles" ($RevisionTxtFiles -join ',')
}
if (Test-Value $ComponentSWRFiles) {
    Write-Telemetry "ComponentSWRFiles" ($ComponentSWRFiles -join ',')
}
if (Test-Value $CustomScriptExecutionCommand) {
    Write-Telemetry "CustomScriptExecutionCommand" ($CustomScriptExecutionCommand)
}
Write-Telemetry "AutoCompleteValue" (ValueOrDefault $AutoComplete 'False')
if ($AutoComplete) {
    Write-Telemetry "AutoCompleteMergeStrategyValue" (ValueOrDefault $MergeStrategy 'None')
}
Write-Telemetry "SkipCreatePRValue" (ValueOrDefault $SkipCreatePR 'False')
Write-Telemetry "BuildPoliciesQueued" (ValueOrDefault $BuildPolicies 'None')
Write-TelemetryMetricStartSeconds "Insert VS Payload"
#endregion

# Have data; now let's get a sparse checkout on the target branch and update the values in the files
Set-Location (Get-VstsTaskVariable -Name 'System.DefaultWorkingDirectory' -Require)
$RepoFolder = Join-Path $PWD $Repository
if (Test-Path $RepoFolder) {
    Remove-Item -Path $RepoFolder -Recurse -Force | Out-Null
}
$AuthHeader = "http.extraheader=""AUTHORIZATION: bearer $($VstsEndpoint.Auth.Parameters.AccessToken)"""

$additionalCloneArguments = ''
if ($ShallowClone) {
    $additionalCloneArguments = '--depth 1'
}

if (Test-Value $CustomScriptExecutionCommand) {
    Invoke-GitCommand (Get-CloneCommand $additionalCloneArguments)
}
else {
    Invoke-GitCommand (Get-CloneCommand "$additionalCloneArguments --no-checkout")
}

Set-Location $RepoFolder
Invoke-GitCommand "config user.name ""$TeamName"""
Invoke-GitCommand "config user.email $TeamEmail"

if (Test-Value $CustomScriptExecutionCommand) {
    Invoke-GitCommand "checkout -B $(Get-TopicBranchName) $TargetBranch"
    Write-Host "##[command] $CustomScriptExecutionCommand"
    Invoke-Expression $CustomScriptExecutionCommand
}
else {
    Invoke-GitCommand "config core.sparsecheckout true"

    $SparseCheckoutFile = '.git\info\sparse-checkout'
    Get-SparseFiles | Set-Content -Path $SparseCheckoutFile
    Write-Host 'Creating sparse checkout for these files:'
    Get-Content -Path $SparseCheckoutFile
    Invoke-GitCommand "checkout -B $(Get-TopicBranchName) $TargetBranch"
}

Update-ComponentsJson

# In the future, if and when the file default.config goes away, we need to detect that case
if (Test-Path -Path "$PWD\.corext\Configs\default.config" -PathType Leaf) {
    Update-PackageConfigs "$PWD\.corext\Configs\default.config"
}
else {
    Write-Host "Skipping default.config: Does not exist."
}

if (Test-Path -Path "$PWD\Packages.props" -PathType Leaf) {
    Update-PackageProps "$PWD\Packages.props"
} elseif (Test-Path -Path "$PWD\Directory.Packages.props" -PathType Leaf) {
    Update-PackageProps "$PWD\Directory.Packages.props"
} elseif (Test-Value $PackagePropsValues) {
    Write-ErrorToTelemetryThenExitWithError "Neither $PWD\Packages.props nor $PWD\Directory.Packages.props exist. Unable to update Package props"
}

Update-AssemblyVersions "$PWD\src\ProductData\AssemblyVersions.tt"
Update-RevisionTxtFiles
Update-ComponentSWRFiles

Invoke-GitCommand "add ."
Invoke-GitCommand "commit -m ""Insert $PayloadName payload into $TargetBranch"""
Invoke-GitCommand (Get-PushCommand)

if ($SkipCreatePR) {
    Write-Host "Skipping PR creation: The Skip Create Pull Request input was specified."
}
else {
    Invoke-PullRequest
}

Write-TelemetryMetricFinishSeconds "Insert VS Payload"
