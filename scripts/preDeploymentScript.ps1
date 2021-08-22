function getUserPrincipalId() {
    $principalId = $null
    Do {
        $emailAddress = Read-Host -Prompt "Please enter your Azure AD email address"
        $principalId = (Get-AzAdUser -Mail $emailAddress).id
        if ($null -eq $principalId) { $principalId = (Get-AzAdUser -UserPrincipalName $emailAddress).Id } 
        if ($null -eq $principalId) { Write-Host "Unable to find a user within the Azure AD with email address: ${emailAddress}. Please try again." }
    } until($null -ne $principalId)
    Return $principalId
}

function selectLocation() {
    $locationList='australiaeast', 'brazilsouth', 'canadacentral', 'centralindia', 'eastus', 'eastus2', 'southcentralus', 'southeastasia', 'uksouth', 'westeurope'
    $location = Get-Random -InputObject $locationList
    Return $location
}

function createServicePrincipal([string]$subscriptionId, [string]$resourceGroupName, [string]$suffix) {
    $scope = "/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}"
    $sp = New-AzADServicePrincipal -DisplayName "pvDemoServicePrincipal-${suffix}" -Role "Owner" -Scope $scope
    Return $sp
}

function getAccessToken([string]$tenantId, [string]$clientId, [string]$clientSecret, [string]$resource) {
    $requestAccessTokenUri = "https://login.microsoftonline.com/${tenantId}/oauth2/token"
    $body = "grant_type=client_credentials&client_id=${clientId}&client_secret=${clientSecret}&resource=${resource}"
    $token = Invoke-RestMethod -Method Post -Uri $requestAccessTokenUri -Body $body -ContentType 'application/x-www-form-urlencoded'
    $accessToken = $token.access_token
    Return $accessToken
}

function deployTemplate([string]$accessToken, [string]$templateLink, [string]$resourceGroupName, [hashtable]$parameters) {
    $randomId = -join ((65..90) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
    $deploymentName = "deployment-${randomId}"
    $scope = "/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}"
    $deploymentUri = "https://management.azure.com${scope}/providers/Microsoft.Resources/deployments/${deploymentName}?api-version=2021-04-01"
    $deploymentBody = @{
        "properties" = @{
            "templateLink" = @{
                "uri" = $templateLink
            }
            "parameters" = $parameters
            "mode" = "Incremental"
        }
    }
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer ${accessToken}"}
        Body = ($deploymentBody | ConvertTo-Json -Depth 9)
        Method = "PUT"
        URI = $deploymentUri
    }
    $job = Invoke-RestMethod @params
    Return $job
}

function getDeployment([string]$accessToken, [string]$subscriptionId, [string]$resourceGroupName, [string]$deploymentName) {
    $params = @{
        ContentType = "application/json"
        Headers = @{"Authorization"="Bearer ${accessToken}"}
        Method = "GET"
        URI = "https://management.azure.com/subscriptions/${subscriptionId}/resourcegroups/${resourceGroupName}/providers/Microsoft.Resources/deployments/${deploymentName}?api-version=2021-04-01"
    }
    $response = Invoke-RestMethod @params
    Return $response
}

# Variables
$tenantId = (Get-AzContext).Tenant.Id
$subscriptionId = (Get-AzContext).Subscription.Id
$principalId = getUserPrincipalId
$suffix = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
$location = selectLocation

# Create Resource Group
$resourceGroup = New-AzResourceGroup -Name "pvdemo-rg-${suffix}" -Location $location
$resourceGroupName = $resourceGroup.ResourceGroupName

# Create Service Principal
$sp = createServicePrincipal $subscriptionId $resourceGroupName $suffix
Start-Sleep -Seconds 10
$clientId = $sp.ApplicationId
$clientSecret = $sp.secret | ConvertFrom-SecureString -AsPlainText
$accessToken = getAccessToken $tenantId $clientId $clientSecret "https://management.core.windows.net/"

# Create Azure Purview Account (as Service Principal)
$templateLink = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/templates/purviewdeploy.json" 
$parameters = @{ suffix = @{ value = $suffix } }
$deployment = deployTemplate $accessToken $templateLink $resourceGroupName $parameters
$deploymentName = $deployment.name

$progress = ('.', '..', '...')
$provisioningState = ""
While ($provisioningState -ne "Succeeded") {
    Foreach ($x in $progress) {
        Clear-Host
        Write-Host "Deployment 1 of 2 is in progress, this will take approximately 5 minutes"
        Write-Host "Running${x}"
        Start-Sleep 1
    }
    $provisioningState = (getDeployment $accessToken $subscriptionId $resourceGroupName $deploymentName).properties.provisioningState
}

# Deploy Template
$templateUri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/templates/azuredeploy.json"
$job = New-AzResourceGroupDeployment `
  -Name "pvDemoTemplate-${suffix}" `
  -ResourceGroupName $resourceGroupName `
  -TemplateUri $templateUri `
  -azureActiveDirectoryObjectID $principalId `
  -servicePrincipalClientID $sp.ApplicationId `
  -servicePrincipalClientSecret $sp.Secret `
  -suffix $suffix `
  -AsJob

$progress = ('.', '..', '...')
While ($job.State -eq "Running") {
    Foreach ($x in $progress) {
        Clear-Host
        Write-Host "Deployment 2 of 2 is in progress, this will take approximately 10 minutes"
        Write-Host "Running${x}"
        Start-Sleep 1
    }
}

# Clean-Up Service Principal
Remove-AzRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $sp.Id -RoleDefinitionName "Contributor"
Remove-AzADServicePrincipal -ObjectId $sp.Id -Force
Remove-AzADApplication -DisplayName $sp.DisplayName -Force

# Clean-Up User Assigned Managed Identity
$configAssignment = Get-AzRoleAssignment -ResourceGroupName $resourceGroupName | Where-Object {$_.DisplayName.Equals("configDeployer")}
Remove-AzRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $configAssignment.ObjectId -RoleDefinitionName "Contributor"

# Deployment Complete
$pv = (Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Purview/accounts").Name
Clear-Host
Write-Host "Deployment complete! https://web.purview.azure.com/resource/${pv}`r`nNote: The Azure Data Factory pipeline and Azure Purview scans may still be running, these jobs will complete shortly."
