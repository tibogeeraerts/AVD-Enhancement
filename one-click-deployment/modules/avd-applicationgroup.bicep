@description('Subscription ID')
@secure()
param subscriptionId string
@description('Name of the resource group.')
param rgName string
@description('Location for all resources.')
param location string
@description('Default tags to add to resource.')
param tags object

param AVDHostpoolName string

@description('Name of the AVD application group.')
param AVDApplicationGroupName string
@description('Application group type.')
param AVDApplicationGroupType string
@description('Description of the AVD application group.')
param AVDApplicationGroupDescription string
@description('Friendly name of the AVD application group.')
param AVDApplicationGroupFriendlyName string
var HpoolArmPath = '/subscriptions/${subscriptionId}/resourceGroups/${rgName}/providers/Microsoft.DesktopVirtualization/hostPools/${AVDHostpoolName}'
@description('Should the application group be shown in the feed?')
param AVDApplicationGroupShowInFeed bool


resource AVDApplicationGroup 'Microsoft.DesktopVirtualization/applicationGroups@2023-11-01-preview' = {
  name: AVDApplicationGroupName
  location: location

  properties: {
    applicationGroupType: AVDApplicationGroupType
    description: AVDApplicationGroupDescription
    friendlyName: AVDApplicationGroupFriendlyName
    hostPoolArmPath: HpoolArmPath
    showInFeed: AVDApplicationGroupShowInFeed
  }

  tags: tags
}

output id string = AVDApplicationGroup.id
output name string = AVDApplicationGroup.name
