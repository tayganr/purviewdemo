# Azure Purview Demo Environment
This repository includes a template (i.e. Bicep + PowerShell) that can be used to automate the deployment of an Azure Purview demo environment.

## Prerequisites

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/get-started-with-azure-cli)
* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* A resource group to which you have [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) permissions. 
* [Register an application with Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#register-an-application-with-azure-ad-and-create-a-service-principal) and [create a new application secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-2-create-a-new-application-secret).

## Usage

1. Download the following files to your local machine:
    * [azuredeploy.bicep](https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/azuredeploy.bicep)
    * [azuredeploy.parameters.json](https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/azuredeploy.parameters.json)
    * [purview.ps1](https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/purview.ps1)
2. Update **azuredeploy.parameters.json** file with your values.
3. Execute the following command:  

`az deployment group create -g YOUR_RESOURCE_GROUP -f azuredeploy.bicep -p parameters.json `

## Resources

* Azure Purview Account
* Azure Key Vault
* Azure SQL Database
* Azure Data Lake Storage Gen2 Account
* Azure Data Factory

## Control Plane (azuredeploy.bicep)

| Namespace | Type |
| ------------- | ------------- |
| Microsoft.Purview | accounts |
| Microsoft.Sql | servers |
| Microsoft.Sql | servers/databases |
| Microsoft.Sql | servers/firewallRules (allow Azure services) |
| Microsoft.Sql | servers/firewallRules (allow all) |
| Microsoft.KeyVault | vaults |
| Microsoft.KeyVault | vaults/accessPolicies (Current User) |
| Microsoft.KeyVault | vaults/accessPolicies (Azure Purview MI)|
| Microsoft.KeyVault | vaults/secret (sql-secret) |
| Microsoft.Storage | storageAccounts |
| Microsoft.Storage | storageAccounts/blobServices |
| Microsoft.Storage | storageAccounts/blobServices/containers |
| Microsoft.ManagedIdentity | userAssignedIdentities |
| Microsoft.Resources | deploymentScripts |
| Microsoft.Authorization | roleAssignments |

## Role Assignments

| # | Scope | Principal | Role Definition |
| ------------- | ------------- | ------------- | ------------- |
| 1 | Azure Purview Account | Azure Data Factory MI | Purview Data Curator |
| 2 | Azure Purview Account | Service Principal | Purview Data Curator |
| 3 | Azure Purview Account | Service Principal | Purview Data Source Administrator |
| 4 | Azure Purview Account | Current User | User Access Administrator |
| 5 | Azure Storage Account | Azure Purview MI | Storage Blob Data Reader |
| 6 | Resource Group | User Assigned Identity | Contributor |

## Post Deployment Script (purview.ps1)

1. Get Access Token
2. Azure Purview: Create Azure Key Vault Connection
3. Azure Purview: Create Credential
4. Azure SQL Database: Register Source
5. Azure SQL Database: Create Scan
6. Azure SQL Database: Run Scan
7. Azure Data Lake Storage Gen2: Load Sample Data
8. Azure Data Lake Storage Gen2: Register Source
9. Azure Data Lake Storage Gen2: Create Scan
10. Azure Data Lake Storage Gen2: Run Scan