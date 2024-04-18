targetScope = 'subscription'
@description('Subscription ID')
@secure()
param subscriptionId string
@description('Name of the resource group.')
param rgName string
@description('Location for all resources.')
param location string
@description('Default tags to add to resource.')
param tags object
@description('Prefix for all resources.')
param resourcePrefix string
@description('Suffix for all resources.')
param resourceSuffix string

@description('Name of existing Storage Account for FSLogix accounts')
param storageAccountName string
@description('Name of public blob container for FSLogix accounts')
param fileshareName string
@description('Name of existing VNET with AD connection')
param vnetName string
@description('Name of existing subnet')
param subnetName string

@description('Name of the key vault with user credentials')
param keyVaultName string
@secure()
@description('Name of secret in key vault for domain admin username')
param domainAdminUsernameSecret string
@secure()
@description('Name of secret in key vault for domain admin password')
param domainAdminPasswordSecret string
@secure()
@description('Name of secret in key vault for local admin username')
param localAdminUsernameSecret string
@secure()
@description('Name of secret in key vault for local admin password')
param localAdminPasswordSecret string


@description('Number of already present VMs')
param vmStartNumber int
@description('Number of VMs to deploy extra')
param extraVmNumber int
@description('Name of the domain to join')
@secure()
param ADDomain string
@description('OU path to join the domain')
@secure()
param ouPath string

@description('VM Type to use')
param vmType string = 'Standard_D2s_v5'

// Get the VNET where the subnet is located
resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' existing = {
  scope: resourceGroup(rgName)
  name: vnetName
}

// Get the subnet where the VMs will be deployed
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: subnetName
  parent: vnet
}

// Create the AVD hostpool
// This is the pool of VMs that will be used for the virtual desktops
module AVDHostpool 'modules/avd-hostpool.bicep' = {
  scope: resourceGroup(rgName)
  name: 'AVDHostpool'
  params: {
    location: location
    AVDHostpoolName: '${resourcePrefix}-vdpool-${resourceSuffix}'
    AVDHostpoolManagmentType: 'Standard'
    validationEnvironment: false
    preferredAppGroupType: 'Desktop'
    AVDHostpoolType: 'Pooled'
    AVDHostpoolLoadBalancerType: 'DepthFirst'
    AVDMaxSessionLimit: 6
    tags: tags
  }
  dependsOn: [vnet]
}

// Create the AVD application group
// This is the group that will be used to assign the desktops to the users
// Assigning the users is the only manual interaction needed after the deployment
module AVDApplicationGroup 'modules/avd-applicationgroup.bicep' = {
  scope: resourceGroup(rgName)
  name: 'AVDApplicationgroup'
  params: {
    subscriptionId: subscriptionId
    rgName: rgName
    location: location
    AVDHostpoolName: AVDHostpool.outputs.name
    AVDApplicationGroupName: '${resourcePrefix}-vdag-${resourceSuffix}'
    AVDApplicationGroupType: 'Desktop'
    AVDApplicationGroupFriendlyName: 'Virtual desktop application group'
    AVDApplicationGroupDescription: 'Application group with virtual desktops.'
    AVDApplicationGroupShowInFeed: true
    tags: tags
  }
  dependsOn: [AVDHostpool]
}

// Create the AVD workspace
// This is the workspace where the virtual desktops will be assigned to the users
// This is also the name that the users will get to see in the AVD client
module AVDWorkspace 'modules/avd-workspace.bicep' = {
  scope: resourceGroup(rgName)
  name: 'AVDWorkspace'
  params: {
    location: location
    AVDWorkspaceName: '${resourcePrefix}-vdws-${resourceSuffix}'
    AVDWorkspaceFriendlyName: 'WORKSPACE ${resourcePrefix}'
    AVDWorkspaceDescription: 'Workspace with virtual desktops.'
    AVDApplicationGroupId: AVDApplicationGroup.outputs.id
    tags: tags
  }
  dependsOn: [AVDApplicationGroup]
}

// Get the key vault with the user credentials stored
resource keyVault 'Microsoft.KeyVault/vaults@2023-02-01' existing = {
  scope: resourceGroup(subscriptionId, rgName )
  name: keyVaultName
}

// Create the VMs
// This will create the VMs that will be used for the virtual desktops
// The VMs will be joined to the domain in this part as well
module AVDVm 'modules/vm.bicep' = {
  scope: resourceGroup(rgName)
  name: 'AVDVm'
  params: {
    location: location
    currentInstances: vmStartNumber
    AVDnumberOfInstances: extraVmNumber
    vmPrefix: '${resourcePrefix}-vm'
    vmType: vmType
    localAdminUsernameSecret: keyVault.getSecret(localAdminUsernameSecret)
    localAdminPasswordSecret: keyVault.getSecret(localAdminPasswordSecret)
    snetId: subnet.id
    tags: tags
    
    domainToJoin: ADDomain
    ouPath: ouPath
    domainAdminUsernameSecret: keyVault.getSecret(domainAdminUsernameSecret)
    domainAdminPasswordSecret: keyVault.getSecret(domainAdminPasswordSecret)
  }
  dependsOn: [subnet, AVDWorkspace]
}

// Post deployment script (stored in Arxus managed SA)
// This script will be used to install the FSLogix agent on the VMs and set the FSLogix regex settings
// There can only be one custom extension script on a VM
module postVMDeploy 'modules/postdeploy.bicep' = {
  scope: resourceGroup(rgName)
  name: 'postVMDeploy'
  params: {
    AVDnumberOfInstances: AVDVm.outputs.AVDNumberOfInstances
    vmPrefix: AVDVm.outputs.vmPrefix
    currentInstances: AVDVm.outputs.currentInstances
    location: location

    fileShareLocation: '\\\\${storageAccountName}.file.core.windows.net\\${fileshareName}'
    hostPoolToken: AVDHostpool.outputs.HostPoolToken
  }
  dependsOn: [AVDVm]
}
