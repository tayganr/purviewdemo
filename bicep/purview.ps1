param(
    [string]$tenant_id,
    [string]$client_id,
    [string]$client_secret,
    [string]$purview_account,
    [string]$vault_uri,
    [string]$admin_login,
    [string]$sql_secret_name,
    [string]$subscription_id,
    [string]$resource_group,
    [string]$location,
    [string]$sql_server_name,
    [string]$sql_db_name,
    [string]$storage_account_name
)

# 1. Key Vault Connection
# 2. Credential
# 3. Source
# 4. Scan
# 5. Trigger (Run Scan)

# Variables
$scan_endpoint = "https://${purview_account}.scan.purview.azure.com"
$proxy_endpoint = "https://${purview_account}.purview.azure.com/proxy"

# [POST] Token
function getToken([string]$tenant_id, [string]$client_id, [string]$client_secret) {
    $uri = "https://login.windows.net/${tenant_id}/oauth2/token"
    $body = @{
        "grant_type" = "client_credentials"
        "client_id" = $client_id
        "client_secret" = $client_secret
        "resource" = "https://purview.azure.net"
    }
    $params = @{
        ContentType = "application/x-www-form-urlencoded"
        Headers = @{"accept"="application/json"}
        Body = $body
        Method = "POST"
        URI = $uri
    }
    
    $token = Invoke-RestMethod @params
    
    Return "Bearer " + ($token.access_token).ToString()
}

# [PUT] Data Source
function putSource([string]$token, [hashtable]$payload) {
    $dataSourceName = $payload.name
    $uri = "${scan_endpoint}/datasources/${dataSourceName}"
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"=$token}
        Body = ($payload | ConvertTo-Json)
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [PUT] Key Vault
function putVault([string]$token, [hashtable]$payload) {
    $randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
    $keyVaultName = "keyVault-${randomId}"
    $uri = "${scan_endpoint}/azureKeyVaults/${keyVaultName}"
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"=$token}
        Body = ($payload | ConvertTo-Json)
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [PUT] Credential
function putCredential([string]$token, [hashtable]$payload) {
    $credentialName = $payload.name
    $uri = "${proxy_endpoint}/credentials/${credentialName}?api-version=2020-12-01-preview"
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"=$token}
        Body = ($payload | ConvertTo-Json -Depth 9)
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [PUT] Scan
function putScan([string]$token, [string]$dataSourceName, [hashtable]$payload) {
    $scanName = $payload.name
    $uri = "${scan_endpoint}/datasources/${dataSourceName}/scans/${scanName}"
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"=$token}
        Body = ($payload | ConvertTo-Json -Depth 9)
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [PUT] Run Scan
function runScan([string]$token, [string]$dataSourceName, [string]$scanName) {
    $guid = New-Guid
    $runId = $guid.guid
    $uri = "${scan_endpoint}/datasources/${dataSourceName}/scans/${scanName}/runs/${runId}?api-version=2018-12-01-preview"
    $params = @{
        Headers = @{"Authorization"=$token}
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# 1. Get Access Token
Write-Output "[INFO] Getting Access Token..."
$token = getToken $tenant_id $client_id $client_secret

# Note: MSI Not currently supported. Error: Audience https://purview.azure.net is not a supported MSI token audience
# $token = (Get-AzAccessToken -ResourceUrl "https://purview.azure.net").Token

# 2. Create a Key Vault Connection
$vault_payload = @{
    properties = @{
        baseUrl = $vault_uri
        description = ""
    }
}
Write-Output "[INFO] Creating Azure Key Vault Connection..."
$vault = putVault $token $vault_payload

# 3. Create a Credential
$credential_payload = @{
    name = "sql-cred"
    properties = @{
        description = ""
        type = "SqlAuth"
        typeProperties = @{
            password = @{
                secretName = $sql_secret_name
                secretVersion = ""
                store = @{
                    referenceName = $vault.name
                    type = "LinkedServiceReference"
                }
                type = "AzureKeyVaultSecret"
            }
            user = $admin_login
        }
    }
    type = "Microsoft.Purview/accounts/credentials"
}
Write-Output "[INFO] Creating Azure Purview Credential..."
putCredential $token $credential_payload

# 4. Create a Source (Azure SQL Database)
$source_sqldb_payload = @{
    id = "datasources/AzureSqlDatabase"
    kind = "AzureSqlDatabase"
    name = "AzureSqlDatabase"
    properties = @{
        collection = ""
        location = $location
        parentCollection = ""
        resourceGroup = $resource_group
        resourceName = $sql_server_name
        serverEndpoint = "${sql_server_name}.database.windows.net"
        subscriptionId = $subscription_id
    }
}
Write-Output "[INFO] Creating Data Source..."
putSource $token $source_sqldb_payload

# 5. Create a Scan Configuration
$randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
$scanName = "Scan-${randomId}"
$scan_sqldb_payload = @{
    kind = "AzureSqlDatabaseCredential"
    name = $scanName
    properties = @{
        databaseName = $sql_db_name
        scanRulesetName = "AzureSqlDatabase"
        scanRulesetType = "System"
        serverEndpoint = "${sql_server_name}.database.windows.net"
        credential = @{
            credentialType = "SqlAuth"
            referenceName = $credential_payload.name
        }
    }
}
Write-Output "[INFO] Creating Scan Configuration..."
putScan $token $source_sqldb_payload.name $scan_sqldb_payload

# 6. Trigger Scan
Write-Output "[INFO] Triggering Scan Run..."
runScan $token $source_sqldb_payload.name $scan_sqldb_payload.name

# 7. Load Storage Account with Sample Data
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resource_group -Name $storage_account_name
$RepoUrl = 'https://api.github.com/repos/nytimes/covid-19-data/zipball/master'
Invoke-RestMethod -Uri $RepoUrl -OutFile "repo.zip"
Expand-Archive -Path "repo.zip"
Set-Location -Path "repo"
Get-ChildItem -File -Recurse | Set-AzStorageBlobContent -Container "data" -Context $storageAccount.Context

# 8. Create a Source (ADLS Gen2)
$source_adls_payload = @{
    id = "datasources/AzureDataLakeStorage"
    kind = "AdlsGen2"
    name = "AzureDataLakeStorage"
    properties = @{
        collection = ""
        location = $location
        parentCollection = ""
        endpoint = "https://${storage_account_name}.dfs.core.windows.net/"
        resourceGroup = $resource_group
        resourceName = $storage_account_name
        subscriptionId = $subscription_id
    }
}
Write-Output "[INFO] Creating Data Source..."
putSource $token $source_adls_payload

# 9. Create a Scan Configuration
$randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
$scanName = "Scan-${randomId}"
$scan_adls_payload = @{
    kind = "AdlsGen2Msi"
    name = $scanName
    properties = @{
        scanRulesetName = "AdlsGen2"
        scanRulesetType = "System"
    }
}
Write-Output "[INFO] Creating Scan Configuration..."
putScan $token $source_adls_payload.name $scan_adls_payload

# 10. Trigger Scan
Write-Output "[INFO] Triggering Scan Run..."
runScan $token $source_adls_payload.name $scan_adls_payload.name