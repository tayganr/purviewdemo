# purviewdemo


## Get Started

`az deployment group create -g demo -f azuredeploy.bicep -p parameters.json `

## Resources

| Namespace | Type | Notes |
| ------------- | ------------- | ------------- |
| Microsoft.Purview | accounts | |
| Microsoft.Sql | servers | |
| Microsoft.Sql | servers/databases | |
| Microsoft.Sql | servers/firewallRules | Allow Azure Services|
| Microsoft.Sql | servers/firewallRules | Allow All |
| Microsoft.KeyVault | vaults | |
| Microsoft.KeyVault | vaults/accessPolicies | Current User |
| Microsoft.KeyVault | vaults/accessPolicies | Azure Purview MI |
| Microsoft.KeyVault | vaults/secret | Azure SQL DB Admin Password|
| Microsoft.Storage | storageAccounts | |
| Microsoft.Authorization | roleAssignments | Purview Data Curator > Service Principal |
| Microsoft.Authorization | roleAssignments | Purview Data Source Administrator > Service Principal|
| Microsoft.Authorization | roleAssignments | Storage Blob Data Reader > Azure Purview MI |