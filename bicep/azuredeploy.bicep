// Parameters
@description('Please enter your Object ID. This can be found by locating your profile within Azure Portal\\Azure Active Directory\\Users.')
param objectId string       // Azure AD (Current User)
@description('Please enter the Service Principal Object ID. PowerShell: $(Get-AzureADServicePrincipal -Filter "DisplayName eq \'YOUR_SERVICE_PRINCIPAL_NAME\'").ObjectId')
param servicePrincipalObjectID string     // OBJECT_ID
@description('Please enter the Service Principal Client ID. PowerShell: $(Get-AzureADServicePrincipal -Filter "DisplayName eq \'YOUR_SERVICE_PRINCIPAL_NAME\'").AppId')
param servicePrincipalClientId string       // CLIENT_ID
@secure()
@description('Please enter the Service Principal Client Secret.')
param servicePrincipalClientSecret string   // CLIENT_SECRET
@description('Please enter the Azure SQL Server admin login.')
param sqlServerAdminLogin string = 'sqladmin'
@secure()
param sqlServerAdminPassword string = newGuid()

// Variables
var location = resourceGroup().location
var tenantId = subscription().tenantId
var subscriptionId = subscription().subscriptionId
var rg = resourceGroup().name
var suffix = substring(uniqueString(rg),0,4)
var sqlSecretName = 'sql-secret'
var rdPrefix = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions'
var role = {
  PurviewDataCurator: '${rdPrefix}/8a3c2885-9b38-4fd2-9d99-91af537c1347'
  PurviewDataReader: '${rdPrefix}/ff100721-1b9d-43d8-af52-42b69c1272db'
  PurviewDataSourceAdministrator: '${rdPrefix}/200bba9e-f0c8-430f-892b-6f0794863803'
  StorageBlobDataReader: '${rdPrefix}/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDataContributor: '${rdPrefix}/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  Contributor: '${rdPrefix}/b24988ac-6180-42a0-ab88-20f7382dd24c'
  UserAccessAdministrator: '${rdPrefix}/18d7d88d-d35e-4fb5-a5c3-7773c20a72d9'
}

// Azure Purview Account
resource pv 'Microsoft.Purview/accounts@2020-12-01-preview' = {
  name: 'pvdemo${suffix}-pv'
  location: location
  sku: {
    name: 'Standard'
    capacity: 4
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Assign Purview Data Curator RBAC role to Service Principal
resource roleAssignment1 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra01${rg}')
  scope: pv
  properties: {
    principalId: servicePrincipalObjectID
    roleDefinitionId: role['PurviewDataCurator']
    principalType: 'ServicePrincipal'
  }
}

// Assign Purview Data Source Administrator RBAC role to Service Principal
resource roleAssignment2 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra02${rg}')
  scope: pv
  properties: {
    principalId: servicePrincipalObjectID
    roleDefinitionId: role['PurviewDataSourceAdministrator']
    principalType: 'ServicePrincipal'
  }
}

// Azure SQL Server
resource sqlsvr 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: 'pvdemo${suffix}-sqlsvr'
  location: location
  properties: {
    administratorLogin: sqlServerAdminLogin
    administratorLoginPassword: sqlServerAdminPassword
  }
  resource firewall1 'firewallRules' = {
    name: 'allowAzure'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '0.0.0.0'
    }
  }
  resource firewall2 'firewallRules' = {
    name: 'allowAll'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }
}

// Azure SQL Database
resource sqldb 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  parent: sqlsvr
  name: 'pvdemo${suffix}-sqldb'
  location: location
  sku: {
    name: 'GP_S_Gen5'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    catalogCollation: 'SQL_Latin1_General_CP1_CI_AS'
    autoPauseDelay: 60
    requestedBackupStorageRedundancy: 'Local'
    sampleName: 'AdventureWorksLT'
  }
}

// Azure Key Vault
resource kv 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: 'pvdemo${suffix}-keyvault'
  location: location
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableSoftDelete: false
    tenantId: tenantId
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId
        permissions:{
          secrets: [
            'get'
            'list'
            'set'
            'delete'
            'recover'
            'backup'
            'restore'
          ]
        }
      }
      {
        tenantId: tenantId
        objectId: pv.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  resource secret 'secrets' = {
    name: sqlSecretName
    properties: {
      value: sqlServerAdminPassword
    }
  }
}

// Azure Storage Account
resource adls 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'pvdemo${suffix}adls'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true
  }
  resource blobService 'blobServices' existing = {
    name: 'default'
    resource blobContainer 'containers' = {
      name: 'data'
      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

// User Identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'configDeployer'
  location: location
}

// Assign Storage Blob Data Reader RBAC role to Azure Purview MI
resource roleAssignment3 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra03${rg}')
  scope: adls
  properties: {
    principalId: pv.identity.principalId
    roleDefinitionId: role['StorageBlobDataReader']
    principalType: 'ServicePrincipal'
  }
}

// Assign Contributor RBAC role to User Assigned Identity (configDeployer)
resource roleAssignment4 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra04${rg}')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: role['Contributor']
    principalType: 'ServicePrincipal'
  }
}

// Assign User Access Administrator RBAC role to Current User
resource roleAssignment5 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra05${rg}')
  scope: pv
  properties: {
    principalId: objectId
    roleDefinitionId: role['UserAccessAdministrator']
    principalType: 'User'
  }
}

// Assign Purview Data Curator RBAC role to Azure Data Factory MI
resource roleAssignment6 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra06${rg}')
  scope: pv
  properties: {
    principalId: adf.identity.principalId
    roleDefinitionId: role['PurviewDataCurator']
    principalType: 'ServicePrincipal'
  }
}

// Storage Blob Data Contributor RBAC role to Azure Data Factory MI
resource roleAssignment7 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra07${rg}')
  scope: adls
  properties: {
    principalId: adf.identity.principalId
    roleDefinitionId: role['StorageBlobDataContributor']
    principalType: 'ServicePrincipal'
  }
}

// Azure Data Factory
resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'pvdemo${suffix}-adf'
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
    purviewConfiguration: {
      purviewResourceId: pv.id
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    catalogUri: '${pv.name}.catalog.purview.azure.com'
  }
}

// Data Plane Operations
resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'script'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '3.0'
    arguments: '-tenant_id ${tenantId} -client_id ${servicePrincipalClientId} -client_secret ${servicePrincipalClientSecret} -purview_account ${pv.name} -vault_uri ${kv.properties.vaultUri} -admin_login ${sqlServerAdminLogin} -sql_secret_name ${sqlSecretName} -subscription_id ${subscriptionId} -resource_group ${rg} -location ${location} -sql_server_name ${sqlsvr.name} -sql_db_name ${sqldb.name} -storage_account_name ${adls.name}'
    scriptContent: loadTextContent('purview.ps1')
    // primaryScriptUri: 'https://raw.githubusercontent.com/tayganr/purviewdemo/main/bicep/purview.ps1'
    forceUpdateTag: guid(resourceGroup().id)
    retentionInterval: 'PT4H' // deploymentScript resource will delete itself in 4 hours
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  dependsOn: [
    pv
    adls
    roleAssignment4
  ]
}
