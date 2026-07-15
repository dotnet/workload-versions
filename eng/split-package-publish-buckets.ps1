# This script splits package files into publish buckets.
# The buckets are:
# 1) packs: all non-manifest packages except the workload set package
# 2) manifests: package IDs containing 'manifest'
# 3) workloadSet: package IDs starting with Microsoft.NET.Workloads. (including architecture-specific MSI variants)

param (
  [Parameter(Mandatory = $true)] [string] $packagesPath
)

Add-Type -AssemblyName System.IO.Compression.FileSystem

$workloadSetPrefix = 'microsoft.net.workloads.'
$manifestPattern = 'manifest'

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
    if ([string]::IsNullOrWhiteSpace($id)) {
      throw "Package ID is missing in '$packageFilePath'."
    }

    return $id
  } finally {
    $archive.Dispose()
  }
}

$packagesPath = (Resolve-Path -Path $packagesPath).Path
$bucketRoot = Join-Path -Path $packagesPath -ChildPath 'publishBuckets'

if (Test-Path -Path $bucketRoot) {
  Remove-Item -Path $bucketRoot -Recurse -Force
}

$bucketDirectories = @{
  packs       = (Join-Path -Path $bucketRoot -ChildPath 'packs')
  manifests   = (Join-Path -Path $bucketRoot -ChildPath 'manifests')
  workloadSet = (Join-Path -Path $bucketRoot -ChildPath 'workloadSet')
}

$bucketDirectories.Values | ForEach-Object {
  $null = New-Item -Path $_ -ItemType Directory -Force
}

$allPackages = Get-ChildItem -Path $packagesPath -Recurse -Filter *.nupkg -File | Where-Object { $_.FullName -notlike "$bucketRoot*" }
if (-not $allPackages) {
  throw "No .nupkg files found under '$packagesPath'."
}

foreach ($package in $allPackages) {
  $packageId = Get-PackageMetadata -packageFilePath $package.FullName

  $packageIdLower = $packageId.ToLowerInvariant()

  $bucketName = 'packs'
  if ($packageIdLower.StartsWith($workloadSetPrefix)) {
    $bucketName = 'workloadSet'
  } elseif ($packageIdLower -match $manifestPattern) {
    $bucketName = 'manifests'
  }

  Copy-Item -Path $package.FullName -Destination $bucketDirectories[$bucketName] -Force
}

Write-Host "Split packages under '$packagesPath' into publish buckets:"
$bucketDirectories.GetEnumerator() | ForEach-Object {
  $count = (Get-ChildItem -Path $_.Value -Filter *.nupkg -File).Count
  Write-Host "  $($_.Key): $count"
}
