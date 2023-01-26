param location string
param clusterName string
param nodeCount int = 2
param vmSize string = 'standard_d2s_v3'
param agentpoolName string = 'nodepool1'
param aksClusterNetworkPlugin string = 'azure'
@description('Specifies outbound (egress) routing method. - loadBalancer or userDefinedRouting.')
@allowed([
  'loadBalancer'
  'managedNATGateway'
  'userAssignedNATGateway'
  'userDefinedRouting'
])
param aksClusterOutboundType string = 'loadBalancer'
param aksClusterLoadBalancerSku string = 'standard'

resource aks 'Microsoft.ContainerService/managedClusters@2021-05-01' = {
  name: clusterName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dnsPrefix: clusterName
    enableRBAC: true
    agentPoolProfiles: [
      {
        name: agentpoolName
        count: nodeCount
        vmSize: vmSize
        mode: 'System'
      }
    ]
    networkProfile: {
      networkPlugin: aksClusterNetworkPlugin
      outboundType: aksClusterOutboundType
      loadBalancerSku: aksClusterLoadBalancerSku
    }
  }
}

output aks_principal_id string = aks.identity.principalId
