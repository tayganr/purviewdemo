// Parameters
@description('Please specify a login name for the Azure SQL Server administrator. Default value: sqladmin.')
param sqlServerAdminLogin string = 'sqladmin'
@secure()
@description('Please specify a password for the Azure SQL Server administrator. Default value: newGuid().')
param sqlServerAdminPassword string = newGuid()

// Variables
var tenantId = subscription().tenantId
var location = resourceGroup().location
var subscriptionId = subscription().subscriptionId
var resourceGroupName = resourceGroup().name
var rdPrefix = '/subscriptions/${subscriptionId}/providers/Microsoft.Authorization/roleDefinitions'
var role = {
  Owner: '${rdPrefix}/8e3af657-a8ff-443c-a75c-2fe8c4bcb635'
  Contributor: '${rdPrefix}/b24988ac-6180-42a0-ab88-20f7382dd24c'
  StorageBlobDataReader: '${rdPrefix}/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1'
  StorageBlobDataContributor: '${rdPrefix}/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}
var sqlSecretName = 'sql-secret'
var suffix = substring(uniqueString(resourceGroup().id, deployment().name),0,5)

// Purview Account
resource purviewAccount 'Microsoft.Purview/accounts@2021-07-01' = {
  name: 'pvdemo${suffix}-pv'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    resourceByPass: 'allowed'
  }
}

// Managed Identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: 'configDeployer'
  location: location
}

// Role Assignment: Who: Managed Identity (configDeployer); What: Owner (RBAC role); Scope: Resource Group
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra01${resourceGroupName}')
  scope: resourceGroup()
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: role['Owner']
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
        objectId: userAssignedIdentity.properties.principalId
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
        objectId: purviewAccount.identity.principalId
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

// Azure Storage Account (ADLS Gen2)
resource adls 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'pvdemo${suffix}adls'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true
    allowBlobPublicAccess: true
  }
  resource blobService 'blobServices' = {
    name: 'default'
    resource blobContainer 'containers' = {
      name: 'bing'
      properties: {
        publicAccess: 'Blob'
      }
    }
  }
}

// Azure Data Factory
resource adf 'Microsoft.DataFactory/factories@2018-06-01' = {
  name: 'pvdemo${suffix}-adf'
  location: location
  properties: {
    publicNetworkAccess: 'Enabled'
    purviewConfiguration: {
      purviewResourceId: purviewAccount.id
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    catalogUri: '${purviewAccount.name}.catalog.purview.azure.com'
  }
  resource linkedServiceStorage 'linkedservices@2018-06-01' = {
    name: 'AzureDataLakeStorageLinkedService'
    properties: {
      type: 'AzureBlobFS'
      typeProperties: {
        url: adls.properties.primaryEndpoints.dfs
      }
    }
  }
  resource datasetSource 'datasets@2018-06-01' = {
    name: 'SourceDataset_a9c'
    properties: {
      linkedServiceName: {
        referenceName: linkedServiceStorage.name
        type: 'LinkedServiceReference'
      }
      type: 'DelimitedText'
      typeProperties: {
        location: {
          type: 'AzureBlobFSLocation'
          folderPath: 'data/2020'
          fileSystem: 'bing'
        }
        columnDelimiter: '\t'
        rowDelimiter: '\n'
        escapeChar: '\\'
        firstRowAsHeader: true
        quoteChar: '"'
      }
      schema: [
        {
          name: 'Date'
          type: 'String'
        }
        {
          name: 'Query'
          type: 'String'
        }
        {
          name: 'IsImplicitIntent'
          type: 'String'
        }
        {
          name: 'Country'
          type: 'String'
        }
        {
          name: 'PopularityScore'
          type: 'String'
        }
      ]
    }
  }
  resource datasetDestination 'datasets@2018-06-01' = {
    name: 'SourceDestination_a9c'
    properties: {
      linkedServiceName: {
        referenceName: linkedServiceStorage.name
        type: 'LinkedServiceReference'
      }
      type: 'Parquet'
      typeProperties: {
        location: {
          type: 'AzureBlobFSLocation'
          fileName: 'merged.parquet'
          folderPath: 'data'
          fileSystem: 'bing'
        }
        compressionCodec: 'snappy'
      }
      schema: []
    }
  }
  resource pipelineCopy 'pipelines@2018-06-01' = {
    name: 'copyPipeline'
    properties: {
      activities: [
        {
          name: 'Copy_a9c'
          type: 'Copy'
          dependsOn: []
          typeProperties: {
            source: {
              type: 'DelimitedTextSource'
              storeSettings: {
                type: 'AzureBlobFSReadSettings'
                recursive: true
                wildcardFileName: '*'
                enablePartitionDiscovery: false
              }
              formatSettings: {
                type: 'DelimitedTextReadSettings'
                skipLineCount: 0
              }
            }
            sink: {
              type: 'ParquetSink'
              storeSettings: {
                type: 'AzureBlobFSWriteSettings'
                copyBehavior: 'MergeFiles'
              }
              formatSettings: {
                type: 'ParquetWriteSettings'
              }
            }
            enableStaging: false
            validateDataConsistency: false
          }
          inputs: [
            {
              referenceName: datasetSource.name
              type: 'DatasetReference'
            }
          ]
          outputs: [
            {
              referenceName: datasetDestination.name
              type: 'DatasetReference'
            }
          ]
        }
      ]
    }
  }
}

// Azure Storage Account (ADLS Gen2 - Synapse Workspace)
resource swsadls 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'pvdemo${suffix}synapsedl'
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    isHnsEnabled: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
  resource service 'blobServices' = {
    name: 'default'
    resource container 'containers' = {
      name: 'synapsefs${suffix}'
    }
  }
}

// Azure Synapse Analytics Workspace
resource sws 'Microsoft.Synapse/workspaces@2021-05-01' = {
  name: 'pvdemo${suffix}-synapse'
  location: location
  properties: {
    defaultDataLakeStorage: {
      accountUrl: reference(swsadls.name).primaryEndpoints.dfs
      filesystem: 'synapsefs${suffix}'
    }
    purviewConfiguration: {
      purviewResourceId: '/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/Microsoft.Purview/accounts/${purviewAccount.name}'
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  resource firewall 'firewallRules' = {
    name: 'allowAll'
    properties: {
      startIpAddress: '0.0.0.0'
      endIpAddress: '255.255.255.255'
    }
  }
}

// Role Assignment: Who: Managed Identity (Purview); What: Storage Blob Data Reader (RBAC role); Scope: ADLS Gen2 Storage Account
resource roleAssignment3 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra03${resourceGroupName}')
  scope: adls
  properties: {
    principalId: purviewAccount.identity.principalId
    roleDefinitionId: role['StorageBlobDataReader']
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment: Who: Managed Identity (Data Factory); What: Storage Blob Data Contributor (RBAC role); Scope: ADLS Gen2 Storage Account
resource roleAssignment7 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra07${resourceGroupName}')
  scope: adls
  properties: {
    principalId: adf.identity.principalId
    roleDefinitionId: role['StorageBlobDataContributor']
    principalType: 'ServicePrincipal'
  }
}

// Role Assignment: Who: Managed Identity (Synapse Analytics); What: Storage Blob Data Contributor (RBAC role); Scope: ADLS Gen2 Storage Account (Synapse Workspace)
resource roleAssignment8 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
  name: guid('ra08${resourceGroupName}')
  scope: swsadls
  properties: {
    principalId: sws.identity.principalId
    roleDefinitionId: role['StorageBlobDataContributor']
    principalType: 'ServicePrincipal'
  }
}

// Assign Storage Blob Data Reader RBAC role to Current User
// resource roleAssignment9 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
//   name: guid('ra09${resourceGroupName}')
//   scope: adls
//   properties: {
//     principalId: azureActiveDirectoryObjectID
//     roleDefinitionId: role['StorageBlobDataReader']
//     principalType: 'User'
//   }
// }

// Post Deployment Script (Data Plane Operations)
resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'script'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.2'
    arguments: '-subscriptionId ${subscriptionId} -resourceGroupName ${resourceGroupName} -accountName ${purviewAccount.name} -objectId ${userAssignedIdentity.properties.principalId} -sqlServerAdminLogin ${sqlServerAdminLogin} -sqlSecretName ${sqlSecretName} -vaultUri ${kv.properties.vaultUri} -sqlServerName ${sqlsvr.name} -location ${location} -sqlDatabaseName ${sqldb.name} -storageAccountName ${adls.name} -adfName ${adf.name} -adfPipelineName ${adf::pipelineCopy.name} -adfPrincipalId ${adf.identity.principalId}'
    primaryScriptUri: 'https://raw.githubusercontent.com/tayganr/purviewdemo/main/scripts/script.ps1'
    forceUpdateTag: guid(resourceGroup().id)
    retentionInterval: 'PT4H'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  dependsOn: [
    roleAssignment
  ]
}
