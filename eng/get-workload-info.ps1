param ([Parameter(Mandatory=$true)] [string] $workloadDropPath)

# Extracts the workload drop information.
# full: The full drop name, excluding the 'Workload.VSDrop.' prefix.
# short: The short name of the drop. Only contains the first word after 'Workload.VSDrop.'.
# type: Either 'pre.components', 'components', or 'packs'.
$regex = '^Workload\.VSDrop\.(?<full>(?<short>\w*)\..*?(?<type>(pre\.)?components$|packs$))'
Get-ChildItem -Path $workloadDropPath -Directory | ForEach-Object {
  $null = $_.Name -match $regex
  $Matches.full + ';' + $Matches.short + ';' + $Matches.type.Replace('.', '')
}