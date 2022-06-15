# Microsoft Purview Demo Environment
This repository includes instructions on how to automate the deployment of a pre-populated Microsoft Purview demo environment.

## Prerequisites

* An active [Azure subscription](https://azure.microsoft.com/en-us/free/).
* No **Azure Policies** preventing creation of **Storage accounts** or **Event Hub** namespaces. Purview will deploy a managed Storage account and Event Hub when it is created. If a blocking policy exists and needs to remain in place, please follow the [Purview exception tag guide](https://docs.microsoft.com/en-us/azure/purview/create-purview-portal-faq#create-a-policy-exception-for-purview) to create an exception for Purview accounts.

## Usage

1. Click **Deploy to Azure**.  
    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftayganr%2Fpurviewdemo%2Fmain%2Ftemplates%2Ftemplate.json)
1. Select a **Region**.
    > Note: If you are planning to create a NEW Resource Group for the set of resources that will be created as part of this template, ensure to select a Region BEFORE creating a new Resource Group (otherwise the Resource Group will be created with the default location).
1. Select the target **Azure Subscription**.
1. Select an existing OR create a new **Resource Group**.
    > Note: If you are selecting an existing Resource Group, this will be automatically set to the existing Resource Group's location.
1. [OPTIONAL] Change the SQL Server Admin Login.
1. [OPTIONAL] Change the SQL Server Admin Password.
    > Note: You do not need to know the password, the post deployment script will automatically store the secret in Key Vault and Purview will use this secret to successfully scan the Azure SQL Database.

## Outcome

* The template should take approximately 10 minutes to complete.
* Once complete, all Azure resources will have been provisioned, RBAC assignments applied, and data plane operations executed, see below for more details.

Note: An additional 10 minutes post-deployment may be required for:

* Azure Data Factory pipeline to finish running and push lineage to Microsoft Purview.
* Microsoft Purview to finish scanning registered sources and populate the catalog.
* The status of these jobs can be monitored within the respective service.

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Validate Deployment

1. Navigate to the Azure Portal, locate your **Resource Group**, click **Deployments**. You should see that the deployment has **Succeeded**.
![Validate Deployment](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/01validate_deployment.png)

2. Within your resource group, you should see the following set of Azure resources.
![Azure Resources](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/02validate_resources.png)

3. Navigate to your Microsoft Purview Account (e.g. `pvdemo{RAND_STRING}-pv`), click **Open Governance Portal** > **Data Map**. You should see 3 collections and 2 sources.
![Microsoft Purview Data Map](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/03validate_datamap.png)

4. Within the **Azure Data Lake Storage Gen2** source, click **View Details**, you should see a scan. Note: The scan may still be in progress and can take up to 10 minutes to complete.
![Microsoft Purview Azure Data Lake Storage Gen2 Scan](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/05validate_scanadls.png)

5. Within the **Azure Data Lake Storage Gen2** source, click the **New Scan** icon, click **Test connection**. The connection should be successful.
![Microsoft Purview Azure Data Lake Storage Gen2 Test Connectivity](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/07validate_credadls.png)

6. Within the **Azure SQL Database** source, click **View Details**, you should see a scan. Note: The scan may still be in progress and can take up to 10 minutes to complete.
![Microsoft Purview Azure SQL Database Scan](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/04validate_scansql.png)

7. Within the **Azure SQL Database** source, click the **New Scan** icon, select a **Database name**, set **Credential** to **sql-cred** , toggle **Lineage extraction** to **Off**, and click **Test connection**. The connection should be successful.
![Microsoft Purview Azure SQL Database Test Connectivity](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/06validate_credsql.png)

8. Navigate to **Data Map** > **Collections** > **Role assignments**. You should see your user added to each role (Collection admin, Data Source admin, Data curator, Data reader), you should also see the Azure Data Factory Managed Identity added as a Data Curator.
![Microsoft Purview Role Assignments](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/08validate_roleassignments.png)

9. Navigate to **Management** > **Data Factory**. You should see a Connected Azure Data Factory account.
![Azure Data Factory Integration](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/09validate_adf.png)

10. Navigate to **Data Catalog** > **Manage Glossary** and click **Hierarchical** view. You should see a pre-populated Glossary.
![Microsoft Purview Glossary](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/10validate_glossary.png)

11. Navigate to **Management** > **Credentials**. You should see credential from Azure Key Vault.
![Microsoft Purview Credential](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/11validate_keyvault.png)

12. Within the search bar, search for "copy" and navigate to the `Copy_a9c` asset within Purview and then click **Lineage**. You should see lineage from the Azure Data Factory Copy Activity. Note: The pipeline within Azure Data Factory may still be running and can take up to 10 minutes to complete. To check the status of the pipeline, navigate to Azure Data Factory and check Monitoring.
![Microsoft Purview Lineage](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/12validate_lineage.png)

<!-- 13. Navigate to the Synapse Workspace and click Open Synapse Studio > Data, search for "merged", open the `merged.parquet` asset. Within the asset details page, select Develop > New SQL script > Select top 100.
![Azure Synapse Analytics Browse Purview](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/13validate_synapsebrowse.png)

14. Click Run to query the parquet file.
![Azure Synapse Analytics Query Purview Asset](https://raw.githubusercontent.com/tayganr/purviewdemo/main/images/14validate_synapsequery.png) -->

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Deployed Resources

* Microsoft Purview Account
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
| 3 | Azure Storage Account | Microsoft Purview MI | Storage Blob Data Reader |
| 4 | Azure Storage Account | Azure Data Factory MI | Storage Blob Data Contributor |

<div align="right"><a href="#azure-purview-demo-environment">↥ back to top</a></div>

## Data Plane Operations

| # | Service | Action |
| ------------- | ------------- | ------------- |
| 1  | Identity Provider | Get Access Token |
| 2  | Microsoft Purview | Create Azure Key Vault Connection |
| 3  | Microsoft Purview | Create Credential |
| 4  | Microsoft Purview | Update Root Collection Policy |
| 5  | Microsoft Purview | Create Collections |
| 6  | Microsoft Purview | Azure SQL DB: Register Source |
| 7  | Microsoft Purview | Azure SQL DB: Create Scan |
| 8  | Microsoft Purview | Azure SQL DB: Run Scan |
| 9  | Azure Data Lake Storage Gen2 | Load Sample Data |
| 10  | Microsoft Purview | ADLS Gen2: Register Source |
| 11 | Microsoft Purview | ADLS Gen2: Create Scan |
| 12 | Microsoft Purview | ADLS Gen2: Run Scan |
| 13 | Azure Data Factory | Run Pipeline |
| 14 | Microsoft Purview | Populate Glossary |
