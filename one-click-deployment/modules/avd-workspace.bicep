@description('Location for all resources.')
param location string
@description('Default tags to add to resource.')
param tags object

@ description('Name of the AVD workspace.')
param AVDWorkspaceName string
@description('Friendly name of the AVD workspace.')
param AVDWorkspaceFriendlyName string
@description ('Description of the AVD workspace.')
param AVDWorkspaceDescription string

@description('ID of Application group.')
param AVDApplicationGroupId string

resource AVDWorkspace 'Microsoft.DesktopVirtualization/workspaces@2023-11-01-preview' = {
  name: AVDWorkspaceName
  location: location
  properties: {
    friendlyName: AVDWorkspaceFriendlyName
    description: AVDWorkspaceDescription
    applicationGroupReferences: [AVDApplicationGroupId]
  }
  tags: tags
}

output name string = AVDWorkspace.name
