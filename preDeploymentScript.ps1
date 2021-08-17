# Azure AD Object ID
$principalId = $null
Do {
    $emailAddress = Read-Host -Prompt "Please enter your Azure AD email address"
    $principalId = (Get-AzAdUser -Mail $emailAddress).id
    if ($principalId -eq $null) { $principalId = (Get-AzAdUser -UserPrincipalName $emailAddress).Id } 
    if ($principalId -eq $null) { Write-Host "Unable to find a user within the Azure AD with email address: ${emailAddress}. Please try again." }
} until($principalId -ne $null)

# Suffix
$suffix = -join ((65..90) + (97..122) | Get-Random -Count 5 | % {[char]$_})

# Location
$locationList='australiaeast', 'brazilsouth', 'canadacentral', 'centralindia', 'eastus', 'eastus2', 'southcentralus', 'southeastasia', 'uksouth', 'westeurope'
$location = Get-Random -InputObject $locationList

# Resource Group
$rg = New-AzResourceGroup -Name "pvdemo-rg-${suffix}" -Location $location

# Service Principal
$subscriptionId = (Get-AzContext).Subscription.Id
$rgName = $rg.ResourceGroupName
$scope = "/subscriptions/${subscriptionId}/resourceGroups/${rgName}"
$sp = New-AzADServicePrincipal -DisplayName "pvDemoServicePrincipal-${suffix}" -Scope $scope

# Deploy Template
$templateUri = "https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/azuredeploy.json"
$job = New-AzResourceGroupDeployment `
  -Name "pvDemoTemplate-${suffix}" `
  -ResourceGroupName $rgName `
  -TemplateUri $templateUri `
  -objectID $principalId `
  -servicePrincipalObjectID $sp.Id `
  -servicePrincipalClientID $sp.ApplicationId `
  -servicePrincipalClientSecret $sp.Secret `
  -AsJob

$progress = ('.', '..', '...')
While ($job.State -eq "Running") {
    Foreach ($x in $progress) {
        cls
        Write-Host "Deployment is in progress, this will take approximately 10 minutes"
        Write-Host "Running${x}"
        Start-Sleep 1
    }
}

# Clean-Up Service Principal
Remove-AzRoleAssignment -ResourceGroupName $rgName -ObjectId $sp.Id -RoleDefinitionName "Contributor"
Remove-AzADServicePrincipal -ObjectId $sp.Id -Force
Remove-AzADApplication -DisplayName $sp.DisplayName -Force

# Clean-Up User Assigned Managed Identity
$configAssignment = Get-AzRoleAssignment -ResourceGroupName $rgName | Where-Object {$_.DisplayName.Equals("configDeployer")}
Remove-AzRoleAssignment -ResourceGroupName $rgName -ObjectId $configAssignment.ObjectId -RoleDefinitionName "Contributor"

# Deployment Complete
$pv = (Get-AzResource -ResourceGroupName $rgName -ResourceType "Microsoft.Purview/accounts").Name
cls
Write-Host "Deployment complete! https://web.purview.azure.com/resource/${pv}`r`nNote: The Azure Data Factory pipeline and Azure Purview scans may still be running, these jobs will complete shortly."