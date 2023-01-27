targetScope = 'subscription'

param location string = 'southcentralus'
param resourcePrefix string = 'aks-managed-natgw-bicep'

var aksResourceGroupName = '${resourcePrefix}-rg'

resource clusterrg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: aksResourceGroupName
  location: location
}

module akscluster './aks-cluster.bicep' = {
  name: resourcePrefix
  scope: clusterrg
  params: {
    location: location
    clusterName: resourcePrefix
  }
}
