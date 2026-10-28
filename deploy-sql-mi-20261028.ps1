# Replace all <...> placeholders before running this script.
Select-AzSubscription -Subscription "<subscription-id>"

# --- Variables ---
$vnetName   = "<virtual-network-name>"
$subnetName = "<subnet-name>"
$location   = "<azure-region>"
$miRg       = "<sql-managed-instance-resource-group>"                    # resource group for the SQL MI
$mi         = "<sql-managed-instance-name>"                              # must be globally unique, lowercase
$vnetRg     = (Get-AzResource -ResourceType "Microsoft.Network/virtualNetworks" -Name $vnetName).ResourceGroupName
$admin      = Get-AzADUser -SignedIn                                      # current signed-in user as Entra admin

# --- Validate and show what will be used ---
if (@($vnetRg).Count -ne 1) { throw "Found $(@($vnetRg).Count) VNets named '$vnetName'. Set `$vnetRg manually." }
if (-not $admin)            { throw "Signed-in user not found. Check your Az sign-in." }
if (-not (Get-AzResourceGroup -Name $miRg -ErrorAction SilentlyContinue)) {
  New-AzResourceGroup -Name $miRg -Location $location | Out-Null }

[pscustomobject]@{ MI=$mi; MI_RG=$miRg; VNet_RG=$vnetRg; Location=$location; VNet=$vnetName; Subnet=$subnetName; Admin=$admin.UserPrincipalName } | Format-List

# --- Get the subnet ---
$vnet = Get-AzVirtualNetwork -Name $vnetName -ResourceGroupName $vnetRg
$sn   = $vnet.Subnets | Where-Object Name -eq $subnetName
if (-not $sn) { throw "Subnet '$subnetName' not found in '$vnetName'. Available: $($vnet.Subnets.Name -join ', ')" }

# --- Verify the subnet (delegated to Microsoft.Sql, NSG and route table associated) ---
[pscustomobject]@{
  Delegated  = $sn.Delegations.ServiceName -contains "Microsoft.Sql/managedInstances"
  NSG        = [bool]$sn.NetworkSecurityGroup
  RouteTable = [bool]$sn.RouteTable
} | Format-List

# --- Fix anything missing (network resources live with the VNet) ---
if (-not $sn.NetworkSecurityGroup) {
  $sn.NetworkSecurityGroup = New-AzNetworkSecurityGroup -Name "$subnetName-nsg" -ResourceGroupName $vnetRg -Location $vnet.Location }
if (-not $sn.RouteTable) {
  $sn.RouteTable = New-AzRouteTable -Name "$subnetName-rt" -ResourceGroupName $vnetRg -Location $vnet.Location }
if (-not ($sn.Delegations.ServiceName -contains "Microsoft.Sql/managedInstances")) {
  Add-AzDelegation -Name "miDelegation" -ServiceName "Microsoft.Sql/managedInstances" -Subnet $sn | Out-Null }

$vnet = $vnet | Set-AzVirtualNetwork
$subnetId = ($vnet.Subnets | Where-Object Name -eq $subnetName).Id

# --- Create the test instance (small, not zone-redundant) ---
New-AzSqlInstance -Name $mi -ResourceGroupName $miRg -Location $location -SubnetId $subnetId `
  -VCore 4 -StorageSizeInGB 32 -Edition "GeneralPurpose" -ComputeGeneration "Gen5" `
  -LicenseType "LicenseIncluded" -BackupStorageRedundancy "Local" `
  -TimezoneId "<windows-time-zone-id>" `
  -ExternalAdminName $admin.UserPrincipalName -ExternalAdminSID $admin.Id `
  -EnableActiveDirectoryOnlyAuthentication -AsJob
