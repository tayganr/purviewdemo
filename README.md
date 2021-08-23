# Azure Purview Demo Environment
This repository includes instructions on how to automate the deployment of a pre-populated Azure Purview demo environment.

## Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* Sufficient access to create resources and register an application.

## Usage

The pre-deployment script below negates any pre-work required by automatically creating a resource group, service principal, and application secret. These values are then subsequentally fed into the ARM template as parameter values. 

1. **Copy** the PowerShell code snippet below.
```powershell
$uri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/scripts/preDeploymentScript.ps1"
Invoke-WebRequest $uri -OutFile "preDeploymentScript.ps1"
./preDeploymentScript.ps1
  ```
2. Navigate to the [Azure Portal](https://portal.azure.com), open the **Cloud Shell**.
![Azure Portal Cloud Shell](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/azure_portal_cloud_shell.png)

3. **Paste** the code snippet and provide your Azure AD **email address** when prompted.
![PowerShell Azure AD Email Address Prompt](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/powershell_email_prompt.png)

## Outcome
* The template should take approximately 10 minutes to complete.
* Once complete, all Azure resources will have been provisioned, RBAC assignments applied, and data plane operations executed, see below for more details.

Note: An additional 10 minutes post-deployment may be required for:
* Azure Data Factory pipeline to finish running and push lineage to Azure Purview.
* Azure Purview to finish scanning registered sources and populate the catalog.
* The status of these jobs can be monitored within the respective service.

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Validate Deployment

![Validate Deployment](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/01validate_deployment.png)
![Azure Resources](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/02validate_resources.png)
![Azure Purview Data Map](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/03validate_datamap.png)
![Azure Purview Azure SQL Database Scan](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/04validate_scansql.png)
![Azure Purview Azure Data Lake Storage Gen2 Scan](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/05validate_scanadls.png)
![Azure Purview Azure SQL Database Test Connectivity](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/06validate_credsql.png)
![Azure Purview Azure Data Lake Storage Gen2 Test Connectivity](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/07validate_credadls.png)
![Azure Purview Role Assignments](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/08validate_roleassignments.png)
![Azure Data Factory Integration](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/09validate_adf.png)
![Azure Purview Glossary](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/10validate_glossary.png)
![Azure Purview Credential](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/11validate_keyvault.png)
![Azure Purview Lineage](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/12validate_lineage.png)
![Azure Synapse Analytics Browse Purview](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/13validate_synapsebrowse.png)
![Azure Synapse Analytics Query Purview Asset](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/14validate_synapsequery.png)


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
| 1 | Azure Storage Account | Current User | Storage Blob Data Reader |
| 2 | Azure Storage Account | Azure Synapse MI | Storage Blob Data Contributor |
| 3 | Azure Storage Account | Azure Purview MI | Storage Blob Data Reader |
| 4 | Azure Storage Account | Azure Data Factory MI | Storage Blob Data Contributor |

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Data Plane Operations

| # | Service | Action |
| ------------- | ------------- | ------------- |
| 1  | Identity Provider | Get Access Token |
| 2  | Azure Purview | Create Azure Key Vault Connection |
| 3  | Azure Purview | Create Credential |
| 4  | Azure Purview | Update Root Collection Policy |
| 5  | Azure Purview | Create Collections |
| 6  | Azure Purview | Azure SQL DB: Register Source |
| 7  | Azure Purview | Azure SQL DB: Create Scan |
| 8  | Azure Purview | Azure SQL DB: Run Scan |
| 9  | Azure Data Lake Storage Gen2 | Load Sample Data |
| 10  | Azure Purview | ADLS Gen2: Register Source |
| 11 | Azure Purview | ADLS Gen2: Create Scan |
| 12 | Azure Purview | ADLS Gen2: Run Scan |
| 13 | Azure Data Factory | Run Pipeline |
| 14 | Azure Purview | Populate Glossary |