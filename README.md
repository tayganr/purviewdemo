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

### Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* Sufficient access to create resources and register an application.

### Usage

The pre-deployment script below negates the pre-work required in option 1 by automatically creating a resource group, service principal, and application secret. These values are then subsequentally fed into the ARM template as parameter values. 

1. Navigate to the [Azure Portal](https://portal.azure.com) and open the [cloud shell](https://docs.microsoft.com/en-us/azure/cloud-shell/overview).
2. Copy and paste the PowerShell code snippet below into the cloud shell.
3. When prompted, provide your Azure AD email address.

The template should take approximately 10 minutes to complete.

```powershell
# Azure AD Object ID
$principalId = $null
Do {
    $emailAddress = Read-Host -Prompt "Please enter your Azure AD email address"
    $principalId = (Get-AzAdUser -Mail $emailAddress).id
    if ($principalId -eq $null) { $principalId = (Get-AzAdUser -UserPrincipalName $emailAddress).Id } 
    if ($principalId -eq $null) { Write-Host "Unable to find a user within the Azure AD with email address: ${emailAddress}. Please try again." }
} until($principalId -ne $null)

# Suffix
$suffix = -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})

# Location
$locationList='australiaeast', 'brazilsouth', 'canadacentral', 'centralindia', 'eastus', 'eastus2', 'southcentralus', 'southeastasia', 'uksouth', 'westeurope'
$location = Get-Random -InputObject $locationList

# Resource Group
$rg = New-AzResourceGroup -Name "pvdemo-rg-${suffix}" -Location $location

# Service Principal
$subscriptionId = (Get-AzContext).Subscription.Id
$rgName = $rg.ResourceGroupName
$scope = "/subscriptions/${subscriptionId}/resourceGroups/${rgName}"
$sp = New-AzADServicePrincipal -DisplayName "pvDemoServicePrincipal-${suffix}" -Scope $scope

# Deploy Template
$templateUri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/azuredeploy.json"
$job = New-AzResourceGroupDeployment `
  -Name "pvDemoTemplate-${suffix}" `
  -ResourceGroupName $rgName `
  -TemplateUri $templateUri `
  -objectID $principalId `
  -servicePrincipalObjectID $sp.Id `
  -servicePrincipalClientID $sp.ApplicationId `
  -servicePrincipalClientSecret $sp.Secret `
  -AsJob

$progress = ('.', '..', '...')
While ($job.State -eq "Running") {
    Foreach ($x in $progress) {
        cls
        Write-Host "Deployment is in progress, this will take approximately 10 minutes"
        Write-Host "Running${x}"
        Start-Sleep 1
    }
}

# Clean-Up Service Principal
Remove-AzRoleAssignment -ResourceGroupName $rgName -ObjectId $sp.Id -RoleDefinitionName "Contributor"
Remove-AzADServicePrincipal -ObjectId $sp.Id -Force

# Clean-Up User Assigned Managed Identity
$configAssignment = Get-AzRoleAssignment -ResourceGroupName $rgName | Where-Object {$_.DisplayName.Equals("configDeployer")}
Remove-AzRoleAssignment -ResourceGroupName $rgName -ObjectId $configAssignment.ObjectId -RoleDefinitionName "Contributor"

# Deployment Complete
Write-Host "Deployment complete! https://web.purview.azure.com/resource/pvdemo${suffix}-pv"
Write-Host "Note: The Azure Data Factory pipeline and Azure Purview scans may still be running and will complete shortly.

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
| 1 | Azure Purview Account | Service Principal | Purview Data Curator |
| 2 | Azure Purview Account | Service Principal | Purview Data Source Administrator |
| 3 | Azure Purview Account | Azure Data Factory MI | Purview Data Curator |
| 4 | Azure Purview Account | Current User | User Access Administrator |
| 5 | Azure Storage Account | Current User | Storage Blob Data Reader |
| 6 | Azure Storage Account | Azure Synapse MI | Storage Blob Data Contributor |
| 7 | Azure Storage Account | Azure Purview MI | Storage Blob Data Reader |
| 8 | Azure Storage Account | Azure Data Factory MI | Storage Blob Data Contributor |

## Data Plane Operations

| # | Service | Action |
| ------------- | ------------- | ------------- |
| 1  | Identity Provider | Get Access Token |
| 2  | Azure Purview | Create Azure Key Vault Connection |
| 3  | Azure Purview | Create Credential |
| 4  | Azure Purview | Create Collection |
| 5  | Azure Purview | Azure SQL DB: Register Source |
| 6  | Azure Purview | Azure SQL DB: Create Scan |
| 7  | Azure Purview | Azure SQL DB: Run Scan |
| 8  | Azure Data Lake Storage Gen2 | Load Sample Data |
| 9  | Azure Purview | ADLS Gen2: Register Source |
| 10 | Azure Purview | ADLS Gen2: Create Scan |
| 11 | Azure Purview | ADLS Gen2: Run Scan |
| 12 | Azure Data Factory | Run Pipeline |
| 13 | Azure Purview | Populate Glossary |