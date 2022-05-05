# Microsoft Purview Demo Environment Generator

1. Click **Deploy to Azure**.  
    [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Ftayganr%2Fpurviewdemo%2Fmain%2Ftemp%2Ftemplate.json)
1. Select the target **Azure Subscription**.
1. Select an existing OR create a new **Resource Group**.
1. Select a **Region**.
    > Note: If you are selecting an existing Resource Group, this will be automatically set to the Resource Group's existing location.
1. [OPTIONAL] Change the SQL Server Admin Login.
1. [OPTIONAL] Change the SQL Server Admin Password.
    > Note: You do not need to know the password, the post deployment script will automatically store the secret in Key Vault and Purview will use this secret to successfully scan the Azure SQL Database.

