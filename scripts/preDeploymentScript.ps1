function getUserPrincipalId([string]$userName) {
    $principalId = (Get-AzAdUser -UserPrincipalName $userName).id
    <#$principalId = $null
    Do {
        $emailAddress = Read-Host -Prompt "Please enter your Azure AD email address"
        $principalId = (Get-AzAdUser -Mail $emailAddress).id
        if ($null -eq $principalId) { $principalId = (Get-AzAdUser -UserPrincipalName $emailAddress).Id } 
        if ($null -eq $principalId) { Write-Host "Unable to find a user within the Azure AD with email address: ${emailAddress}. Please try again." }
    } until($null -ne $principalId)
    #>
    Return $principalId
}

function selectLocation() {
    $location = $null
    $purviewLocations = (Get-AzLocation | Where-Object {$_.Providers -contains "Microsoft.Purview"}).Location
    Write-Host "`r`n"
    Write-Host "Locations:"
    Foreach ($x in $purviewLocations | Sort-Object) {
        Write-Host " - $x"
    }
    Do {
        $location = Read-Host -Prompt "Please enter a valid location"
        If ($purviewLocations -contains $location) {
            continue
        } else {
            Write-Host "$location is an invalid location"
            $location = $null
        }
    } until($null -ne $location)
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
    $accessToken = $null
    try {
        $token = Invoke-RestMethod -Method Post -Uri $requestAccessTokenUri -Body $body -ContentType 'application/x-www-form-urlencoded'
        $accessToken = $token.access_token
        Write-Host "Access token generated successfully!"
    } catch {
        Start-Sleep 1
        Write-Host "Pending access token..."
    }
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
    $job = $null
    try {
        $job = Invoke-RestMethod @params
    } catch {
        Write-Host "[Error] Something went wrong when trying to deploy the template." -ForegroundColor White -BackgroundColor Red
        Write-Host $_.Exception
    }
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
$azContext = Get-AzContext
$tenantId = $azContext.Tenant.Id
$subscriptionId = $azContext.Subscription.Id
$subscriptionName = $azContext.Subscription.Name
$userName = ((az account show) | ConvertFrom-Json -Depth 10).user.name
$principalId = getUserPrincipalId $userName
$context = [PSCustomObject]@{
    TenantID = $tenantId
    SubscriptionName = $subscriptionName
    SubscriptionId = $subscriptionId
    UserName = $userName
    PrincipalID = $principalId
}

# Confirm Environment Context
Write-Host("`r`nThe Azure Purview demo will be deployed in the following environment.`n`n{0}" -f ($context | Format-Table | Out-String))
Do {
    $valid = "Y", "N"
    $proceed = Read-Host -Prompt "Would you like to proceed? (Y/N)"
    If ($proceed.ToUpper() -eq "Y") {
        continue
    } elseif ($proceed.ToUpper() -eq "N") {
        exit
    } else {
        Write-Host "$proceed is an invalid response."
    }
} until($valid.contains($proceed.ToUpper()))
if ($proceed.ToUpper() -eq "N") {
    Write-Host "Trying to exit..."
    exit
}

# Resource Providers
$registeredResourceProviders = Get-AzResourceProvider | Select-Object ProviderNamespace 
$requiredResourceProviders = @("Microsoft.Authorization","Microsoft.DataFactory","Microsoft.EventHub","Microsoft.KeyVault","Microsoft.Purview","Microsoft.Storage","Microsoft.Sql","Microsoft.Synapse")
Write-Host "`n"
Write-Host "[INFO] Checking that the required resource providers are registered..."
foreach ($rp in $requiredResourceProviders) {
    if ($registeredResourceProviders -match $rp) {
        Write-Host "  [OK] ${rp}"
    } else {
        Write-Host "`r`n"
        Write-Host "The following resource provider is not registered: ${rp}" -ForegroundColor Black -BackgroundColor Yellow
        Write-Host "Attempting to register resource provider: ${rp}"
        Register-AzResourceProvider -ProviderNamespace $rp
        Do {
            $regState = (Get-AzResourceProvider -ProviderNamespace Microsoft.Purview)[0].RegistrationState
            Write-Progress "Registration in progress for resource provider: ${rp}. Current state: ${regState}."
            Start-Sleep 5
        } until($regState -eq "Registered")
        Write-Host "  [OK] ${rp}"
    }
}

$suffix = -join ((48..57) + (97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
$location = selectLocation

# Create Resource Group
$resourceGroup = New-AzResourceGroup -Name "pvdemo-rg-${suffix}" -Location $location
$resourceGroupName = $resourceGroup.ResourceGroupName
Write-Host "Resource Group: $resourceGroupName"

# Create Service Principal
$sp = createServicePrincipal $subscriptionId $resourceGroupName $suffix
$clientId = $sp.AppId
$clientSecret = $sp.PasswordCredentials.SecretText
$accessToken = $null
While ($null -eq $accessToken) {
    $accessToken = getAccessToken $tenantId $clientId $clientSecret "https://management.core.windows.net/"
}

# Create Azure Purview Account (as Service Principal)
$templateLink = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/templates/json/purviewdeploy.json" 
$parameters = @{ suffix = @{ value = $suffix } }
$deployment = deployTemplate $accessToken $templateLink $resourceGroupName $parameters
if ($null -eq $deployment) {
    exit
}
$deploymentName = $deployment.name

$progress = ('.', '..', '...')
$provisioningState = ""
While ($provisioningState -ne "Succeeded") {
    Foreach ($x in $progress) {
        Write-Progress "Deployment 1 of 2 is in progress, this will take approximately 5 minutes${x}"
        Start-Sleep 1
    }
    $provisioningState = (getDeployment $accessToken $subscriptionId $resourceGroupName $deploymentName).properties.provisioningState
}

# Deploy Template
$templateUri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/templates/json/azuredeploy.json"
$secureSecret = ConvertTo-SecureString -AsPlainText $sp.PasswordCredentials.SecretText
$job = New-AzResourceGroupDeployment `
  -Name "pvDemoTemplate-${suffix}" `
  -ResourceGroupName $resourceGroupName `
  -TemplateUri $templateUri `
  -azureActiveDirectoryObjectID $principalId `
  -servicePrincipalClientID $clientId `
  -servicePrincipalClientSecret $secureSecret `
  -suffix $suffix `
  -AsJob

if ($job.State -ne "Running") {
    Write-Host "[Error] Something went wrong with deployment 2."
    $job | Format-List -Property *
    exit
}

$progress = ('.', '..', '...')
While ($job.State -eq "Running") {
    Foreach ($x in $progress) {
        Write-Progress "Deployment 2 of 2 is in progress, this will take approximately 10 minutes${x}"
        Start-Sleep 1
    }
}

# # Clean-Up Service Principal
Remove-AzRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $sp.Id -RoleDefinitionName "Owner"
Remove-AzADServicePrincipal -ObjectId $sp.Id
Remove-AzADApplication -DisplayName $sp.DisplayName

# # Clean-Up User Assigned Managed Identity
$configAssignment = Get-AzRoleAssignment -ResourceGroupName $resourceGroupName | Where-Object {$_.DisplayName.Equals("configDeployer")}
Remove-AzRoleAssignment -ResourceGroupName $resourceGroupName -ObjectId $configAssignment.ObjectId -RoleDefinitionName "Contributor"

# Deployment Complete
$pv = (Get-AzResource -ResourceGroupName $resourceGroupName -ResourceType "Microsoft.Purview/accounts").Name
Write-Host "Deployment complete! https://web.purview.azure.com/resource/${pv}`r`nNote: The Azure Data Factory pipeline and Azure Purview scans may still be running, these jobs will complete shortly."
