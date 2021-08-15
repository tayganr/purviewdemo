# Azure Purview Demo Environment
This repository includes template files that can be used to automate the deployment of an Azure Purview demo environment.

## Option 1 - Click Deploy to Azure

### Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* A resource group to which you have [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) permissions. 
* A [registered application](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#register-an-application-with-azure-ad-and-create-a-service-principal) and an [application secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-2-create-a-new-application-secret).

### Parameters

Below is the parameters required by the template. It is recommended that you have these values ready prior to clicking the "Deploy to Azure" button.

* **Azure AD Object ID**: This is the ID to YOUR account within Azure Active Directory. This can be located by navigating to your profile within Azure AD. Alternatively, you can run the below PowerShell command to retrieve this value.

    ```powershell
    (Get-AzAdUser -Mail "YOUR_EMAIL_ADDRESS").id
    ```

* **Service Principal Object ID**: This is the ID to a Service Principal (registered application). This can be located by navigating to your application via Azure AD > App Registrations > YOUR_APP_NAME and copying the Object ID. Alternatively, you can run the below PowerShell command to retrieve this value.

    ```powershell
    (Get-AzADServicePrincipal -DisplayName "SERVICE_PRINCIPAL_NAME").Id
    ```

* **Service Principal Client ID**: This is the Client ID (aka Application ID) to a Service Principal (registered application). This can be located by navigating to your application via Azure AD > App Registrations > YOUR_APP_NAME and copying the Application (client) ID. Alternatively, you can run the below PowerShell command to retrieve this value.

    ```powershell
    (Get-AzADServicePrincipal -DisplayName "SERVICE_PRINCIPAL_NAME").ApplicationId
    ```

* **Service Principal Client Secret**: This is the Client Secret to a Service Principal (registered application). For more information on how to generate a Client Secret, check out ths tutorial on [Microsoft Docs](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-2-create-a-new-application-secret).


### Usage

Once you have your parameter values ready, click the button below to deploy to Azure.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftayganr%2Fpurviewdemo%2Fmain%2Fbicep%2Fazuredeploy.json)

## Option 2 - Cloud Shell

```powershell
# Azure AD Object ID
$emailAddress = Read-Host -Prompt "`r`nPlease enter your Azure AD email address"
$principalId = (Get-AzAdUser -Mail $emailAddress).id

# Suffix
$suffix = -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})

# Location
$locationList='australiaeast', 'brazilsouth', 'canadacentral', 'centralindia', 'eastus', 'eastus2', 'southcentralus', 'southeastasia', 'uksouth', 'westeurope'
$location = Get-Random -InputObject $locationList

# Resource Group
$rg = New-AzResourceGroup -Name "pvdemo-rg-${suffix}" -Location $location

# Service Principal
$sp = New-AzADServicePrincipal -DisplayName "pvDemoServicePrincipal-${suffix}"

# Client Secret
$Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode($sp.Secret)
$password = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($Ptr)
$securePassword = ConvertTo-SecureString $password –asplaintext –force

# Deploy Template
$templateUri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/azuredeploy.json"
New-AzResourceGroupDeployment `
  -Name "pvDemoTemplate-${suffix}" `
  -ResourceGroupName $rg.ResourceGroupName `
  -TemplateUri $templateUri `
  -objectID $principalId `
  -servicePrincipalObjectID $sp.Id `
  -servicePrincipalClientID $sp.ApplicationId `
  -servicePrincipalClientSecret $securePassword
  ```

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