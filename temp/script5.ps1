param(
    [string]$subscriptionId,
    [string]$resourceGroupName,
    [string]$accountName,
    [string]$objectId
)

Install-Module Az.Purview -Force
Import-Module Az.Purview

Add-AzPurviewAccountRootCollectionAdmin -AccountName $accountName -ResourceGroupName $resourceGroupName -ObjectId $objectId

# # Add User Assigned Managed Identity to Root Collection Admin
# $uri = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Purview/accounts/${accountName}/addRootCollectionAdmin?api-version=2021-07-01"
# $body = @{objectId= "${objectId}"}
# $response = Invoke-WebRequest -Uri $uri -Method POST -Body $body

$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content =$response.Content | ConvertFrom-Json
$access_token = $content.access_token

$response = Invoke-WebRequest -Uri "https://${accountName}.purview.azure.com/catalog/api/atlas/v2/glossary" -Headers @{Authorization="Bearer $access_token"}
$content =$response.Content | ConvertFrom-Json
echo $content

