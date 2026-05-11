# This script waits for package versions to appear on a NuGet V3 feed.
# It polls package versions sequentially using the interval configured below.

param (
  [Parameter(Mandatory = $true)] [string] $packagesPath,
  [Parameter(Mandatory = $true)] [string] $feedIndexUrl
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Get-PackageMetadata {
  param (
    [Parameter(Mandatory = $true)] [string] $packageFilePath
  )

  $archive = [System.IO.Compression.ZipFile]::OpenRead($packageFilePath)
  try {
    $nuspecEntry = $archive.Entries | Where-Object { $_.Name.EndsWith('.nuspec', [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    if (-not $nuspecEntry) {
      throw "Could not find .nuspec in package '$packageFilePath'."
    }

    $stream = $nuspecEntry.Open()
    try {
      $reader = New-Object System.IO.StreamReader($stream)
      try {
        $nuspecXml = [xml]$reader.ReadToEnd()
      } finally {
        $reader.Dispose()
      }
    } finally {
      $stream.Dispose()
    }

    $id = $nuspecXml.package.metadata.id
    $version = $nuspecXml.package.metadata.version
    if ([string]::IsNullOrWhiteSpace($id) -or [string]::IsNullOrWhiteSpace($version)) {
      throw "Package ID/version is missing in '$packageFilePath'."
    }

    return @{
      Id      = $id
      Version = $version
    }
  } finally {
    $archive.Dispose()
  }
}

function Get-PackageBaseAddress {
  param (
    [Parameter(Mandatory = $true)] [string] $indexUrl
  )

  $index = Invoke-RestMethod -Method Get -Uri $indexUrl
  $resource = $index.resources | Where-Object { $_.'@type' -like 'PackageBaseAddress/3.0.0*' } | Select-Object -First 1
  if (-not $resource) {
    throw "Could not find PackageBaseAddress in '$indexUrl'."
  }

  return $resource.'@id'.TrimEnd('/')
}

$packagesPath = (Resolve-Path -Path $packagesPath).Path
$packageFiles = Get-ChildItem -Path $packagesPath -Filter *.nupkg -File
if (-not $packageFiles) {
  throw "No .nupkg files found under '$packagesPath'."
}

$packageBaseAddress = Get-PackageBaseAddress -indexUrl $feedIndexUrl
$pollingIntervalSeconds = 300
$maxAttempts = 60

foreach ($packageFile in $packageFiles) {
  $packageMetadata = Get-PackageMetadata -packageFilePath $packageFile.FullName
  $idLower = $packageMetadata.Id.ToLowerInvariant()
  $versionLower = $packageMetadata.Version.ToLowerInvariant()
  $registrationUrl = "$packageBaseAddress/$idLower/index.json"

  Write-Host "Waiting for $($packageMetadata.Id) $($packageMetadata.Version) on $feedIndexUrl"

  $isAvailable = $false
  for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
    try {
      $registrationIndex = Invoke-RestMethod -Method Get -Uri $registrationUrl
      if ($registrationIndex.versions -contains $versionLower) {
        Write-Host "  Available after attempt $attempt."
        $isAvailable = $true
        break
      }

      Write-Host "  Not available yet (attempt $attempt of $maxAttempts)."
    } catch {
      Write-Host "  Failed to query package index on attempt $attempt of $maxAttempts. Error: $($_.Exception.Message)"
    }

    if ($attempt -lt $maxAttempts) {
      Start-Sleep -Seconds $pollingIntervalSeconds
    }
  }

  if (-not $isAvailable) {
    throw "Timed out waiting for $($packageMetadata.Id) $($packageMetadata.Version) in '$feedIndexUrl'."
  }
}
