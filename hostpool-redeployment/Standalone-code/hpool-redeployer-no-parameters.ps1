# IMPORTANT parameters
$ResourceGroup = "rg-xxx"
$HostpoolName = "vdpool-xxx"
$KvName = "kv-xxx"
$Location = "westeurope"

# Domain parameters
$LocalAdminUsernameKVSecret = "localadmin-username"
$LocalAdminPasswordKVSecret = "localadmin-password"
$DomainAdminUsernameKVSecret = "domainadmin-username"
$DomainAdminPasswordKVSecret = "domainadmin-password"
$LocalAdminUsername = Get-AzKeyVaultSecret -VaultName $kvName -Name "localadmin-username" -AsPlainText
$LocalAdminPassword = Get-AzKeyVaultSecret -VaultName $kvName -Name "localadmin-password" -AsPlainText | ConvertTo-SecureString -Force -AsPlainText
[pscredential]$LocalCredentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $LocalAdminPassword)
$DomainAdminUsername = Get-AzKeyVaultSecret -VaultName $kvName -Name "domainadmin-username" -AsPlainText
$DomainAdminPassword = Get-AzKeyVaultSecret -VaultName $kvName -Name "domainadmin-password" -AsPlainText
$Domain = $DomainAdminUsername.Split('@')[1]
$OuPath = "OU=xxx,DC=domain,DC=com"
$FileshareLocation = "\\xxx.file.core.windows.net\xxx"

# VM creation parameters
$NewVmNames = @()
$ReuseVMNumbers = $false
$AmountOfVMs = 1
$DeleteExistingHosts = $false
$DrainExistingHosts = $true
$Prefix = "xxx"
$HighestVmNumber = 0
$VmSize = "Standard_D2s_v5"
$DiskSize = 128
$DiskType = "Standard_LRS"
$SubnetId = "/subscriptions/xxx/resourceGroups/rg-xxx/providers/Microsoft.Network/virtualNetworks/vnet-xxx/subnets/snet-xxx"

# VM Image parameters
$UseNewImage = $true
$UseCustomImage = $true
$VmImageId = "/subscriptions/xxxx/resourceGroups/rg-arx-avd-shared/providers/Microsoft.Compute/galleries/gal-xxx/images/xxx/versions/1.0.0"
$VmImagePublisher = "microsoftwindowsdesktop"
$VmImageOffer = "office-365"
$VmImageSku = "win11-23h2-avd-m365"
$VmImageVersion = "latest"
$SecurityType = "TrustedLaunch"

# Check parameters
if ($ReuseVMNumbers) {
    $DeleteExistingHosts = $true
    $DrainExistingHosts = $false
} else {
    if ($AmountOfVMs -lt 1) {
        Write-Host "Amount of VMs must be at least 1" -ForegroundColor Red
        exit
    }
    if (($DeleteExistingHosts) -eq $true -AND ($DrainExistingHosts -eq $true)) {
        Write-Host "Cannot delete and drain existing hosts at the same time" -ForegroundColor Red
        exit
    }
}

if ($UseNewImage) {
    if ($UseCustomImage -eq $true) {
        if ($null -eq $VmImageId) {
            Write-Host "Image resource ID is required when using custom gallery image" -ForegroundColor Red
            exit
        }
    } else {
        if ($VmImageSku -eq $null) {
            Write-Host "Image Sku is required when using marketplace image" -ForegroundColor Red
            exit
        }
    }
} else {
    $UseNewImage = $false
}

###############################
#        Start Script         #
###############################
$startTime = Get-Date

# Log start of script
Write-Host -ForegroundColor Blue "[INFO]     : " -NoNewline
Write-Host -ForegroundColor White "Starting script!"

# GetHostpoolVMs
$CurrentSessionHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName
$CurrentVmNames = @()
foreach ($SessionHost in $CurrentSessionHosts) {
    $CurrentVmNames += $SessionHost.Name.Split('/')[1].Split('.')[0]
}

# Check for existing hosts
if ($CurrentSessionHosts.Count -eq 0) {
    Write-Host -ForegroundColor Blue "[INFO]     : " -NoNewline
    Write-Host -ForegroundColor White "No existing hosts found"
} else {
    Write-Host -ForegroundColor Blue "[INFO]     : " -NoNewline
    Write-Host -ForegroundColor White "Found session hosts: " -NoNewline
    Write-Host -Separator ", " -ForegroundColor Cyan $CurrentVmNames

    # Get highest VM number in pool
    foreach ($VmName in $CurrentSessionHosts) {
        $VmName = $VmName.Name.Split('/')[1]
        $SessionHostNumber = [int]$VmName.Split('-')[-1].Split('.')[0]
        if ($SessionHostNumber -gt $HighestVmNumber) {
            $HighestVmNumber = $SessionHostNumber
            $LastVmName = $VmName.Split('.')[0]
        }
    }

    # Change default variable values with existing setup values
    $LastVMInfo = Get-AzVM -ResourceGroupName $ResourceGroup -Name $LastVMName

    if ($LastVMName -match '-') {
        # VMName contains hyphens so cutting of prefix before last section of the split
        $lastSection = $LastVMName.split('-')[-1]
        $Prefix = ($LastVMName.split('-') -join '-').replace("-$lastSection", "")
    } else {
        # VMName contains no hyphens. Assume last numbers to be the VM number
        $regex = '[0-9]+$'
        $Prefix = $LastVMName -replace $regex, ''
    }

    $VmSize = $LastVMInfo.HardwareProfile.VmSize
    $Domain = $CurrentSessionHosts[-1].Name.Split('/')[1].Split('.', 2)[1]
    if($null -eq $Domain) {
        $Domain = $DomainAdminUsername.Split('@')[1]
    }
    $Tags = $LastVMInfo.Tags

    # Get OU if available
    $JsonADDomainExtension = $LastVMInfo.Extensions | Where-Object { $_.Publisher -eq "Microsoft.Compute" -and $_.Type -eq "JsonADDomainExtension" }
    if ($JsonADDomainExtension) {
        $OuPath = $JsonADDomainExtension.Settings.OrganizationalUnitDN
    } else { $OuPath = "" }

    # Set disk variables
    $DiskName = $LastVMInfo.StorageProfile.OsDisk.Name
    $Disk     = Get-azDisk | Where-Object {$_.Id -eq  $LastVMInfo.StorageProfile.OsDisk.ManagedDisk.Id }
    $DiskSize = $Disk.DiskSizeGB
    $DiskType = $Disk.Sku.Name

    # Set nic variables
    $NicName = $LastVMInfo.NetworkProfile.NetworkInterfaces[0].Id.Split("/")[-1]
    $SubnetId = Get-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NicName | Select-Object -ExpandProperty IpConfigurations | Select-Object -ExpandProperty Subnet | Select-Object -ExpandProperty Id

    # Delete or drain existing hosts
    if ($DeleteExistingHosts) {
        Write-Host -ForegroundColor Yellow "[INFO]     : " -NoNewline; Write-Host -ForegroundColor White "Deleting existing VMs"

        $CurrentSessionHosts | ForEach-Object -Parallel {
            $RG = $($using:ResourceGroup)
            $HP = $($using:HostpoolName)
            $SessionHostName = $_.Name.Split('/')[1]
            $VmName = $SessionHostName.Split('.')[0]

            $VMinfo = Get-azVM -resourcegroupName $RG -Name $VmName
            
            # Update NIC config so it won't auto delete
            # Write-Output "Updating NIC so it will auto-delete"
            $VmInfo.NetworkProfile.NetworkInterfaces[0].DeleteOption = 'Delete'

            # Write-Output "Updating OSDisk so it will auto-delete"
            $VmInfo.StorageProfile.OsDisk.DeleteOption = 'Delete'

            $DataDisks = $VmInfo.StorageProfile.DataDisks

            if ($dataDisks) {
                # Write-Output "Updating DataDisks so they will auto-delete"
                forEach ($disk in $dataDisks) {
                    $disk.DeleteOption = 'Delete'
                }
            }
            
            $VMInfo | Update-AzVM | Out-Null

            # Write-Output "Deleting $VmName"
            Remove-AzWvdSessionHost -ResourceGroupName $RG -HostPoolName $HP -Name $SessionHostName | Out-Null
            Remove-AzVM -ResourceGroupName $RG -Name $VmName -Force | Out-Null
        }

        Write-Host -ForegroundColor Green "[SUCCES]   : " -NoNewline; Write-Host -ForegroundColor White "VM(s) deleted succesfully"
    } elseif ($DrainExistingHosts) {
        Write-Host -ForegroundColor Yellow "[INFO]     : " -NoNewline; Write-Host -ForegroundColor White "Draining existing VMs"

        foreach ($existingVm in $CurrentSessionHosts) {
            $HostpoolVmName = $existingVm.Name.Split('/')[1]
            $VmName = $HostpoolVmName.Split('.')[0]
            Update-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -Name $HostpoolVmName -AllowNewSession:$false | Out-Null
            Set-AzResource -ResourceGroupName $ResourceGroup -name $VmName -Tags $DrainingTags -ResourceType "Microsoft.Compute/VirtualMachines" -Force | Out-Null
        }
        Write-Host -ForegroundColor Green "[SUCCES]   : " -NoNewline; Write-Host -ForegroundColor White "VM(s) set to drain succesfully"
    } else {
        Write-Error "No action selected for existing VMs (IMPOSSIBLE)"
        exit
    }

    # Change security type if not Standard
    if ($LastVMInfo.SecurityProfile.SecurityType) {
        $SecurityType = $LastVMInfo.SecurityProfile.SecurityType
    }
}

if ($Tags.ContainsKey("AIR-ImageDefinition")) {
    $Tags["AIR-ImageDefinition"] = "$VmImageSku\$VmImageVersion"
} else {
    $Tags += @{"AIR-ImageDefinition"= "$VmImageSku\$VmImageVersion"}
}

$RegistrationToken = (Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostpoolName -resourceGroupName $ResourceGroup).Token
if (!$RegistrationToken) {
    Write-Output "Generating new registration token..."
    $RegistrationToken = (New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))).Token
}

# Create new VM names
$NewVmNames = @()
for ($i = 1; $i -le $AmountOfVMs; $i++) {
    $VmNumber = $HighestVmNumber + $i
    $VmName = "$Prefix-${VmNumber}"
    $NewVmNames += $VmName
}

# DEPLOY VMs
Write-Host "[DEPLOYING]: " -ForegroundColor Green -NoNewline
Write-Host $NewVmNames -ForegroundColor Cyan -Separator ", "

# Create new VMs
$NewVmNames | ForEach-Object -Parallel {
    $VmName = $_
    $ResourceGroup = $($using:ResourceGroup)
    $Location = $($using:Location)
    $RegistrationToken = $($using:RegistrationToken)
    $VmSize = $($using:VmSize)
    $VmImageId = $($using:VmImageId)
    $VmImagePublisher = $($using:VmImagePublisher)
    $VmImageOffer = $($using:VmImageOffer)
    $VmImageSku = $($using:VmImageSku)
    $VmImageVersion = $($using:VmImageVersion)
    $SecurityType = $($using:SecurityType)
    $LocalCredentials = $($using:LocalCredentials)
    $DomainAdminUsername = $($using:DomainAdminUsername)
    $DomainAdminPassword = $($using:DomainAdminPassword)
    $Domain = $($using:Domain)
    $OuPath = $($using:OuPath)
    $FileshareLocation = $($using:FileshareLocation)
    $Tags = $($using:Tags)
    $UseNewImage = $($using:UseNewImage)
    $UseCustomImage = $($using:UseCustomImage)

    $DiskSize = $($using:DiskSize)
    $DiskType = $($using:DiskType)

    $SubnetId = $($using:SubnetId)

    $NicName = "${VmName}-nic"
    $DiskName = "${VmName}-osdisk"

    $VM = New-AzVMConfig -VMName $VmName -VMSize $VmSize -SecurityType $SecurityType -Tags $Tags
    $NIC = New-AzNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroup -Location $Location -SubnetId $SubnetId -Force

    $VM = Set-AzVMOperatingSystem -VM $VM -Windows -ComputerName $VmName -Credential $LocalCredentials -ProvisionVMAgent -EnableAutoUpdate
    $VM = Add-AzVMNetworkInterface -VM $VM -Id $NIC.Id -DeleteOption "Detach"
    $VM = Set-AzVMOSDisk -VM $VM -Name $DiskName -DiskSizeInGB $DiskSize -StorageAccountType $DiskType -CreateOption "FromImage" -Caching "ReadWrite" -DeleteOption "Detach"
    $VM = Set-AzVMBootDiagnostic -VM $VM -Disable

    if ($UseNewImage) {
        if ($UseCustomImage) {
            $VM = Set-AzVMSourceImage -VM $VM -Id $VmImageId
        } else {
            $VM = Set-AzVMSourceImage -VM $VM -PublisherName $VmImagePublisher -Offer $VmImageOffer -Skus $VmImageSku -Version $VmImageVersion
        }
    } else {
        $VM = Set-AzVMSourceImage -VM $VM -PublisherName $VmImagePublisher -Offer $VmImageOffer -Skus $VmImageSku -Version $VmImageVersion
    }

    Write-Output "[${VmName}] : Creating..."
    New-AzVM -VM $VM -ResourceGroupName $ResourceGroup -Location $Location -DisableBginfoExtension -licenseType "Windows_Client" | Out-Null

    Write-Output "[${VmName}] : Running domain join"
    $domainJoinSettings = @{
        Name                   = "joindomain"
        Type                   = "JsonADDomainExtension" 
        Publisher              = "Microsoft.Compute"
        typeHandlerVersion     = "1.3"
        SettingString          = '{
            "name": "'+ $($Domain) + '",
            "ouPath": "'+ $($OuPath) + '",
            "user": "'+ $($DomainAdminUsername) + '",
            "restart": "'+ $true + '",
            "options": 3
        }'
        ProtectedSettingString = '{
            "password":"' + $($DomainAdminPassword) + '"}'
        VMName                 = $VmName
        ResourceGroupName      = $ResourceGroup
        location               = $Location
    }
    Set-AzVMExtension @domainJoinSettings | Out-Null

    Write-Output "[${VmName}] : Running Post Deploy Scripts (agent install)"
    Set-AzVMCustomScriptExtension `
        -ResourceGroupName $ResourceGroup `
        -VMName $VmName `
        -Location $Location `
        -Name "PostDeployScript" `
        -FileUri "https://avdtibostorage.blob.core.windows.net/public/PostDeployScript.ps1" `
        -Run "PostDeployScript.ps1 -FileshareLocation $FileshareLocation -HostpoolToken $RegistrationToken" `
        -TypeHandlerVersion "1.10" | Out-Null
} -ThrottleLimit 10

Write-Host "[SUCCES]   : " -ForegroundColor Green -NoNewline; Write-Host "VM(s) deployed succesfully!"
Write-Host "Deployment took $([Math]::Round((new-timespan -start $startTime -End $(Get-Date)).totalMinutes,2)) minutes"