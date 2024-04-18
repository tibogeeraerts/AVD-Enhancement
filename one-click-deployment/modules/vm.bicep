param location string
param currentInstances int
param AVDnumberOfInstances int
param vmPrefix string
param vmType string = 'Standard_D2s_v5'
@allowed(['StandardSSD_LRS', 'Premium_LRS'])
param vmDiskType string = 'StandardSSD_LRS'
param vmDiskSize int = 128
@secure()
param domainAdminUsernameSecret string
@secure()
param domainAdminPasswordSecret string
@secure()
param localAdminUsernameSecret string
@secure()
param localAdminPasswordSecret string
param snetId string
param tags object
param domainToJoin string
param ouPath string

resource AVDVm 'Microsoft.Compute/virtualMachines@2023-09-01' = [for vmNumber in range(0, AVDnumberOfInstances): {
  name: '${vmPrefix}-${vmNumber + currentInstances}'
  location: location
  tags: tags

  properties: {
    licenseType: 'Windows_Client'
    hardwareProfile: {
      vmSize: vmType
    }
    storageProfile: {
      osDisk: {
        name: '${vmPrefix}-${vmNumber + currentInstances}-osdisk'
        osType: 'Windows'
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: vmDiskType
        }
        diskSizeGB: vmDiskSize
      }
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'office-365'
        sku: 'win11-23h2-avd-m365'
        version: 'latest'
      }
      dataDisks: []
    }
    osProfile: {
      computerName: '${vmPrefix}-${vmNumber + currentInstances}'
      adminUsername: localAdminUsernameSecret
      adminPassword: localAdminPasswordSecret
      allowExtensionOperations: true
      windowsConfiguration: {
        enableAutomaticUpdates: false
        patchSettings: {
          patchMode: 'manual'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${vmPrefix}-${vmNumber + currentInstances}-nic')
        }
      ]
    }
  }
  dependsOn: [NIC[vmNumber]]
}]


resource NIC 'Microsoft.Network/networkInterfaces@2020-06-01' = [for i in range(0, AVDnumberOfInstances): {
  name: '${vmPrefix}-${i + currentInstances}-nic'
  location: location
  tags: tags

  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: snetId
          }
        }
      }
    ]
  }
}]

resource joindomain 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for i in range(0, AVDnumberOfInstances): {
  name: '${vmPrefix}-${i + currentInstances}/joindomain'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'JsonADDomainExtension'
    typeHandlerVersion: '1.3'
    autoUpgradeMinorVersion: true
    settings: {
      name: domainToJoin
      user: domainAdminUsernameSecret
      ouPath: ouPath
      restart: 'true'
      options: '3'
      NumberOfRetries: '3'
      RetryIntervalInMilliseconds: '30000'
    }
    protectedSettings: {
      password: domainAdminPasswordSecret
    }
  }
  dependsOn: [
    AVDVm[i]
  ]
}]

output AVDNumberOfInstances int = AVDnumberOfInstances
output vmPrefix string = vmPrefix
output currentInstances int = currentInstances
