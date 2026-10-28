# SQL Managed Instance time zone scripts

PowerShell examples for inventorying Azure SQL Managed Instances and preparing a test deployment.

## Background

Read [Canada's 2026 time zone updates: guidance for Microsoft SQL - Azure SQL Dev Corner](https://devblogs.microsoft.com/azure-sql/canadas-2026-time-zone-updates-guidance-for-microsoft-sql/) before planning changes.

## Scripts

| Script | Purpose |
| --- | --- |
| [inventory-sqlmi-servers.ps1](./inventory-sqlmi-servers.ps1) | Lists instances across enabled subscriptions accessible to the signed-in Azure CLI account, including time zone, update policy, state, and zone redundancy (ZR), with impact classifications and summary counts. |
| [deploy-sql-mi-20261028.ps1](./deploy-sql-mi-20261028.ps1) | Sanitized test-deployment example using descriptive placeholders instead of environment-specific values. |

## Requirements

- PowerShell.
- For inventory: Azure CLI, signed in with `az login`, and permission to list instances in the relevant subscriptions.
- For deployment: Azure PowerShell modules `Az.Accounts`, `Az.Resources`, `Az.Network`, and `Az.Sql`; sign in with `Connect-AzAccount`.

## Inventory

```powershell
.\inventory-sqlmi-servers.ps1
```

The script reports ZR as `Yes` when the returned instance setting is true. Its impact classifications and suggested fix labels are screening hints, not a complete assessment. Validate them against the linked article and current Microsoft documentation. A `No` classification is not a guarantee that a workload is unaffected. Warnings indicate subscriptions that could not be inventoried; results can therefore be incomplete.

The script only lists resources and prints results; it does not apply its suggested fixes. Review any inventory output for identifying information before sharing it.

## Test deployment

Replace every `<...>` placeholder in the deployment script:

- `<subscription-id>`
- `<virtual-network-name>`
- `<subnet-name>`
- `<azure-region>`
- `<sql-managed-instance-resource-group>`
- `<sql-managed-instance-name>`
- `<windows-time-zone-id>`

Review the entire script and its resource settings before running:

```powershell
.\deploy-sql-mi-20261028.ps1
```

**This script changes Azure resources and can incur charges.** It uses the signed-in user as the Microsoft Entra administrator and starts creation as a background job. Check that job's outcome; starting a job does not confirm deployment success.

The deployment example is not a remediation script and does not preserve or migrate an existing instance. The original environment-specific deployment script is intentionally excluded.
