# Azure Purview Demo Environment
This repository includes template files that can be used to automate the deployment of an Azure Purview demo environment.

## Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* A resource group to which you have [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) permissions. 
* [Register an application with Azure AD](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#register-an-application-with-azure-ad-and-create-a-service-principal) and [create a new application secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-2-create-a-new-application-secret).

## Usage
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftayganr%2Fpurviewdemo%2Fmain%2Fbicep%2Fazuredeploy.json)

## Resources

* Azure Purview Account
* Azure Key Vault
* Azure SQL Database
* Azure Data Lake Storage Gen2 Account
* Azure Data Factory
* Azure Synapse Analytics Workspace

## Role Assignments

| # | Scope | Principal | Role Definition |
| ------------- | ------------- | ------------- | ------------- |
| 1 | Azure Purview Account | Azure Data Factory MI | Purview Data Curator |
| 2 | Azure Purview Account | Service Principal | Purview Data Curator |
| 3 | Azure Purview Account | Service Principal | Purview Data Source Administrator |
| 4 | Azure Purview Account | Current User | User Access Administrator |
| 5 | Azure Storage Account | Azure Purview MI | Storage Blob Data Reader |
| 6 | Azure Storage Account | Azure Data Factory MI | Storage Blob Data Contributor |
| 7 | Resource Group | User Assigned Identity | Contributor |
| 8 | Azure Storage Account | Azure Synapse MI | Storage Blob Data Contributor |
| 9 | Azure Storage Account | Current User | Storage Blob Data Reader |

## Data Plane Operations

1. Get Access Token
2. Azure Purview: Create Azure Key Vault Connection
3. Azure Purview: Create Credential
4. Azure Purview: Create Collection
5. Azure SQL Database: Register Source
6. Azure SQL Database: Create Scan
7. Azure SQL Database: Run Scan
8. Azure Data Lake Storage Gen2: Load Sample Data
9. Azure Data Lake Storage Gen2: Register Source
10. Azure Data Lake Storage Gen2: Create Scan
11. Azure Data Lake Storage Gen2: Run Scan
12. Azure Data Factory: Run Pipeline
13. Azure Purview: Populate Glossary