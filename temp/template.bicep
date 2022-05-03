// param guid1 string = newGuid()
var location = resourceGroup().location
var subscriptionId = subscription().subscriptionId
var rg = resourceGroup().name
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

// resource pv 'Microsoft.Purview/accounts@2021-07-01' = {
//   name: 'pvdemo${guid1}-pv'
//   location: location
//   identity: {
//     type: 'SystemAssigned'
//   }
//   tags: {
//     resourceByPass: 'allowed'
//   }
// }

// User Identity
resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: 'configDeployer'
}

// Assign Contributor RBAC role to User Assigned Identity (configDeployer)
// resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-08-01-preview' = {
//   name: guid('ra04${rg}')
//   scope: resourceGroup()
//   properties: {
//     principalId: userAssignedIdentity.properties.principalId
//     roleDefinitionId: role['Contributor']
//     principalType: 'ServicePrincipal'
//   }
// }

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'script'
  location: location
  kind: 'AzurePowerShell'
  properties: {
    azPowerShellVersion: '7.2'
    primaryScriptUri: 'https://raw.githubusercontent.com/tayganr/purviewdemo/main/temp/script.ps1'
    forceUpdateTag: guid(resourceGroup().id)
    retentionInterval: 'PT4H'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  // dependsOn: [
  //   roleAssignment
  // ]
}
