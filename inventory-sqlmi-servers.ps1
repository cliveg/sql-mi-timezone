$impact = @{ 'Mountain Standard Time' = 'Yes (Alberta)'; 'Pacific Standard Time' = 'Check (BC)'; 'Central Standard Time' = 'Check (Manitoba)' }
$rank = { ('Yes', 'Check', 'No').IndexOf($_.Impact.Split()[0]) }
$rows = foreach ($sub in (az account list --query "[?state=='Enabled'].id" -o tsv)) {
$mis = az sql mi list --subscription $sub --query "[].[name,timezoneId,databaseFormat,state,zoneRedundant]" -o tsv 2>$null
if ($LASTEXITCODE) { Write-Warning "Skipped subscription $sub (no access or error)"; continue }
foreach ($line in $mis) {
$name, $tz, $policy, $state, $zr = $line -split "`t"
$i = if ($impact[$tz]) { $impact[$tz] } else { 'No' }
[pscustomobject]@{ Impact = $i; Instance = $name; State = $state; ZR = if ($zr -eq 'true') { 'Yes' } else { '-' }; Policy = $policy
TimeZone = $tz -replace ' Standard Time'; Fix = if ($i -eq 'No') { '-' } elseif ($policy -eq 'AlwaysUpToDate') { 'D' } else { 'A+D or R' } }
}
}
$rows | Sort-Object $rank, Instance | Format-Table Impact, Instance, State, ZR, Fix, Policy, TimeZone -AutoSize
$rows | Group-Object Impact | Select-Object @{n = 'Impact'; e = { $_.Name } }, @{n = 'Instances'; e = { $_.Count } },
@{n = 'Running'; e = { @($_.Group | Where-Object State -eq 'Ready').Count } }, @{n = 'ZR'; e = { @($_.Group | Where-Object ZR -eq 'Yes').Count } },
@{n = 'Fix D'; e = { @($_.Group | Where-Object Fix -eq 'D').Count } },
@{n = 'Fix A+D or R'; e = { @($_.Group | Where-Object Fix -like 'A').Count } } | Sort-Object $rank | Format-Table -AutoSize
'D = Database-level time zone (ALTER DATABASE SCOPED CONFIGURATION SET TIME_ZONE) + shift SQL Agent jobs 1 hour'
'A = switch update policy to AlwaysUpToDate (one-way), then D R = Recreate the MI with the new time zone'
'ZR = zone-redundant (instance-level setting: recreate (R) must also set zone redundancy)'
