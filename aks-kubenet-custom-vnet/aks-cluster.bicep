param location string
param clusterName string
param aksSubnetId string
param nodeCount int = 2
param vmSize string = 'standard_d2s_v3'
param agentpoolName string = 'nodepool1'
param aksClusterNetworkPlugin string = 'kubenet'
param aksClusterPodCidr string = '192.168.0.0/16'
param aksClusterServiceCidr string = '172.16.0.0/16'
param aksClusterDnsServiceIP string = '172.16.0.10'
param aksClusterDockerBridgeCidr string = '172.17.0.1/16'
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
        vnetSubnetID: aksSubnetId
      }
    ]
    networkProfile: {
      networkPlugin: aksClusterNetworkPlugin
      podCidr: aksClusterPodCidr
      serviceCidr: aksClusterServiceCidr
      dnsServiceIP: aksClusterDnsServiceIP
      dockerBridgeCidr: aksClusterDockerBridgeCidr
      outboundType: aksClusterOutboundType
      loadBalancerSku: aksClusterLoadBalancerSku
    }
  }
}

output aks_principal_id string = aks.identity.principalId
