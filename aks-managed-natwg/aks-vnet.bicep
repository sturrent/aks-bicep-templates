param location string
param vnetName string
param vvnetPreffix array
param subnets array

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: vvnetPreffix
    }
    subnets: subnets
  }
}

var aksSubnetId = resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, 'aks-subnet')

output akssubnet string = aksSubnetId
