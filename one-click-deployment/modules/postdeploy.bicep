param AVDnumberOfInstances int
param vmPrefix string
param currentInstances int
param location string
param fileShareLocation string
param hostPoolToken string

resource PostDeployScript 'Microsoft.Compute/virtualMachines/extensions@2020-12-01' = [for i in range(0, AVDnumberOfInstances): {
  name: '${vmPrefix}-${i + currentInstances}/PostDeployScript'
  location: location
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.10'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris: [
        'https://avdtibostorage.blob.core.windows.net/public/PostDeployScript2.ps1'
      ]
    }
    protectedSettings: {
      commandToExecute: 'powershell.exe -ExecutionPolicy Bypass -File PostDeployScript.ps1 -FileshareLocation ${fileShareLocation} -HostpoolToken ${hostPoolToken}'
    }
  }
}]
