param location string
param tags object

@description('Name of the AVD hostpool.')
param AVDHostpoolName string
@description('Management type of the hostpool.')
param AVDHostpoolManagmentType string
@description('Is the hostpool a validation environment?')
param validationEnvironment bool
@description('Preferred app group type.')
param preferredAppGroupType string
@description('Hostpool type.')
param AVDHostpoolType string
@description('Pooled loadbalancer type.')
param AVDHostpoolLoadBalancerType string
@description('Max session limit.')
param AVDMaxSessionLimit int

param tokenExpirationTime string = dateTimeAdd(utcNow('yyyy-MM-dd T00:00:00'),'P1D','o')

// RDP settings like only 1 monitor, open in new windows, ...
var customRdpProperty = 'drivestoredirect:s:*;audiomode:i:0;videoplaybackmode:i:1;redirectclipboard:i:1;redirectprinters:i:1;devicestoredirect:s:*;redirectcomports:i:1;redirectsmartcards:i:1;usbdevicestoredirect:s:*;enablecredsspsupport:i:1;redirectwebauthn:i:1;use multimon:i:0;screen mode id:i:1;smart sizing:i:1;dynamic resolution:i:1;'

resource AVDHostpool 'Microsoft.DesktopVirtualization/hostPools@2023-11-01-preview' = {
  name: AVDHostpoolName
  location: location

  properties: {
    managementType: AVDHostpoolManagmentType
    validationEnvironment: validationEnvironment
    preferredAppGroupType: preferredAppGroupType
    hostPoolType: AVDHostpoolType
    loadBalancerType: AVDHostpoolLoadBalancerType
    startVMOnConnect: true
    customRdpProperty: customRdpProperty
    maxSessionLimit: AVDMaxSessionLimit
    registrationInfo: {
      expirationTime: tokenExpirationTime
      registrationTokenOperation: 'Update'
    }
  }

  tags: tags
}

output name string = AVDHostpool.name
output HostPoolToken string = reference(AVDHostpool.id).registrationInfo.token
