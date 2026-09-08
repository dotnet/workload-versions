[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)] [string] $KeyVaultName,
  [Parameter(Mandatory=$true)] [string] $AppSecretName,
  [Parameter(Mandatory=$true)] [string] $InstallationOwner,
  [Parameter(Mandatory=$true)] [string] $OutputVariableName
)

$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true

Import-Module "$PSScriptRoot/GitHubAppToken.psm1" -Force

function Get-KeyVaultSecretValue {
  param([Parameter(Mandatory=$true)] [string] $Name)

  $secretJson = az keyvault secret show `
    --vault-name $KeyVaultName `
    --name $Name `
    --output json `
    --only-show-errors
  if ($LASTEXITCODE -ne 0) {
    throw "Failed to read secret '$Name' from Key Vault '$KeyVaultName'."
  }

  ($secretJson | ConvertFrom-Json).value
}

$appId = Get-KeyVaultSecretValue "$AppSecretName-app-id"
$privateKey = Get-KeyVaultSecretValue "$AppSecretName-app-private-key"

try {
  $jwt = New-GitHubAppJwt -AppId $appId -PrivateKeyPem $privateKey
  $tokenResponse = Get-GitHubAppInstallationToken `
    -Jwt $jwt `
    -InstallationOwner $InstallationOwner
}
finally {
  $privateKey = $null
}

if ([string]::IsNullOrWhiteSpace($tokenResponse.token)) {
  throw "GitHub did not return an installation token for '$InstallationOwner'."
}

Write-Host "Got an installation token for '$InstallationOwner' that expires at $($tokenResponse.expires_at)."
Write-Host "##vso[task.setvariable variable=$OutputVariableName;issecret=true]$($tokenResponse.token)"
