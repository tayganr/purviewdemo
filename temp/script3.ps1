$response = Invoke-WebRequest -Uri 'http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fpurview.azure.net%2F' -Headers @{Metadata="true"}
$content =$response.Content | ConvertFrom-Json
$access_token = $content.access_token

$response = Invoke-WebRequest -Uri 'https://pvdemo6uqbt-pv.purview.azure.com/catalog/api/atlas/v2/glossary' -Headers @{Authorization="Bearer $access_token"}
$content =$response.Content | ConvertFrom-Json
echo $content