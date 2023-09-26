param basename string
param subnetId string
param identity object
param principalId string
param location string

resource aksCluster 'Microsoft.ContainerService/managedClusters@2023-07-01' = {
  name: basename
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: identity
  }
  properties: {
    nodeResourceGroup: '${basename}-aksInfraRG'
    dnsPrefix: '${basename}aks'
    agentPoolProfiles: [
      {
        name: 'default'
        count: 2
        vmSize: 'Standard_D4s_v3'
        mode: 'System'
        maxPods: 50
        type: 'VirtualMachineScaleSets'
        vnetSubnetID: subnetId
      }
    ]
    networkProfile: {
      loadBalancerSku: 'standard'
      networkPlugin: 'kubenet'
      outboundType: 'loadBalancer'
      dnsServiceIP: '10.0.0.10'
      serviceCidr: '10.0.0.0/16'
    }
    enableRBAC: true
  }
}

module aksPvtNetworkContrib '../Identity/role.bicep' = {
  name: 'aksPvtNetworkContrib'
  params: {
    principalId: principalId
    roleGuid: '4d97b98b-1d4f-4787-a291-c67834d212e7' //Network Contributor
  }
}
