// az deployment group create -g "sandbox" -f ./bicep/purview.bicep -p ./bicep/purviewparameters.json

// Parameters
param objectId string       // Azure AD (Current User)
param clientId string       // CLIENT_ID
param clientSecret string   // CLIENT_SECRET
param spObjectId string     // OBJECT_ID
param adminLogin string
param suffix string = utcNow('ssfff')
param timestamp string = utcNow()
param roleNameGuid1 string = newGuid()
param roleNameGuid2 string = newGuid()
@secure()
param adminPassword string = newGuid()

// Variables
var location = resourceGroup().location
var subscriptionId = subscription().subscriptionId
var tenantId = subscription().tenantId
var roleDefinitionPrefix = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions'
var role = {
  PurviewDataCurator: '${roleDefinitionPrefix}/8a3c2885-9b38-4fd2-9d99-91af537c1347'
  PurviewDataReader: '${roleDefinitionPrefix}/ff100721-1b9d-43d8-af52-42b69c1272db'
  PurviewDataSourceAdministrator: '${roleDefinitionPrefix}/200bba9e-f0c8-430f-892b-6f0794863803'
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

// Assign Purview RBAC roles to Service Principal
resource roleAssignment1 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: roleNameGuid1
  scope: pv
  properties: {
    principalId: spObjectId
    roleDefinitionId: role['PurviewDataCurator']
    principalType: 'ServicePrincipal'
  }
}

// Assign Purview RBAC roles to Service Principal
resource roleAssignment2 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: roleNameGuid2
  scope: pv
  properties: {
    principalId: spObjectId
    roleDefinitionId: role['PurviewDataSourceAdministrator']
    principalType: 'ServicePrincipal'
  }
}

// Azure SQL Server
resource sqlsvr 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: 'pvdemo${suffix}-sqlsvr'
  location: location
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
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
    name: 'sql-secret'
    properties: {
      value: adminPassword
    }
  }
}

// Data Plane Operations
resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'script'
  location: resourceGroup().location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '3.0'
    arguments: '-tenant_id ${tenantId} -client_id ${clientId} -client_secret ${clientSecret} -purview_account ${pv.name} -vault_uri ${kv.properties.vaultUri}'
    scriptContent: loadTextContent('purview.ps1')
    forceUpdateTag: timestamp // script will run every time
    retentionInterval: 'PT4H' // deploymentScript resource will delete itself in 4 hours
  }
}

// output scriptOutput string = script.properties.outputs.putSource
