# Standalone code

## Project setup
These 3 scripts contain the powershell code that needs to be used on a local machine.
These powershell scripts can be downloaded and used for personal usage.

## Add-Hosts-Interactive
<details><summary>Content</summary>

### Requirements
- [ ] Azure subscription ID
- [ ] Location
- [ ] Azure Key Vault name
    - [ ] Local admin username secret
    - [ ] Local admin password secret
    - [ ] Domain join account username secret
    - [ ] Domain join account password secret
- [ ] AD domain
    - [ ] optional: OU Path
- [ ] Subnet
- [ ] Domain joined file share

### How to use
To use this code you have to download the powershell script and fill out all the variable names in the beginning of the script. Starting at line 53, there are variables that need values corresponding to your Azure setup.

#### Variables
These are the required variables for each possible setup.

| Variable            | Value                                            |
| --------            | ------------------------------------------------ |
| Subscription ID     | ID of Azure subscription with AVD setup          |
| Location            | Location of resources in Azure                   |
| KvName              | Name of key vault storing all needed credentials |

These are the variables for a hostpool with no existing virtual machine in it.

| Variable            | Value                                                          |
| ------------------- | -------------------------------------------------------------- |
| Prefix              | Prefix for new virtual machines in hostpool                    |
| HighestVmNumber     | Higherst number in existing hostpool                           |
| VmSize              | Type of virtual machine to deploy                              |
| LocalAdminUserName  | Change name in query to secret name of corresponding user      |
| LocalAdminPassword  | Change name in query to secret name of corresponding password  |
| DomainAdminUsername | Change name in query to secret name of corresponding user      |
| DomainAdminPassword | Change name in query to secret name of corresponding password  |
| OuPath              | OU path where virtual machines should be placed                |
| DiskSize            | Size of new disks that will be made                            |
| DiskType            | Type of new disks that will be made                            |
| SubnetId            | The subnet where the new virtual machines will be placed       |
| MarketPlaceImage    | Boolean value to choose custom compute image or default image  |
| CustomImageId       | Resources ID of custom compute image in case wanted            |
| FileshareLocation   | Location of domain joined file share to store FSLogix accounts |

### Running the script
After filling out the required parameters, you can start the script by running
```Powershell
.\Add-Hosts-Interactive.ps1
```
in the folder where the script is located. A browser window will open to verify the login of the user and from there script will start with asking the questions for the user.

#### Possible scenarios
Script is started and no changes need to be made:
![interactivecli-nochanges][image-interactivecli-nochanges]

Script is started and no changes need to be made:
![interactivecli-changeimage][image-interactivecli-changeimage]

Script is started and image gets changed:
![interactivecli-changename][image-interactivecli-changename]
</details>





## hpool-redeployer-no-parameters
<details><summary>Content</summary>

For this script, the intention is to modify all the parameters in the code and then start the script. No more parameters need to be entered as they are all already in the script.

### Requirements
- [ ] Azure subscription ID
- [ ] Resource group
- [ ] Location
- [ ] Azure Key Vault name
    - [ ] Local admin username secret
    - [ ] Local admin password secret
    - [ ] Domain join account username secret
    - [ ] Domain join account password secret
- [ ] AD domain
    - [ ] optional: OU Path
- [ ] Subnet
- [ ] Domain joined file share

### How to use
To use this code you have to download the powershell script and fill out all the variable names in the beginning of the script. After that the script can be ran like a normal Powershell script.

#### Variables
These are the required variables for each possible setup. Most of these variables will be overwritten by the gathered data from an existing VM in the hostpool.

| Variable            | Value                                                                                  |
| --------            | -------------------------------------------------------------------------------------- |
| Subscription ID     | ID of Azure subscription with AVD setup                                                |
| Resource group      | Resource group waar virtuele machines bij horen                                        |
| Location            | Location of resources in Azure                                                         |
| KvName              | Name of key vault storing all needed credentials                                       |
|                     |                                                                                        |
| LocalAdminUserName  | Change name in query to secret name of corresponding user                              |
| LocalAdminPassword  | Change name in query to secret name of corresponding password                          |
| DomainAdminUsername | Change name in query to secret name of corresponding user                              |
| DomainAdminPassword | Change name in query to secret name of corresponding password                          |
| OuPath              | OU path where virtual machines should be placed                                        |
| FileshareLocation   | Location of domain joined file share to store FSLogix accounts                         |
|                     |                                                                                        |
| ReuseVMNumbers      | Boolean value to reuse existing vm names or create new ones                            |
| AmountOfVMs         | Integer value that specifies how many new VMs should be deployed                       |
| DeleteExistingHosts | Boolean value that when true, will allow deletion of existing VMs                      |
| DrainExistingHosts  | Boolean value that will set existing VMs in hostpool to draining mode                  |
| Prefix              | Prefix for new virtual machines in hostpool                                            |
| HighestVmNumber     | Higherst number in existing hostpool                                                   |
| VmSize              | Type of virtual machine to deploy                                                      |
| DiskSize            | Size of new disks that will be made                                                    |
| DiskType            | Type of new disks that will be made                                                    |
| SubnetId            | The subnet where the new virtual machines will be placed                               |
|                     |                                                                                        |
| UseNewImage         | Boolean value to change OS image from current image in hostpool                        |
| UseCustomImage      | Boolean value to choose custom image or Windows default image                          |
| VmImageId           | When deploying VMs with new custom image, this should be the resource ID of that image |
| VmImagePublisher    | When deploying VMs with Windows standard image, this is the publisher name to select   |
| VmImageOffer        | When deploying VMs with Windows standard image, this is the offer name to select       |
| VmImageSku          | When deploying VMs with Windows standard image, this is the sku name to select         |
| VmImageVersion      | When deploying VMs with Windows standard image, this is the version to select          |
| SecurityType        | Some custom images need special security types, this can be defined here               |


### Running the script
After filling out the parameters, you can start the script by running
```Powershell
.\hpool-redeployer-no-parameters.ps1
```
The script will then replace the hosts in the hostpool as configured with the parameters.

#### Possible scenarios
A possible scenario for this script can be that a frequently used hostpool is expecting a lot of new users. The system administrator want to update the hosts in the hostpool to a new custom OS image and deploy 10 virtual machines instead of the 3 that are existing now.
![hpool-redeploy-noparameters][image-hpool-redeploy-noparameters]

After this redeployment the new hosts can be found in the hostpool in the portal.
![hpool-redeploy-noparameters-portal][image-hpool-redeploy-noparameters-portal]
</details>





## hpool-redeployer-with-parameters
<details><summary>Content</summary>

In this script, some default parameters can be modified in the script itself but most of the parameters are best given when the script is started. This way, 1 script can be used to redeploy multiple host pools.

### Requirements
- [ ] Azure subscription ID
- [ ] Resource group
- [ ] Location
- [ ] Azure Key Vault name
    - [ ] Local admin username secret
    - [ ] Local admin password secret
    - [ ] Domain join account username secret
    - [ ] Domain join account password secret
- [ ] AD domain
    - [ ] optional: OU Path
- [ ] Subnet
- [ ] Domain joined file share

### How to use
To use this code you have to download the powershell script and place it in a folder. There you can start the script including all listed parameters that are required and the needed parameters for what you want to archieve.

#### Variables
There are mandatory parameters for this script and optional parameters. The optional parameters can be left empty or can be given a default value. The mandatory parameters will need to be given a value when calling the script.

| Mandatory parameters | Value                                                                                  |
| --------             | -------------------------------------------------------------------------------------- |
| ResourceGroup        | Resource group waar virtuele machines bij horen                                        |
| HostpoolName         | Resource group waar virtuele machines bij horen                                        |
| KvName               | Name of key vault storing all needed credentials                                       |
| FileshareLocation    | Location of domain joined file share to store FSLogix accounts                         |
| ReuseVMNumbers       | Boolean value to reuse existing vm names or create new ones                            |
| AmountOfVMs          | Integer value that specifies how many new VMs should be deployed                       |
| UseNewImage          | Boolean value to change OS image from current image in hostpool                        |

| Optional parameters  |                                                                                        |
| --------             | -------------------------------------------------------------------------------------- |
| Location             | Location of resources in Azure                                                         |
| LocalAdminUserName   | Change name in query to secret name of corresponding user                              |
| LocalAdminPassword   | Change name in query to secret name of corresponding password                          |
| DomainAdminUsername  | Change name in query to secret name of corresponding user                              |
| DomainAdminPassword  | Change name in query to secret name of corresponding password                          |
| OuPath               | OU path where virtual machines should be placed                                        |
| DeleteExistingHosts  | Boolean value that when true, will allow deletion of existing VMs                      |
| DrainExistingHosts   | Boolean value that will set existing VMs in hostpool to draining mode                  |
| Prefix               | Prefix for new virtual machines in hostpool                                            |
| VmSize               | Type of virtual machine to deploy                                                      |
| UseCustomImage       | Boolean value to choose custom image or Windows default image                          |
| VmImageId            | When deploying VMs with new custom image, this should be the resource ID of that image |
| VmImageSku           | When deploying VMs with Windows standard image, this is the sku name to select         |
| SecurityType         | Some custom images need special security types, this can be defined here               |

There are also variables that can be filled out but are not required if the hostpool has existing virtual machines.
| Variables            |                                                                                        |
| -------------------- | -------------------------------------------------------------------------------------- |
| HighestVmNumber      | Higherst number in existing hostpool                                                   |
| DiskSize             | Size of new disks that will be made                                                    |
| DiskType             | Type of new disks that will be made                                                    |
| SubnetId             | The subnet where the new virtual machines will be placed                               |
| VmImagePublisher     | When deploying VMs with Windows standard image, this is the publisher name to select   |
| VmImageOffer         | When deploying VMs with Windows standard image, this is the offer name to select       |
| VmImageVersion       | When deploying VMs with Windows standard image, this is the version to select          |


### Running the script
For running this script it is best to gather all parameters you want to adjust for this script beforehand. When all parameters are found, the minimum script can be started with:
```Powershell
.\hpool-redeployer-with-parameters.ps1 -ResourceGroup "string" -HostpoolName "string" -KvName "string"  -FileshareLocation "string" -ReuseVMNumbers $true/$false -AmountOfVMs 1 -UseNewImage $true/$false
```

To change all parameters, use this command:
```Powershell
.\hpool-redeployer-with-parameters.ps1 -ResourceGroup "string" -HostpoolName "string" -KvName "string" -Location "string" -LocalAdminUsernameKVSecret "string" -LocalAdminPasswordKVSecret "string" -DomainAdminUsernameKVSecret "string" -DomainAdminPasswordKVSecret "string" -OuPath "string" -FileshareLocation "string" -ReuseVMNumbers $true/$false -AmountOfVMs 1 -DeleteExistingHosts $true/$false -DrainExistingHosts $true/$false -Prefix "string" -VmSize "string" -UseNewImage $true/$false -UseCustomImage $true/$false -VmImageId "string" -VmImageSku "string" -SecurityType "string"
```

#### Possible scenarios
A possible scenario for this script can be that a new customer want to test the hostpool redeployment script on a testing environment. To change all the virtual machines in a hostpool from a standard Windows image to a custom image from his compute gallery.
![hpool-redeploy-withparameters][image-hpool-redeploy-withparameters]
The results of this update are shown in the portal as the new hosts appear in the hostpool.
![hpool-redeploy-withparameters-portal][image-hpool-redeploy-withparameters-portal]
When looking at the virtual machines in the portal you can also see that the new image is being used.
![hpool-redeploy-withparameters-vms-portal][image-hpool-redeploy-withparameters-vms-portal]
</details>


<!-- MARKDOWN LINKS & IMAGES -->
[image-interactivecli-nochanges]: ../images/interactivecli-nochanges.png
[image-interactivecli-changeimage]: ../images/interactivecli-changeimage.png
[image-interactivecli-changename]: ../images/interactivecli-changename.png
[image-hpool-redeploy-noparameters]: ../images/hpool-redeploy-noparameters.png
[image-hpool-redeploy-noparameters-portal]: ../images/hpool-redeploy-noparameters-portal.png
[image-hpool-redeploy-withparameters]: ../images/hpool-redeploy-withparameters.png
[image-hpool-redeploy-withparameters-portal]: ../images/hpool-redeploy-withparameters-portal.png
[image-hpool-redeploy-withparameters-vms-portal]:../images/hpool-redeploy-withparameters-vms-portal.png