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

1. Navigate to the Azure Portal, locate your Resource Group (e.g. `pvdemo-rg-{suffix}`), click Deployments. You should see two deployments that have **Succeded**.
![Validate Deployment](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/01validate_deployment.png)

2. Within your resource group, you should see the following set of Azure resources.
![Azure Resources](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/02validate_resources.png)

3. Navigate to your Azure Purview Account (e.g. `pvdemo{suffix}-pv`), click Open Purview Studio > Data Map. You should see 3 collections and 2 sources.
![Azure Purview Data Map](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/03validate_datamap.png)

4. Within the Azure SQL Database source, click **View Details**, you should see a scan. Note: The scan may still be in progress and can take up to 10 minutes to complete.
![Azure Purview Azure SQL Database Scan](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/04validate_scansql.png)

5. Within the Azure Data Lake Storage Gen2 source, click **View Details**, you should see a scan. Note: The scan may still be in progress and can take up to 10 minutes to complete.
![Azure Purview Azure Data Lake Storage Gen2 Scan](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/05validate_scanadls.png)

6. Within the Azure SQL Database source, click the **New Scan** icon, select a **Database name**, select the sql-cred **Credential**, click **Test connection**. The connection test should be successful.
![Azure Purview Azure SQL Database Test Connectivity](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/06validate_credsql.png)

7. Within the Azure Data Lake Storage Gen2 source, click the **New Scan** icon, click **Test connection**. The connection test should be successful.
![Azure Purview Azure Data Lake Storage Gen2 Test Connectivity](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/07validate_credadls.png)

8. Navigate to Data Map > Collections > Role assignments. You should see your user added to each role (Collection admin, Data Source admin, Data curator, Data reader), you should also see the Azure Data Factory Managed Idenity added as a Data Curator.
![Azure Purview Role Assignments](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/08validate_roleassignments.png)

9. Navigate to Management > Data Factory. You should see a Connected Azure Data Factory account.
![Azure Data Factory Integration](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/09validate_adf.png)

10. Navigate to Data Catalog > Manage Glossary and click Hierarchical view. You should see a pre-populated Glossary.
![Azure Purview Glossary](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/10validate_glossary.png)

11. Navigate to Management > Credentials. You should see credential from Azure Key Vault.
![Azure Purview Credential](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/11validate_keyvault.png)

12. Search for "copy" and navigate to the `Copy_a9c` asset within Purview, click Lineage. You should see lineage from the Azure Data Factory Copy Activity. Note: The pipeline within Azure Data Factory may still be running, this can take up to 10 minutes to complete.
![Azure Purview Lineage](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/12validate_lineage.png)

13. Navigate to the Synapse Workspace > Open Synapse Studio > Data, search for "merged", open `merged.parquet`, select Develop > New SQL script > Select top 100.
![Azure Synapse Analytics Browse Purview](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/13validate_synapsebrowse.png)

14. Click Run to query the parquet file.
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