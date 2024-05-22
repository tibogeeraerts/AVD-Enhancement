#region Functions
function CheckVmSetup {
    # Ask user if VM size is correct
    Write-Host ""
    Write-Host "The following VM setup is selected:" -ForegroundColor Cyan
    Write-Host "VM Size : " -ForegroundColor Yellow -NoNewline; Write-Host $VmSize -ForegroundColor White
    Write-Host "Domain  : " -ForegroundColor Yellow -NoNewline; Write-Host $Domain -ForegroundColor White
    Write-Host "OU Path : " -ForegroundColor Yellow -NoNewline; Write-Host $OuPath -ForegroundColor White
    Write-Host "Subnet  : " -ForegroundColor Yellow -NoNewline; Write-Host $SubnetName -ForegroundColor White
    Write-Host "VM name : " -ForegroundColor Yellow -NoNewline; Write-Host "$Prefix" -ForegroundColor White
    $ApproveText = Read-Host "Approve? (y/n)"
    if ($ApproveText -eq 'n') { $ApproveVM = $false } else { $ApproveVM = $true }

    return $ApproveVM
}

function CheckImageSetup {
    # Ask user if VM image is correct
    Write-Host ""
    Write-Host "The following VM image is selected:" -ForegroundColor Cyan
    Write-Host "Image   : " -ForegroundColor Yellow -NoNewline; Write-Host $VmImageSku -ForegroundColor White
    Write-Host "Version : " -ForegroundColor Yellow -NoNewline; Write-Host $VmImageVersion -ForegroundColor White
    Write-Host "Security: " -ForegroundColor Yellow -NoNewline; Write-Host $SecurityType -ForegroundColor White
    $ApproveText = Read-Host "Approve? (y/n)"
    if ($ApproveText -eq 'n') { $ApproveImage = $false } else { $ApproveImage = $true }

    return $ApproveImage
}

function CheckDeploy {
    # Ask user if full setup is correct
    Write-Host ""
    Write-Host "Deploying VM(s) with the following settings:" -ForegroundColor Cyan
    Write-Host "VM Size : " -ForegroundColor Yellow -NoNewline; Write-Host $VmSize -ForegroundColor White
    Write-Host "Domain  : " -ForegroundColor Yellow -NoNewline; Write-Host $Domain -ForegroundColor White
    Write-Host "OU Path : " -ForegroundColor Yellow -NoNewline; Write-Host $OuPath -ForegroundColor White
    Write-Host "Subnet  : " -ForegroundColor Yellow -NoNewline; Write-Host $SubnetName -ForegroundColor White
    Write-Host "Image   : " -ForegroundColor Yellow -NoNewline; Write-Host $VmImageSku -ForegroundColor White
    Write-Host "Version : " -ForegroundColor Yellow -NoNewline; Write-Host $VmImageVersion -ForegroundColor White
    Write-Host "Security: " -ForegroundColor Yellow -NoNewline; Write-Host $SecurityType -ForegroundColor White
    Write-Host ""
    Write-Host "Hostpool: " -ForegroundColor Blue -NoNewline; Write-Host $HostPoolName -ForegroundColor White
    Write-Host "VMs     : " -ForegroundColor Blue -NoNewline; Write-Host $AmountOfVMs -ForegroundColor White
    Write-Host "VM name : " -ForegroundColor Blue -NoNewline; Write-Host $Prefix -ForegroundColor White
    $ApproveText = Read-Host "Approve? (y/n)"
    if ($ApproveText -eq 'y') { $ApproveDeploy = $true } else { $ApproveDeploy = $false }

    return $ApproveDeploy
}
#endregion

#region Mandatory parameters
$subscriptionId = "xxxx-xxx-xxx-xxxx"
$Location = "westeurope"
$KvName = "kv-xxx"

$ApproveVM = $false
$ApproveImage = $false
$ApproveDeploy = $false

#endregion
Clear-Host

$startTime = Get-Date
Connect-AzAccount -SubscriptionId $subscriptionId | Out-Null

#region Optional parameters
# These hardcoded parameters are used when no existing values are found in the current hostpools/session hosts or when deploying to an empty hostpool.

$Prefix = "vm-xxx"
$HighestVmNumber = 0
$VmSize = "Standard_D2s_v5"
$SecurityType = "TrustedLaunch"
$LocalAdminUsername = Get-AzKeyVaultSecret -VaultName $kvName -Name "localadmin-username" -AsPlainText
$LocalAdminPassword = Get-AzKeyVaultSecret -VaultName $kvName -Name "localadmin-password" -AsPlainText | ConvertTo-SecureString -Force -AsPlainText
[pscredential]$LocalCredentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $LocalAdminPassword)
$DomainAdminUsername = Get-AzKeyVaultSecret -VaultName $kvName -Name "domainadmin-username" -AsPlainText
$DomainAdminPassword = Get-AzKeyVaultSecret -VaultName $kvName -Name "domainadmin-password" -AsPlainText
$Domain = $DomainAdminUsername.Split('@')[1]
$OuPath = "OU=xxx,DC=domain,DC=com"
$DiskSize = 128
$DiskType = "StandardSSD_LRS"
$SubnetId = "/subscriptions/xxx/resourceGroups/rg-xxx/providers/Microsoft.Network/virtualNetworks/vnet-xxx/subnets/snet-xxx"
$SubnetName = $SubnetId.Split("/")[-1]
$MarketPlaceImage = $false
$CustomImageId = "/subscriptions/xxx/resourceGroups/rg-xxx/providers/Microsoft.Compute/galleries/gal-xxx/images/xxx/versions/1.0.0"
$FileshareLocation = "\\xxx.file.core.windows.net\xxx"

if ($MarketPlaceImage) {
    $VmImagePublisher = "microsoftwindowsdesktop"
    $VmImageOffer = "office-365"
    $VmImageSku = "win11-23h2-avd-m365"
    $VmImageVersion = "latest"
}
else {
    $imageInfo = Get-azGalleryImageDefinition `
        -ResourceGroupName $customImageId.split('/')[4] `
        -GalleryName $customImageId.split('/')[8] `
        -Name $customImageId.split('/')[10]

    $VmImagePublisher = $imageInfo.Identifier.Publisher
    $VmImageOffer = $imageInfo.Identifier.Offer
    $VmImageSku = $imageInfo.Identifier.Sku
    $VmImageVersion = $customImageId.split('/')[-1]
}
#endregion

################
# START SCRIPT #
################

#region Get existing Host Pools
$AvailableHostPools = Get-AzWvdHostPool

if ($AvailableHostPools) {
    Write-Host "I found the following Hostpools. Please select one." -ForegroundColor Cyan
    $counter = 1
    foreach ($HostPool in $AvailableHostPools) {
        Write-Host "[$counter] " -ForegroundColor Yellow -NoNewline
        Write-Host "- $($HostPool.Name)" -ForegroundColor White
        $counter++
    }
}
else {
    Write-Host "No Hostpools found. Exiting..." -ForegroundColor Red
    start-sleep -Seconds 3
    exit
}

do {
    $HostPoolSelectionIndex = Read-Host "Enter the number of the HostPool you want to select"
} while ($HostPoolSelectionIndex -notmatch '^\d+$' -or $HostPoolSelectionIndex -lt 1 -or $HostPoolSelectionIndex -gt $AvailableHostPools.Count)
[int]$HostPoolSelectionIndex = $HostPoolSelectionIndex
$SelectedHostPool = $AvailableHostPools[$HostPoolSelectionIndex - 1]
$HostPoolName = $SelectedHostPool.Name
$resourceGroup = $SelectedHostPool.Id.Split('/')[4]

#endregion

# SELECT AMOUNT OF VMS
Write-Host ""
Write-Host "Deploy how many session hosts?" -ForegroundColor Cyan
do {
    $AmountOfVMs = Read-Host "Enter the amount of VMs you want to deploy"
} while ($AmountOfVMs -notmatch '^\d+$' -or $AmountOfVMs -lt 1)
[int]$AmountOfVMs = $AmountOfVMs

# CHECK for existing VMs
# Get VM Image info
$CurrentVMNames = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostPoolName
if ($CurrentVMNames.Count -ne 0) {
    # Set basic VM info
    $LastVMName = $CurrentVMNames[-1].Name.Split('/')[1].Split('.')[0]
    $LastVMInfo = Get-AzVM -ResourceGroupName $ResourceGroup -Name $LastVMName

    if ($LastVMName -match '-') {
        # VMName contains hyphens so cutting of prefix before last section of the split
        $lastSection = $LastVMName.split('-')[-1]
        $Prefix = ($LastVMName.split('-') -join '-').replace("-$lastSection", "")
    }
    else {
        # VMName contains no hyphens. Assume last numbers to be the VM number
        $regex = '[0-9]+$'
        $Prefix = $LastVMName -replace $regex, ''
    }

    $VmSize = $LastVMInfo.HardwareProfile.VmSize
    $Domain = $CurrentVMNames[-1].Name.Split('/')[1].Split('.', 2)[1]
    
    # Get OU if available
    $JsonADDomainExtension = $LastVMInfo.Extensions | Where-Object { $_.Publisher -eq "Microsoft.Compute" -and $_.VirtualMachineExtensionType -eq "JsonADDomainExtension" }
    if ([string]$JsonADDomainExtension.Settings.ouPath) {
        $OuPath = [string]$JsonADDomainExtension.Settings.ouPath
    }
    
    # Set disk variables
    $DiskName = $LastVMInfo.StorageProfile.OsDisk.Name
    $Disk     = Get-azDisk | Where-Object {$_.Id -eq  $LastVMInfo.StorageProfile.OsDisk.ManagedDisk.Id }
    $DiskSize = $Disk.DiskSizeGB
    $DiskType = $Disk.Sku.Name

    # Set nic variables
    $NicName    = $LastVMInfo.NetworkProfile.NetworkInterfaces[0].Id.Split("/")[-1]
    $SubnetId   = Get-AzNetworkInterface -ResourceGroupName $ResourceGroup -Name $NicName | Select-Object -ExpandProperty IpConfigurations | Select-Object -ExpandProperty Subnet | Select-Object -ExpandProperty Id
    $SubnetName = $SubnetId.Split('/')[-1]

    # Get highest VM number in pool
    foreach ($SessionHostName in $CurrentVMNames) {
        $VmName = $SessionHostName.Name.Split('/')[1]
        $SessionHostNumber = [int]$VmName.Split('-')[-1].Split('.')[0]
        if ($SessionHostNumber -gt $HighestVmNumber) {
            $HighestVmNumber = $SessionHostNumber
        }
    }

    # Set VM Image info
    if ($LastVMInfo.StorageProfile.ImageReference.Id) {
        $MarketPlaceImage = $false
        $CustomImageId    = $LastVMInfo.StorageProfile.ImageReference.Id
        $VmImageSku       = $LastVMInfo.StorageProfile.ImageReference.Id.Split('/')[-3]
        $VmImageVersion   = $LastVMInfo.StorageProfile.ImageReference.Id.Split('/')[-1]
    }
    else {
        $MarketPlaceImage = $true
        $VmImagePublisher = $LastVMInfo.StorageProfile.ImageReference.Publisher
        $VmImageOffer     = $LastVMInfo.StorageProfile.ImageReference.Offer
        $VmImageSku       = $LastVMInfo.StorageProfile.ImageReference.Sku
        $VmImageVersion   = $LastVMInfo.StorageProfile.ImageReference.Version
    }

    # Change security type if not Standard
    if ($LastVMInfo.SecurityProfile.SecurityType) {
        $SecurityType = $LastVMInfo.SecurityProfile.SecurityType
    }
}

$ApproveDeploy = CheckDeploy
while ($ApproveDeploy -eq $false) {
    
    $ApproveVM = CheckVmSetup
    while ($ApproveVM -eq $false) {
        Write-Host ""
        Write-Host "Changing current VM setup" -ForegroundColor Red

        # Check VM size
        Write-Host "VM Size: " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "${VmSize} correct? (y/n)"
        if ($ApproveText -eq 'n') {
            $VmSize = Read-Host "New VM size: "
        }

        # Check Domain
        Write-Host "Domain: " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "${Domain} correct? (y/n)"
        if ($ApproveText -eq 'n') {
            $Domain = Read-Host "New Domain: "
        }

        # Check OU Path
        Write-Host "OU Path: " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "${OuPath} correct? (y/n)"
        if ($ApproveText -eq 'n') {
            $OuPath = Read-Host "New OU Path: "
        }

        # Check Subnet
        Write-Host "Subnet: " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "${SubnetName} correct? (y/n)"
        if ($ApproveText -eq 'n') {
            $SubnetId = Read-Host "New Subnet ID: "
            $SubnetName = $SubnetId.Split('/')[-1]
        }

        Write-Host "VM name: " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "$Prefix correct? (y/n)"
        if ($ApproveText -eq 'n') {
            $Prefix = Read-Host "New VM name prefix: "
        }

        $ApproveVM = CheckVmSetup
    }

    $ApproveImage = CheckImageSetup
    while ($ApproveImage -eq $false) {
        Write-Host ""
        Write-Host "Changing current image setup" -ForegroundColor Red

        # Check VM Image
        Write-Host "Image  : " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "${VmImageSku}\${VmImageVersion} correct? (y/n)"
        if ($ApproveText -eq 'n') {
            Write-Host "Use custom image? (y/n): " -ForegroundColor Cyan -NoNewline
            $CustomImage = Read-Host
            if ($CustomImage -eq 'y') {
                $MarketPlaceImage = $false
                $CustomImageId = Read-Host "Enter the image ID: "
                $VmImageSku = $CustomImageId.Split('/')[-3]
                $VmImageVersion = $CustomImageId.Split('/')[-1]
            }
            else {
                $MarketPlaceImage = $true
                $MarketPlaceSkus = Get-AzVMImageSku -Location "West Europe" -PublisherName "microsoftwindowsdesktop" -Offer "office-365" | Where-Object { $_.Skus -like "*avd*" } | Select-Object Skus
                Write-Host "Please select another image:" -ForegroundColor Cyan
                $counter = 1
                foreach ($MarketPlaceSku in $MarketPlaceSkus) {
                    Write-Host " [$counter] " -ForegroundColor Yellow -NoNewline
                    Write-Host "- $($MarketPlaceSku.Skus)" -ForegroundColor White
                    $counter++
                }
                do {
                    $ImageNumber = Read-Host "Enter the number of the image you want to select: "
                } while ($ImageNumber -notmatch '^\d+$' -or $ImageNumber -lt 1)
                [int]$ImageIndex = $ImageNumber - 1
                
                $VmImagePublisher = "microsoftwindowsdesktop"
                $VmImageOffer = "office-365"
                $VmImageSku = $MarketPlaceSkus[$ImageIndex].Skus
                $VmImageVersion = "latest"
            }
        }

        # Check Security Type
        Write-Host "Security: " -ForegroundColor Yellow -NoNewline; $ApproveText = Read-Host "${SecurityType} correct? (y/n)"
        if ($ApproveText -eq 'n') {
            $SecurityTypes = @("Standard", "TrustedLaunch", "TrustedLaunchSupported")
            $counter = 1
            foreach ($SecurityType in $SecurityTypes) {
                Write-Host "[$counter] " -ForegroundColor Yellow -NoNewline
                Write-Host "- $SecurityType" -ForegroundColor White
                $counter++
            }
            do {
                $SecurityTypeNumber = Read-Host "Enter the number of the security type you want to select: "
            } while ($SecurityTypeNumber -notmatch '^\d+$' -or $SecurityTypeNumber -lt 1 -or $SecurityTypeNumber -gt 3)
            [int]$SecurityTypeIndex = $SecurityTypeNumber - 1
            $SecurityType = $SecurityTypes[$SecurityTypeIndex]
        }

        $ApproveImage = CheckImageSetup
    }

    $ApproveDeploy = CheckDeploy
}

# DEPLOY VMs
Write-Host ""
Write-Host "Deploying VMs" -ForegroundColor Green

# Get registration token
$RegistrationToken = (Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostpoolName -resourceGroupName $ResourceGroup).Token
if (!$RegistrationToken) {
    $RegistrationToken = (New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(7).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))).Token
}

# Create new VM names
$NewVmNames = @()
for ($i = 1; $i -le $AmountOfVMs; $i++) {
    $VmNumber = $HighestVmNumber + $i
    $VmName = "$Prefix-${VmNumber}"
    $NewVmNames += $VmName
}

Write-Host $NewVmNames

# Create new VMs
$NewVmNames | ForEach-Object -Parallel {
    $VmName = $_
    $ResourceGroup = $($using:ResourceGroup)
    $Location = $($using:Location)
    $HostPoolName = $($using:HostPoolName)
    $FileshareLocation = $($using:FileshareLocation)
    $RegistrationToken = $($using:RegistrationToken)
    $VmSize = $($using:VmSize)
    $MarketPlaceImage = $($using:MarketPlaceImage)
    $CustomImageId = $($using:CustomImageId)
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
    $Prefix = $($using:Prefix)

    $DiskSize = $($using:DiskSize)
    $DiskType = $($using:DiskType)

    $SubnetId = $($using:SubnetId)

    $NicName = "${VmName}-nic"
    $DiskName = "${VmName}-osdisk"

    $VM = New-AzVMConfig -VMName $VmName -VMSize $VmSize -SecurityType $SecurityType
    $NIC = New-AzNetworkInterface -Name $NicName -ResourceGroupName $ResourceGroup -Location $Location -SubnetId $SubnetId -Force

    $VM = Set-AzVMOperatingSystem -VM $VM -Windows -ComputerName $VmName -Credential $LocalCredentials -ProvisionVMAgent -EnableAutoUpdate
    $VM = Add-AzVMNetworkInterface -VM $VM -Id $NIC.Id -DeleteOption "Detach"
    $VM = Set-AzVMOSDisk -VM $VM -Name $DiskName -DiskSizeInGB $DiskSize -StorageAccountType $DiskType -CreateOption "FromImage" -Caching "ReadWrite" -DeleteOption "Detach"
    $VM = Set-AzVMBootDiagnostic -VM $VM -Disable

    # Set new image
    if ($MarketplaceImage -eq $true) {
        $VM = Set-AzVMSourceImage -VM $VM -PublisherName $VmImagePublisher -Offer $VmImageOffer -Skus $VmImageSku -Version "latest"
    }
    else {
        $VM = Set-AzVMSourceImage -VM $VM -Id $CustomImageId
    }

    New-AzVM -VM $VM -ResourceGroupName $ResourceGroup -Location $Location -DisableBginfoExtension -licenseType "Windows_Client" | Out-Null

    Write-Output "$(Get-Date) - Created $($VM.Name)"

    Start-sleep -Seconds 30
    
    # Check for StartStop tagging and disable them temporarily
    $deployedVM = Get-azVM -ResourceGroupName $ResourceGroup  -Name $VmName

    if ($deployedVM.Tags['StartStop-Enabled']) {
       # Write-Host "Temporarily disabling StartStop by setting StartStop-Enabled tag to false" -ForegroundColor Cyan  
        $tagsToChange = @{"StartStop-Enabled" = "false"; }
        Update-AzTag -ResourceId $deployedVM.id -Tag $tagsToChange -Operation Merge | Out-Null

        $disabledTag = $true
    }

    Write-Output "$(Get-Date) - Domain Joining $($VM.Name)"
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
    Set-AzVMExtension @domainJoinSettings  | Out-Null

    Write-Output "$(Get-Date) - Installing Agent $($VM.Name)"
    Set-AzVMCustomScriptExtension `
        -ResourceGroupName $ResourceGroup `
        -VMName $VmName `
        -Location $Location `
        -Name "PostDeployScript" `
        -FileUri "https://avdtibostorage.blob.core.windows.net/public/PostDeployScript.ps1" `
        -Run "PostDeployScript.ps1 -FileshareLocation $FileshareLocation -HostpoolToken $RegistrationToken" `
        -TypeHandlerVersion "1.10" `
        -NoWait | Out-Null

    if ($disabledTag) {
       # Write-Host "Re-enabling StartStop tag" -ForegroundColor Cyan  
        $tagsToChange = @{"StartStop-Enabled" = "true"; }
        Update-AzTag -ResourceId $deployedVM.id -Tag $tagsToChange -Operation Merge | Out-Null
    }

    Write-Output "$(Get-Date) - Done creating $($VM.Name)"
} -ThrottleLimit 10

Write-Host "VMs deployed" -ForegroundColor Green
Write-Host "Deployment took $([Math]::Round((new-timespan -start $startTime -End $(Get-Date)).totalMinutes,2)) minutes"