param(
  [string] $primaryBranchesJson = '[]',
  [string] $secondaryBranchesJson = '[]',
  [string] $topicBranch = '|default|'
)

$ErrorActionPreference = 'Stop'
$primaryBranches = @(ConvertFrom-Json -InputObject $primaryBranchesJson)
$secondaryBranches = @(ConvertFrom-Json -InputObject $secondaryBranchesJson)
$branches = @($primaryBranches + $secondaryBranches)
$destinations = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($branch in $branches) {
  $null = $destinations.Add($branch)
}

$matrices = @{}
foreach ($kind in @('primary', 'secondary')) {
  $targets = $primaryBranches
  if ($kind -eq 'secondary') {
    $targets = $secondaryBranches
  }
  $matrix = [ordered]@{}
  for ($index = 0; $index -lt $targets.Count; $index++) {
    $matrix["Target$index"] = @{ InsertionTarget = $targets[$index] }
  }
  # A disabled job still needs a valid matrix during pipeline expansion.
  if ($matrix.Count -eq 0) {
    $matrix['NoInsertion'] = @{ InsertionTarget = '' }
  }
  $matrices[$kind] = $matrix
}

[pscustomobject]@{
  parallel = $branches.Count -gt 1 -and $destinations.Count -eq $branches.Count -and $topicBranch -in '|default|', '|temp|'
  primaryEnabled = $primaryBranches.Count -gt 0
  secondaryEnabled = $secondaryBranches.Count -gt 0
  primaryMatrix = $matrices.primary
  secondaryMatrix = $matrices.secondary
}
