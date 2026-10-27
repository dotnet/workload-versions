$ErrorActionPreference = 'Stop'

function Assert-Equal {
  param($Expected, $Actual, [string] $Message)
  if ($Expected -ne $Actual) {
    throw "$Message Expected '$Expected', got '$Actual'."
  }
}

function New-Plan {
  param([string[]] $Primary = @(), [string[]] $Secondary = @(), [string] $Topic = '|default|')
  & "$PSScriptRoot/../create-vs-insertion-plan.ps1" `
    -primaryBranchesJson (ConvertTo-Json -InputObject @($Primary) -Compress) `
    -secondaryBranchesJson (ConvertTo-Json -InputObject @($Secondary) -Compress) `
    -topicBranch $Topic
}

$plan = New-Plan -Primary @('main', 'release/dev18.0') -Secondary @('release/dev17.14')
Assert-Equal $true $plan.parallel 'Independent destinations must run in parallel.'
Assert-Equal 2 $plan.primaryMatrix.Count 'Every primary insertion must have one matrix leg.'
Assert-Equal 'main' $plan.primaryMatrix.Target0.InsertionTarget 'Preserve the first primary target.'
Assert-Equal 'release/dev18.0' $plan.primaryMatrix.Target1.InsertionTarget 'Preserve the second primary target.'
Assert-Equal 'release/dev17.14' $plan.secondaryMatrix.Target0.InsertionTarget 'Preserve secondary targets separately.'
Assert-Equal $true $plan.primaryEnabled 'Primary jobs must be enabled when configured.'
Assert-Equal $true $plan.secondaryEnabled 'Secondary jobs must be enabled when configured.'

foreach ($topic in @('|default|', '|temp|')) {
  $plan = New-Plan -Secondary @('main', 'release/dev17.14') -Topic $topic
  Assert-Equal $true $plan.parallel 'Target-specific generated topics allow parallel insertion.'
  Assert-Equal $false $plan.primaryEnabled 'An empty primary list must not insert anything.'
  Assert-Equal 1 $plan.primaryMatrix.Count 'Disabled jobs must still have a valid placeholder matrix.'
  $roundTrip = $plan.secondaryMatrix | ConvertTo-Json -Compress | ConvertFrom-Json
  Assert-Equal 'release/dev17.14' $roundTrip.Target1.InsertionTarget 'Matrix outputs must survive JSON transport.'
}

foreach ($topic in @('temp/shared-insertion', '')) {
  $plan = New-Plan -Primary @('main') -Secondary @('release/dev17.14') -Topic $topic
  Assert-Equal $false $plan.parallel 'Custom or task-generated topics must retain serial behavior.'
}

foreach ($duplicates in @(
  @{ Primary = @('main', 'main'); Secondary = @() }
  @{ Primary = @('main'); Secondary = @('main') }
  @{ Primary = @(); Secondary = @('main', 'MAIN') }
)) {
  $plan = New-Plan @duplicates
  Assert-Equal $false $plan.parallel 'Duplicate effective destinations must retain serial behavior.'
  Assert-Equal ($duplicates.Primary.Count + $duplicates.Secondary.Count) @(
    if ($plan.primaryEnabled) { $plan.primaryMatrix.Values }
    if ($plan.secondaryEnabled) { $plan.secondaryMatrix.Values }
  ).Count 'Do not deduplicate or lose serial insertions.'
}

foreach ($single in @(
  @{ Primary = @('main'); Secondary = @() }
  @{ Primary = @(); Secondary = @('main') }
  @{ Primary = @(); Secondary = @() }
)) {
  $plan = New-Plan @single
  Assert-Equal $false $plan.parallel 'Zero or one insertion must not incur another agent startup.'
  Assert-Equal ($single.Primary.Count -gt 0) $plan.primaryEnabled 'Only configured primary insertions are enabled.'
  Assert-Equal ($single.Secondary.Count -gt 0) $plan.secondaryEnabled 'Only configured secondary insertions are enabled.'
}

$targets = @('release/a.b', 'release/a-b', 'release/a_b', 'release/100%0A')
$plan = New-Plan -Primary $targets
Assert-Equal $true $plan.parallel 'Different branch names must not collide after job-name normalization.'
Assert-Equal $targets.Count $plan.primaryMatrix.Count 'Branch punctuation must not lose destinations.'
for ($index = 0; $index -lt $targets.Count; $index++) {
  Assert-Equal $targets[$index] $plan.primaryMatrix["Target$index"].InsertionTarget 'Keep original branch names unchanged.'
}

Write-Host 'VS insertion plan tests passed.'
