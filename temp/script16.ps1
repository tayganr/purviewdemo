param(
    [string]$subscriptionId,
    [string]$resourceGroupName,
    [string]$accountName,
    [string]$objectId,
    [string]$sqlAdminLogin,
    [string]$sqlSecretName,
    [string]$vaultUri
)

Install-Module Az.Purview -Force
Import-Module Az.Purview

# Variables
$pv_endpoint = "https://${accountName}.purview.azure.com"

# [GET] Metadata Policy
function getMetadataPolicy([string]$access_token, [string]$collectionName) {
    $uri = "${pv_endpoint}/policystore/collections/${collectionName}/metadataPolicy?api-version=2021-07-01"
    $response = Invoke-WebRequest -Uri $uri -Headers @{Authorization="Bearer $access_token"} -ContentType "application/json" -Method "GET"
    Return $response.Content | ConvertFrom-Json -Depth 10
}

# Modify Metadata Policy
function addRoleAssignment([object]$policy, [string]$principalId, [string]$roleName) {
    Foreach ($attributeRule in $policy.properties.attributeRules) {
        if (($attributeRule.name).StartsWith("purviewmetadatarole_builtin_${roleName}:")) {
            Foreach ($conditionArray in $attributeRule.dnfCondition) {
                Foreach($condition in $conditionArray) {
                    if ($condition.attributeName -eq "principal.microsoft.id") {
                        $condition.attributeValueIncludedIn += $principalId
                    }
                 }
            }
        }
    }
}

# [PUT] Metadata Policy
function putMetadataPolicy([string]$access_token, [string]$metadataPolicyId, [object]$payload) {
    $uri = "${pv_endpoint}/policystore/metadataPolicies/${metadataPolicyId}?api-version=2021-07-01"
    $body = ($payload | ConvertTo-Json -Depth 10)
    $response = Invoke-WebRequest -Uri $uri -Headers @{Authorization="Bearer $access_token"} -ContentType "application/json" -Method "PUT" -Body $body
    Return $response.Content | ConvertFrom-Json -Depth 10
}

# [PUT] Key Vault
function putVault([string]$access_token, [hashtable]$payload) {
    $randomId = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 3 |ForEach-Object{[char]$_})
    $keyVaultName = "keyVault-${randomId}"
    $uri = "${pv_endpoint}/scan/azureKeyVaults/${keyVaultName}"
    $body = ($payload | ConvertTo-Json)
    $response = Invoke-WebRequest -Uri $uri -Headers @{Authorization="Bearer $access_token"} -ContentType "application/json" -Method "PUT" -Body $body
    Return $response.Content | ConvertFrom-Json -Depth 10
}

# [PUT] Credential
function putCredential([string]$access_token, [hashtable]$payload) {
    $credentialName = $payload.name
    $uri = "${pv_endpoint}/proxy/credentials/${credentialName}?api-version=2020-12-01-preview"
    $body = ($payload | ConvertTo-Json -Depth 9)
    $response = Invoke-RestMethod @params
    $response = Invoke-WebRequest -Uri $uri -Headers @{Authorization="Bearer $access_token"} -ContentType "application/json" -Method "PUT" -Body $body
    Return $response.Content | ConvertFrom-Json -Depth 10
}

# [PUT] Scan
function putScan([string]$access_token, [string]$dataSourceName, [hashtable]$payload) {
    $scanName = $payload.name
    $uri = "${pv_endpoint}/scan/datasources/${dataSourceName}/scans/${scanName}"
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer $access_token"}
        Body = ($payload | ConvertTo-Json -Depth 9)
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [PUT] Run Scan
function runScan([string]$access_token, [string]$datasourceName, [string]$scanName) {
    $uri = "${pv_endpoint}/scan/datasources/${datasourceName}/scans/${scanName}/run?api-version=2018-12-01-preview"
    $payload = @{ scanLevel = "Full" }
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer $access_token"}
        Body = ($payload | ConvertTo-Json)
        Method = "POST"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [POST] Create Glossary
function createGlossary([string]$access_token) {
    $uri = "${pv_endpoint}/catalog/api/atlas/v2/glossary"
    $payload = @{
        name = "Glossary"
        qualifiedName = "Glossary"
    }
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer $access_token"}
        Method = "POST"
        URI = $uri
        Body = ($payload | ConvertTo-Json -Depth 4)
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# [POST] Import Glossary Terms
function importGlossaryTerms([string]$access_token, [string]$glossaryGuid, [string]$glossaryTermsTemplateUri) {
    $glossaryTermsFilename = "import-terms-sample.csv"
    Invoke-RestMethod -Uri $glossaryTermsTemplateUri -OutFile $glossaryTermsFilename
    $glossaryImportUri = "${pv_endpoint}/catalog/api/atlas/v2/glossary/${glossaryGuid}/terms/import?includeTermHierarchy=true&api-version=2021-05-01-preview"
    $fieldName = 'file'
    $filePath = (Get-Item $glossaryTermsFilename).FullName
    Add-Type -AssemblyName System.Net.Http
    $client = New-Object System.Net.Http.HttpClient
    $content = New-Object System.Net.Http.MultipartFormDataContent
    $fileStream = [System.IO.File]::OpenRead($filePath)
    $fileContent = New-Object System.Net.Http.StreamContent($fileStream)
    $content.Add($fileContent, $fieldName, $glossaryTermsFilename)
    $access_token = $access_token.split(" ")[1]
    $client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $access_token)
    $result = $client.PostAsync($glossaryImportUri, $content).Result
    return $result
}

# Add UAMI to Root Collection Admin
Add-AzPurviewAccountRootCollectionAdmin -AccountName $accountName -ResourceGroupName $resourceGroupName -ObjectId $objectId

# Get Access Token
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token

# Update Root Collection Policy (Add Current User to Built-In Purview Roles)
$rootCollectionPolicy = getMetadataPolicy $access_token $accountName
addRoleAssignment $rootCollectionPolicy $objectId "data-curator"
addRoleAssignment $rootCollectionPolicy $objectId "data-source-administrator"
putMetadataPolicy $access_token $rootCollectionPolicy.id $rootCollectionPolicy

# Refresh Access Token
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token

# Get Glossary
$response = Invoke-WebRequest -Uri "https://${accountName}.purview.azure.com/catalog/api/atlas/v2/glossary" -Headers @{Authorization="Bearer $access_token"}
$content = $response.Content | ConvertFrom-Json

# 2. Create a Key Vault Connection
$vault_payload = @{
    properties = @{
        baseUrl = $vaultUri
        description = ""
    }
}
$vault = putVault $access_token $vault_payload

# 3. Create a Credential
$credential_payload = @{
    name = "sql-cred"
    properties = @{
        description = ""
        type = "SqlAuth"
        typeProperties = @{
            password = @{
                secretName = $sqlSecretName
                secretVersion = ""
                store = @{
                    referenceName = $vault.name
                    type = "LinkedServiceReference"
                }
                type = "AzureKeyVaultSecret"
            }
            user = $sqlAdminLogin
        }
    }
    type = "Microsoft.Purview/accounts/credentials"
}
putCredential $access_token $credential_payload

# # 5. Create Collections (Sales and Marketing)
# $collectionSales = putCollection $access_token "Sales" $purview_account
# $collectionMarketing = putCollection $access_token "Marketing" $purview_account
# $collectionSalesName = $collectionSales.name
# $collectionMarketingName = $collectionMarketing.name
# Start-Sleep 30