$ErrorActionPreference = 'Stop'

Import-Module "$PSScriptRoot/../GitHubAppToken.psm1" -Force

function Assert-Equal {
  param($Expected, $Actual, [string] $Message)
  if ($Expected -ne $Actual) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function ConvertFrom-Base64Url {
  param([Parameter(Mandatory=$true)] [string] $Value)

  $base64 = $Value.Replace('-', '+').Replace('_', '/')
  switch ($base64.Length % 4) {
    2 { $base64 += '==' }
    3 { $base64 += '=' }
  }
  [Convert]::FromBase64String($base64)
}

$rsa = [Security.Cryptography.RSA]::Create(2048)
try {
  $privateKey = $rsa.ExportRSAPrivateKeyPem()
  $now = [DateTimeOffset]::Parse('2026-09-08T20:00:00Z')
  $jwt = New-GitHubAppJwt -AppId '4876385' -PrivateKeyPem $privateKey -Now $now
  $segments = $jwt.Split('.')

  Assert-Equal 3 $segments.Count 'JWT must have three segments.'
  $header = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $segments[0])) | ConvertFrom-Json
  $payload = [Text.Encoding]::UTF8.GetString((ConvertFrom-Base64Url $segments[1])) | ConvertFrom-Json
  Assert-Equal 'RS256' $header.alg 'JWT algorithm is incorrect.'
  Assert-Equal '4876385' $payload.iss 'JWT issuer is incorrect.'
  Assert-Equal $now.AddMinutes(-1).ToUnixTimeSeconds() $payload.iat 'JWT issued-at time is incorrect.'
  Assert-Equal $now.AddMinutes(5).ToUnixTimeSeconds() $payload.exp 'JWT expiration is incorrect.'

  $signatureValid = $rsa.VerifyData(
    [Text.Encoding]::UTF8.GetBytes("$($segments[0]).$($segments[1])"),
    (ConvertFrom-Base64Url $segments[2]),
    [Security.Cryptography.HashAlgorithmName]::SHA256,
    [Security.Cryptography.RSASignaturePadding]::Pkcs1)
  Assert-Equal $true $signatureValid 'JWT signature is invalid.'
}
finally {
  $privateKey = $null
  $rsa.Dispose()
}

$requests = [Collections.Generic.List[object]]::new()
$requestInvoker = {
  param($Method, $Uri, $Headers, $Body)

  $requests.Add([pscustomobject]@{
    Method = $Method
    Uri = $Uri
    Body = $Body
  })
  if ($Method -eq 'GET') {
    return @([pscustomobject]@{
      id = 42
      account = [pscustomobject]@{ login = 'dotnet' }
    })
  }
  [pscustomobject]@{
    token = 'test-installation-token'
    expires_at = '2026-09-08T21:00:00Z'
  }
}.GetNewClosure()

$response = Get-GitHubAppInstallationToken `
  -Jwt 'test-jwt' `
  -InstallationOwner 'dotnet' `
  -GitHubApiUrl 'https://example.invalid' `
  -RequestInvoker $requestInvoker

Assert-Equal 'test-installation-token' $response.token 'Installation token was not returned.'
Assert-Equal 2 $requests.Count 'Unexpected number of GitHub API requests.'
Assert-Equal 'GET' $requests[0].Method 'The first request must list installations.'
Assert-Equal 'POST' $requests[1].Method 'The second request must mint a token.'
Assert-Equal 'read' (($requests[1].Body | ConvertFrom-Json).permissions.contents) 'Token permissions were not downscoped.'

$officialPipeline = Get-Content "$PSScriptRoot/../pipelines/official.yml" -Raw
$workloadJob = Get-Content "$PSScriptRoot/../pipelines/templates/jobs/workload-build.yml" -Raw
if ($officialPipeline -match 'DotNetBot-GitHub-AllBranches' -or $workloadJob -match 'BotAccount-dotnet-bot-repo-PAT') {
  throw 'The workload pipeline must not retain a fallback to BotAccount-dotnet-bot-repo-PAT.'
}

Write-Host 'GitHub App token tests passed.'
