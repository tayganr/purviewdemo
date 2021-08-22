param suffix string

resource pv 'Microsoft.Purview/accounts@2020-12-01-preview' = {
  name: 'pvdemo${suffix}-pv'
  location: resourceGroup().location
  sku: {
    name: 'Standard'
    capacity: 1
  }
  identity: {
    type: 'SystemAssigned'
  }
}
