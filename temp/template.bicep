param guid string = newGuid()
param location string = resourceGroup().location

resource pv 'Microsoft.Purview/accounts@2021-07-01' = {
  name: 'pvdemo${guid}-pv'
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  tags: {
    resourceByPass: 'allowed'
  }
}
