# Install-Module -Name Az.Purview -Force
# Import-Module -Name Az.Purview
# $kvConn = New-AzPurviewAzureKeyVaultObject -BaseUrl 'https://datascankv.vault.azure.net/' -Description 'This is a key vault'
# New-AzPurviewKeyVaultConnection -Endpoint 'https://pvdemo6uqbt-pv.purview.azure.com/' -KeyVaultName KeyVaultConnection2 -Body $kvConn

$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F' -Headers @{Metadata="true"}
$content =$response.Content | ConvertFrom-Json
$access_token = $content.access_token
echo "The managed identities for Azure resources access token is $access_token"