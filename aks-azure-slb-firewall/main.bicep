targetScope = 'subscription'

// Parameters
param location string = 'southcentralus'
param baseName string = 'aks-slb-fw'
param hubVNETaddPrefixes array = [
  '10.0.0.0/16'
]
param hubVNETdefaultSubnet object = {
  properties: {
    addressPrefix: '10.0.0.0/24'
  }
  name: 'default'
}
param hubVNETfirewalSubnet object = {
  properties: {
    addressPrefix: '10.0.1.0/24'
  }
  name: 'AzureFirewallSubnet'
}

param spokeVNETaddPrefixes array = [
  '10.1.0.0/16'
]
param spokeVNETdefaultSubnet object = {
  properties: {
    addressPrefix: '10.1.0.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
  }
  name: 'default'
}

// Variables
var aksrgName = '${baseName}-rg'
var fwrgName = 'fw-hub-rg-${baseName}'

module aksrg 'resource-group/rg.bicep' = {
  name: aksrgName
  params: {
    rgName: aksrgName
    location: location
  }
}

module fwrg 'resource-group/rg.bicep' = {
  name: fwrgName
  params: {
    rgName: fwrgName
    location: location
  }
}

module vnethub 'vnet/vnet.bicep' = {
  scope: resourceGroup(fwrg.name)
  name: 'hub-VNet'
  params: {
    location: location
    vnetAddressSpace: {
        addressPrefixes: hubVNETaddPrefixes
    }
    vnetNamePrefix: 'hub'
    subnets: [
      hubVNETdefaultSubnet
      hubVNETfirewalSubnet
    ]
  }
  dependsOn: [
    fwrg
  ]
}

module vnetspoke 'vnet/vnet.bicep' = {
  scope: resourceGroup(aksrg.name)
  name: 'spoke-VNet'
  params: {
    location: location
    vnetAddressSpace: {
        addressPrefixes: spokeVNETaddPrefixes
    }
    vnetNamePrefix: 'spoke'
    subnets: [
      spokeVNETdefaultSubnet
      {
        properties: {
          addressPrefix: '10.1.2.0/23'
          privateEndpointNetworkPolicies: 'Disabled'
          routeTable: {
            id: routetable.outputs.routetableID
          }          
        }
        name: 'AKS'
      }
    ]
  }
  dependsOn: [
    aksrg
  ]
}

module vnetpeeringhub 'vnet/vnetpeering.bicep' = {
  scope: resourceGroup(fwrg.name)
  name: 'vnetpeering'
  params: {
    peeringName: 'HUB-to-Spoke'
    vnetName: vnethub.outputs.vnetName
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: vnetspoke.outputs.vnetId
      }
    }    
  }
}

module vnetpeeringspoke 'vnet/vnetpeering.bicep' = {
  scope: resourceGroup(aksrg.name)
  name: 'vnetpeeringspoke'
  params: {
    peeringName: 'Spoke-to-HUB'
    vnetName: vnetspoke.outputs.vnetName
    properties: {
      allowVirtualNetworkAccess: true
      allowForwardedTraffic: true
      remoteVirtualNetwork: {
        id: vnethub.outputs.vnetId
      }
    }    
  }
}

module publicipfw 'vnet/publicip.bicep' = {
  scope: resourceGroup(fwrg.name)
  name: 'publicipfw'
  params: {
    location: location
    publicipName: 'fw-pip'
    publicipproperties: {
      publicIPAllocationMethod: 'Static'      
    }
    publicipsku: {
      name: 'Standard'
      tier: 'Regional'      
    }
  } 
}

resource subnetfw 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(fwrg.name)
  name: '${vnethub.name}/AzureFirewallSubnet'
}

// Variables
var managementURL = 'management.azure.com'
var loginURL = 'login.microsoftonline.com'
var corewindowsURL = 'core.windows.net'

module azfirewall 'vnet/firewall.bicep' = {
  scope: resourceGroup(fwrg.name)
  name: 'azfirewall'
  params: {
    location: location
    fwname: 'azfirewall'    
    fwipConfigurations: [
      {
        name: 'fwPublicIP'
        properties: {
          subnet: {
            id: subnetfw.id
          }
          publicIPAddress: {
            id: publicipfw.outputs.publicipId
          }
        }
      }
    ]
    fwapplicationRuleCollections: [
      {
        name: 'Helper-tools'
        properties: {
          priority: 101
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Allow-ifconfig'
              protocols: [
                {
                  port: 80
                  protocolType: 'Http'
                }
                {
                  port: 443
                  protocolType: 'Https'
                }                
              ]
              targetFqdns: [
                'ifconfig.co' 
                'api.snapcraft.io' 
                'jsonip.com' 
                'kubernaut.io' 
                'motd.ubuntu.com'
              ]
              sourceAddresses: [
                '10.0.0.0/16'
                '10.1.0.0/16'
              ]
            }
          ]
        }
      }      
      {
        name: 'AKS-egress-application'
        properties: {
          priority: 102
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'Egress'
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }                
              ]
              targetFqdns: [
                '*.azmk8s.io' 
                'aksrepos.azurecr.io'
                '*.blob.${corewindowsURL}' 
                'mcr.microsoft.com' 
                '*.cdn.mscr.io' 
                '${managementURL}' 
                '${loginURL}' 
                'packages.azure.com' 
                'acs-mirror.azureedge.net' 
                '*.opinsights.azure.com' 
                '*.monitoring.azure.com' 
                'dc.services.visualstudio.com'
              ]
              sourceAddresses: [
                '10.0.0.0/16'
                '10.1.0.0/16'
              ]
            }
            {
              name: 'Registries'
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }                
              ]
              targetFqdns: [
                '*.data.mcr.microsoft.com' 
                '*.azurecr.io' 
                '*.gcr.io' 
                'gcr.io' 
                'storage.googleapis.com' 
                '*.docker.io' 
                'quay.io' 
                '*.quay.io' 
                '*.cloudfront.net' 
                'production.cloudflare.docker.com'
              ]
              sourceAddresses: [
                '10.0.0.0/16'
                '10.1.0.0/16'
              ]
            }
            {
              name: 'Additional-Usefull-Address'
              protocols: [
                {
                  port: 443
                  protocolType: 'Https'
                }                
              ]
              targetFqdns: [
                'security.ubuntu.com' 
                'security.ubuntu.com' 
                'packages.microsoft.com' 
                'azure.archive.ubuntu.com' 
                'security.ubuntu.com'  
                '*.letsencrypt.org' 
                'usage.projectcalico.org' 
                'vortex.data.microsoft.com'
              ]
              sourceAddresses: [
                '10.0.0.0/16'
                '10.1.0.0/16'
              ]
            }  
            {
              name: 'AKS-FQDN-TAG'
              protocols: [
                {
                  port: 80
                  protocolType: 'Http'
                }                
                {
                  port: 443
                  protocolType: 'Https'
                }                
              ]
              targetFqdns: []
              fqdnTags: [
                'AzureKubernetesService'
              ]
              sourceAddresses: [
                '10.0.0.0/16'
                '10.1.0.0/16'
              ]
            }                                   
          ]
        }
      }            
    ]
    fwnatRuleCollections: []
    fwnetworkRuleCollections: [
      {
        name: 'AKS-egress'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'NTP'
              protocols: [
                'UDP'
              ]
              sourceAddresses: [
                '10.0.0.0/16'
                '10.1.0.0/16'
              ]
              destinationAddresses: [
                '*'
              ]
              destinationPorts: [
                '123'
              ]
            }
          ]
        }
      }      
    ]
  } 
}

module routetable 'vnet/routetable.bicep' = {
  scope: resourceGroup(aksrg.name)
  name: 'aks-udr'
  params: {
    location: location
    rtName: 'aks-udr'
  }
  dependsOn: [
    azfirewall
  ] 
}

module routetableroutes 'vnet/routetableroutes.bicep' = {
  scope: resourceGroup(aksrg.name)
  name: 'aks-udr-route'
  params: {
    routetableName: 'aks-udr'
    routeName: 'aks-udr-route'
    properties: {
      nextHopType: 'VirtualAppliance'
      nextHopIpAddress: azfirewall.outputs.fwPrivateIP
      addressPrefix: '0.0.0.0/0'      
    }
  }
  dependsOn: [
    routetable
  ] 
}

resource subnetaks 'Microsoft.Network/virtualNetworks/subnets@2020-11-01' existing = {
  scope: resourceGroup(aksrg.name)
  name: '${vnetspoke.name}/AKS'
}

module aksIdentity 'Identity/userassigned.bicep' = {
  scope: resourceGroup(aksrg.name)
  name: 'aksIdentity'
  params: {
    basename: baseName
    location: location
  }
}

module aksCluster 'aks/privateaks.bicep' = {
  scope: resourceGroup(aksrg.name)
  name: 'aksCluster'
  params: {
    basename: baseName
    location: location
    subnetId: subnetaks.id
    identity: {
      '${aksIdentity.outputs.identityid}' : {}
    }
    principalId: aksIdentity.outputs.principalId
  }
  dependsOn: [
    routetableroutes
  ] 
}
