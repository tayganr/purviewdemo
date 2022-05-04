param(
    [string]$subscriptionId,
    [string]$resourceGroupName,
    [string]$accountName,
    [string]$objectId
)

Install-Module Az.Purview -Force
Import-Module Az.Purview

# Variables
$pv_endpoint = "https://${accountName}.purview.azure.com"

# [GET] Metadata Policy
function getMetadataPolicy([string]$access_token, [string]$collectionName) {
    $uri = "${pv_endpoint}/policystore/collections/${collectionName}/metadataPolicy?api-version=2021-07-01"
    echo $uri
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer $access_token"}
        Method = "GET"
        URI = $uri
    }
    echo $params
    $response = Invoke-RestMethod @params
    Return $response
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
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer $access_token"}
        Body = ($payload | ConvertTo-Json -Depth 10)
        Method = "PUT"
        URI = $uri
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# Add UAMI to Root Collection Admin
Add-AzPurviewAccountRootCollectionAdmin -AccountName $accountName -ResourceGroupName $resourceGroupName -ObjectId $objectId

# # Add User Assigned Managed Identity to Root Collection Admin
# $uri = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Purview/accounts/${accountName}/addRootCollectionAdmin?api-version=2021-07-01"
# $body = @{objectId= "${objectId}"}
# $response = Invoke-WebRequest -Uri $uri -Method POST -Body $body

# Get Access Token
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token
echo $access_token

# Update Root Collection Policy (Add Current User to Built-In Purview Roles)
$rootCollectionPolicy = getMetadataPolicy $access_token $accountName
$metadataPolicyId = $rootCollectionPolicy.id
addRoleAssignment $rootCollectionPolicy $objectId "data-curator"
addRoleAssignment $rootCollectionPolicy $objectId "data-source-administrator"
putMetadataPolicy $access_token $metadataPolicyId $rootCollectionPolicy

# Refresh Access Token
$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content = $response.Content | ConvertFrom-Json
$access_token = $content.access_token

# Get Glossary
$response = Invoke-WebRequest -Uri "https://${accountName}.purview.azure.com/catalog/api/atlas/v2/glossary" -Headers @{Authorization="Bearer $access_token"}
$content = $response.Content | ConvertFrom-Json
echo $content

