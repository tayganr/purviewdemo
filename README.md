# Azure Purview Demo Environment
This repository includes template files that can be used to automate the deployment of an Azure Purview demo environment.

## Deployment Options
* [Option 1 - Partial Automation](#option-1---partial-automation). Requires an existing Service Principal.
* [Option 2 - Complete Automation](#option-2---complete-automation). Service Principal created automtically as part of the deployment.

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Option 1 - Partial Automation

### Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* A resource group to which you have [Owner](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) permissions. 
* A [registered application](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#register-an-application-with-azure-ad-and-create-a-service-principal) and an [application secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#option-2-create-a-new-application-secret).

### Usage

Once you have your parameter values ready, click the button below to deploy the template to Azure. For more information on how to retrieve the required parameter values, see the section below.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftayganr%2Fpurviewdemo%2Fmain%2Fbicep%2Fazuredeploy.json)

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

![Azure Portal Custom Deployment UI](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/deploy_to_azure.png)

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Option 2 - Complete Automation

### Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* Sufficient access to create resources and register an application.

### Usage

The pre-deployment script below negates the pre-work required in option 1 by automatically creating a resource group, service principal, and application secret. These values are then subsequentally fed into the ARM template as parameter values. 

1. **Copy** the PowerShell code snippet below.
```powershell
$uri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/preDeploymentScript.ps1"
Invoke-WebRequest $uri -OutFile "preDeploymentScript.ps1"
./preDeploymentScript.ps1
  ```
2. Navigate to the [Azure Portal](https://portal.azure.com), open the **Cloud Shell**.
![Azure Portal Cloud Shell](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/azure_portal_cloud_shell.png)

3. **Paste** the code snippet and provide your Azure AD **email address** when prompted.
![PowerShell Azure AD Email Address Prompt](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/powershell_email_prompt.png)

### Outcome
* The template should take approximately 10 minutes to complete.
* Once complete, all Azure resources will have been provisioned, RBAC assignments applied, and data plane operations executed, see below for more details.

Note: An additional 10 minutes post-deployment may be required for:
* Azure Data Factory pipeline to finish running and push lineage to Azure Purview.
* Azure Purview to finish scanning registered sources and populate the catalog.
* The status of these jobs can be monitored within the respective service.

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Deployed Resources

* Azure Purview Account
* Azure Key Vault
* Azure SQL Database
* Azure Data Lake Storage Gen2 Account
* Azure Data Factory
* Azure Synapse Analytics Workspace

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

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

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

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