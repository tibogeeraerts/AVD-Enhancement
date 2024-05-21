param (
    [Parameter(Mandatory = $true)][string]$ResourceGroup,
    [Parameter(Mandatory = $true)][string]$Location,
    [Parameter(Mandatory = $true)][string]$HostpoolName,
    [Parameter(Mandatory = $true)][string]$KvName,
    [Parameter(Mandatory = $true)][string]$LocalAdminUsernameKVSecret,
    [Parameter(Mandatory = $true)][string]$LocalAdminPasswordKVSecret,
    [Parameter(Mandatory = $true)][string]$DomainAdminUsernameKVSecret,
    [Parameter(Mandatory = $true)][string]$DomainAdminPasswordKVSecret,
    [Parameter(Mandatory = $true)][string]$OuPath,
    [Parameter(Mandatory = $true)][string]$FileshareLocation,
    [Parameter(Mandatory = $true)][string]$SessionHostName
)

###################################################
# Tags used by script                             #
###################################################
# AIR-CheckForAnnualUpdate: true/false
# AIR-ExcludeFromUpdate:    true/false
# AIR-ForceLogoffUsers:     true/false
# AIR-ImageStatus           up-to-date/out-of-date
# AIR-ImageDefinition:      example-avd\1.0.0
####################################################



# Connect to Azure
Connect-AzAccount -Identity



################
# START SCRIPT #
################
try {
    # Fetching credentials
    Write-Output "Getting credentials from $KvName."
    $LocalAdminUsername = Get-AzKeyVaultSecret -VaultName $KvName -Name $LocalAdminUsernameKVSecret -AsPlainText
    $LocalAdminPassword = Get-AzKeyVaultSecret -VaultName $KvName -Name $LocalAdminPasswordKVSecret -AsPlainText | ConvertTo-SecureString -Force -AsPlainText
    [pscredential]$LocalCredentials = New-Object System.Management.Automation.PSCredential ($LocalAdminUsername, $LocalAdminPassword)
    $DomainAdminUsername = Get-AzKeyVaultSecret -VaultName $KvName -Name $DomainAdminUsernameKVSecret -AsPlainText
    $DomainAdminPassword = Get-AzKeyVaultSecret -VaultName $KvName -Name $DomainAdminPasswordKVSecret -AsPlainText
    $Domain = $DomainAdminUsername.Split('@')[1]

    # Calculating extra variable values
    $VmName = $SessionHostName.Split('.')[0]
    $HostIsUpToDate = $true
    $HostIsEmpty = $false

    # Getting hostpool token
    Write-Output "Getting registration token."
    $RegistrationToken = (Get-AzWvdHostPoolRegistrationToken -HostPoolName $HostpoolName -resourceGroupName $ResourceGroup).Token
    if ($RegistrationToken -eq "" -or $null -eq $RegistrationToken) {
        Write-Output "Generating new registration token..."
        $RegistrationToken = (New-AzWvdRegistrationInfo -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -ExpirationTime $((get-date).ToUniversalTime().AddDays(1).ToString('yyyy-MM-ddTHH:mm:ss.fffffffZ'))).Token
    }

    # Get VM information
    Write-Output "CHECKING: $VmName"
    $VmInfo = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VmName

    if (!($VmInfo.Tags['AIR-DateCreated'])) {
        #Tag does not exist yet so setting it to today
        Update-AzTag -Tag @{'AIR-DateCreated' = "$((Get-Date).ToString('dd/MM/yyyy'))"} -ResourceId $VmInfo.Id -Operation Merge | Out-Null
    }

    # Get VM image reference
    $VmImageReference = $VmInfo.StorageProfile.ImageReference

    # Check if VM is using a marketplace image
    if (-not $VmImageReference.Id) {
        Write-Output "$VmName is using a marketplace image."
        $MarketplaceImage = $true

        # Check if image is using latest anual update if paramater is true
        $CheckAnnualUpdate = $VmInfo.Tags['AIR-CheckAnnualUpdate']
        if ($CheckAnnualUpdate -eq 'true') {
            Write-Output "AIR-CheckAnnualUpdate tag is true so checking for new yearly image."
            $VmImageSku = $VmImageReference.Sku

            # Get all available Windows Skus
            $AvailableWindowsSkus = Get-AzVMImageSku -Location $Location -PublisherName $VmImageReference.Publisher -Offer $VmImageReference.Offer |
                Where-Object { $_.Skus -like "*avd*" } |
                Select-Object Skus
            $AvailableWindowsSkus = $AvailableWindowsSkus.Skus
            $LatestWindowsSku = $AvailableWindowsSkus | Sort-Object -Descending | Select-Object -First 1
            $VmImagePublisher = $VmImageReference.Publisher
            $VmImageOffer = $VmImageReference.Offer
            Write-Output "Determined that latest available Windows Sku is: $LatestWindowsSku"
            Write-Output "Current Windows Sku is : $VmImageSku"

            # Check if VM is using the latest available Windows marketplace image
            if ($VmImageSku -ne $LatestWindowsSku) {
                $VmImageYear = $VmImageSku.Split('-')[1]
                $WindowsImageYear = $LatestWindowsSku.Split('-')[1]
                if ($VmImageYear -lt $WindowsImageYear) {
                    Write-Output "$VmName is not using the latest available image"
                    Update-AzTag -Tag @{'AIR-ImageStatus' = 'out-of-date'} -ResourceId $VmInfo.Id -Operation Merge | Out-Null
                    Update-AzTag -Tag @{'AIR-ImageDefinition' = $VmImageSku} -ResourceId $VmInfo.Id -Operation Merge | Out-Null
                    $VmOutOfDate = $true
                    Write-Output "$VmName is not using the latest available yearly image"
                }
            } else {
                $VmOutOfDate = $false
                Write-Output "$VmName is already using the latest available yearly image"
            }
        }

        # Check if VM is older than 45 days if not already out-of-date
        Write-Output "Checking if $VmName is older than 45 days."
            
        # Check if the VM is older than 45 days
        $CurrentDate = Get-Date
        $CreationDate = [DateTime]::ParseExact($VmInfo.Tags['AIR-DateCreated'], "dd/MM/yyyy", $null)
        $DaysSinceCreation = ($CurrentDate - $CreationDate).Days

        if ($DaysSinceCreation -gt 45) {
            Write-Output "$VmName is more than 45 days old"
            Update-AzTag -Tag @{'AIR-ImageStatus' = 'out-of-date'} -ResourceId $VmInfo.Id -Operation Merge | Out-Null
            $HostIsUpToDate = $false
        }
        else {
            Write-Output "$VmName is less than 45 days old"
            Update-AzTag -Tag @{'AIR-ImageStatus' = 'up-to-date'} -ResourceId $VmInfo.Id -Operation Merge | Out-Null
        }
    } else {            
        Write-Output "$VmName is using a custom image."
        $MarketplaceImage = $false

        # Get the custom image info
        $VmResourceId = $VmInfo.Id

        # Get custom image info
        Write-Output "Getting current custom image versions."
        $CustomImageVersions = Get-AzGalleryImageVersion -ResourceGroupName $VmImageReference.Id.Split('/')[-9] -GalleryName $VmImageReference.Id.Split('/')[-5] -GalleryImageDefinitionName $VmImageReference.Id.Split('/')[-3]

        # Determine latest available custom image
        Write-Output "Checking if image is latest and provisoned succesfullly."
        $LatestCustomImageVersion = [version]"0.0.0"
        foreach ($CustomImageVersion in $CustomImageVersions) {
            $CustomImageExcludeFromLatest = $CustomImageVersion.PublishingProfile.ExcludeFromLatest
            $CustomImageImageProvisioningState = $CustomImageVersion.ProvisioningState
            if (-not $CustomImageExcludeFromLatest -and $CustomImageImageProvisioningState -eq 'Succeeded') {
                $CustomImageVersionNumber = [version]$CustomImageVersion.Name
                if ($CustomImageVersionNumber -gt $LatestCustomImageVersion) {
                    $LatestCustomImageVersion = $CustomImageVersionNumber
                    $LatestCustomImageVersionId = $CustomImageVersion.Id
                }
            }
        }
        Write-Output "Latest available custom image version is: $LatestCustomImageVersion"

        # Define custom image definition
        $CurrentCustomImageName = $VmImageReference.Id.Split('/')[-3]
        [version]$currentCustomImageVersion = $VmImageReference.Id.Split('/')[-1]
        $CurrentCustomImageDefinition = "$CurrentCustomImageName\$currentCustomImageVersion"
        Update-AzTag -Tag @{'AIR-ImageDefinition' = $CurrentCustomImageDefinition} -ResourceId $VmResourceId -Operation Merge | Out-Null
        Write-Output "Current custom image version is: $currentCustomImageVersion"

        # Check if the VM is using the latest available custom image
        if ($currentCustomImageVersion -notmatch $LatestCustomImageVersion) {
            Write-Output "$VmName is out-of-date!"
            Update-AzTag -Tag @{'AIR-ImageStatus' = 'out-of-date'} -ResourceId $VmResourceId -Operation Merge | Out-Null
            $HostIsUpToDate = $false
        } else {
            Write-Output "$VmName is up-to-date!"
            Update-AzTag -Tag @{'AIR-ImageStatus' = 'up-to-date'} -ResourceId $VmResourceId -Operation Merge | Out-Null
        }
    }

    Write-Output "Checking if $VmName is excluded from updates."
    $ExcludeVmFromUpdate = $VmInfo.Tags['AIR-ExcludeFromUpdate']
    if ($ExcludeVmFromUpdate -ne 'true') {
        # Check for AIR-ForceLogoffUsers tag if true or not, if true force logoff users
        Write-Output "Checking if $VmName has to forcefully logoff users."
        $ForceLogoffUsers = $VmInfo.Tags['AIR-ForceLogoffUsers']
        if ($ForceLogoffUsers -eq 'true') {
            # Get all user sessions on the host
            Write-Output "active sessions on $VmName will be terminated."
            $UserSessions = Get-AzWvdUserSession -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -SessionHostName $SessionHostName
            # Message the user he will be logged
            foreach ($UserSession in $UserSessions) {
                Update-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -Name $SessionHostName -AllowNewSession:$false | Out-Null
                Write-Output "Forcing logoff users on $VmName"
                Remove-AzWvdUserSession -HostPoolName $HostpoolName -ResourceGroupName $ResourceGroup -SessionHostName $SessionHostName -Id $UserSession.Id.Split('/')[-1]
            }
            Write-Information "Waiting 10 seconds for active sessions to dissapear."
            Start-Sleep -Seconds 10
            Write-Output "10 seconds wait is done."
        }

        # Check if host has open session when host is out of date
        if ($HostIsUpToDate -eq $false) {
            # Check sessions and set tag
            Write-Output "Checking if $VmName has open sessions."
            $HasOpenSessions = Get-AzWvdUserSession -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -SessionHostName $SessionHostName
            if ($HasOpenSessions) {
                # Possibility to message user here to leave the VM
                $HostIsEmpty = $false
                Write-Output "$VmName has open sessions!"
            } else {
                Update-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -Name $SessionHostName -AllowNewSession:$false | Out-Null
                $HostIsEmpty = $true
                Write-Output "$VmName has no open sessions!"
            }
        }

        # Update VM info
        $VmInfo = Get-AzVM -ResourceGroupName $ResourceGroup -Name $VmName
        $OsDisk = Get-AzDisk -ResourceGroupName $ResourceGroup -DiskName $VmInfo.StorageProfile.OsDisk.Name
        $VmTags = $VmInfo.Tags

        Write-Output "Checking if $VmName is out-of-date and host is empty."
        if ($VmTags['AIR-ImageStatus'] -eq 'out-of-date' -and $HostIsEmpty) {
            Write-Output "UPDATING: $VmName"

            # Update NIC config so it won't auto delete
            write-output "Updating NIC so it won't auto-delete"
            $VmInfo.NetworkProfile.NetworkInterfaces[0].DeleteOption = 'Detach'
            $VMInfo | Update-AzVM | Out-Null

            # Delete existing host
            Write-Output "Removing Host from Host Pool"
            Remove-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName -Name $SessionHostName -Force | Out-Null
            
            Write-Output "Deleting Virtual Machine"
            Remove-AzVM -ResourceGroupName $ResourceGroup -Name $VmName -Force | Out-Null

            # Delete disk of VM
            Write-Output "Deleting Disk"
            Remove-AzDisk -ResourceGroupName $ResourceGroup -DiskName $OsDisk.Name -Force | Out-Null

            # Get NIC ID of VM
            $VmNicId = $VmInfo.NetworkProfile.NetworkInterfaces.Id

            # Set all needed variables from the existing VM
            $VmSize = $VmInfo.HardwareProfile.VmSize
            $VmSecurityType = $VmInfo.SecurityProfile.SecurityType
            if ($null -eq $VmSecurityType) {
                $VmSecurityType = "Standard"
            }
            
            $Disk     = Get-azDisk | Where-Object {$_.Id -eq  $LastVMInfo.StorageProfile.OsDisk.ManagedDisk.Id }
            $VmDiskSize = $Disk.DiskSizeGB
            $VmDiskType = $Disk.Sku.Name

            # Create new AzVM object
            $NewVm = New-AzVMConfig -VMName $VmName -VMSize $VmSize -SecurityType $VmSecurityType
            $NewVm = Set-AzVMOperatingSystem -VM $NewVm -Windows -ComputerName $VmName -Credential $LocalCredentials -ProvisionVMAgent -EnableAutoUpdate
            $NewVm = Add-AzVMNetworkInterface -VM $NewVm -Id $VmNicId
            $NewVm = Set-AzVMOSDisk -VM $NewVm -Name "$VmName-osdisk" -CreateOption "FromImage" -Windows -DiskSizeInGB $VmDiskSize -StorageAccountType $VmDiskType -DeleteOption "delete"
            $NewVm = Set-AzVMBootDiagnostic -VM $NewVm -Disable

            # Set new image
            if ($MarketplaceImage -eq $true) {
                $NewVm = Set-AzVMSourceImage -VM $NewVm -PublisherName $VmImagePublisher -Offer $VmImageOffer -Skus $LatestWindowsSku -Version "latest"
                $ImageDefinitionTag = "$LatestWindowsSku\latest"
            } else {
                $NewVm = Set-AzVMSourceImage -VM $NewVm -Id $LatestCustomImageVersionId
                $LatestCustomImageName = $LatestCustomImageVersionId.Split('/')[-3]
                $LatestCustomImageVersion = $LatestCustomImageVersionId.Split('/')[-1]
                $ImageDefinitionTag = "$LatestCustomImageName\$LatestCustomImageVersion"
            }

            $VmTags['AIR-ExcludeFromUpdate'] = 'true'
            $VmTags['AIR-ImageStatus'] = 'up-to-date'
            $VmTags['AIR-ImageDefinition'] = $ImageDefinitionTag
            $VmTags['AIR-ForceLogoffUsers'] = 'false'
            $VmTags['AIR-DateCreated'] = (Get-Date).ToString('dd/MM/yyyy')

            # Create new VM
            Write-Output "Deploying VM"
            New-AzVM -ResourceGroupName $ResourceGroup -Location $Location -VM $NewVm -DisableBginfoExtension -licenseType "Windows_Client" -Tag $VmTags

            Write-Output "Running Domain Join"
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
                VMName                 = $NewVm.Name
                ResourceGroupName      = $ResourceGroup
                location               = $Location
            }
            Set-AzVMExtension @domainJoinSettings | Out-Null

            Write-Output "Running Post Deploy Scripts (agent install)"
            Set-AzVMCustomScriptExtension `
                -ResourceGroupName $ResourceGroup `
                -VMName $NewVm.Name `
                -Location $Location `
                -Name "PostDeployScript" `
                -FileUri "https://avdtibostorage.blob.core.windows.net/public/PostDeployScript.ps1" `
                -Run "PostDeployScript.ps1 -FileshareLocation $FileshareLocation -HostpoolToken $RegistrationToken" `
                -TypeHandlerVersion "1.10" `
                -NoWait | Out-Null

            Write-Output "SUCCES: $VmName has been updated."
            $CurrentDay = Get-Date -Format "dd/MM/yyyy"
            $CurrentHour = Get-Date -Format "HH:mm:ss"
            Write-Output "LOG;UPDATED;$VmName;$CurrentDay;$CurrentHour;$ImageDefinitionTag"
        } else {
            Write-Output "SKIPPING: $VmName"

            $ImageDefinitionTag = $VmTags['AIR-ImageDefinition']

            $CurrentDay = Get-Date -Format "dd/MM/yyyy"
            $CurrentHour = Get-Date -Format "HH:mm:ss"
            Write-Output "LOG;SKIP;$VmName;$CurrentDay;$CurrentHour;$ImageDefinitionTag"
        }
    } else {
        Write-Output "SKIPPING: $VmName"

        $ImageDefinitionTag = (Get-AzVM -ResourceGroupName $ResourceGroup -Name $VmName).Tags['AIR-ImageDefinition']
        $ImageDefinitionTag = $ImageDefinitionTag ?? 'unknown'

        $CurrentDay = Get-Date -Format "dd/MM/yyyy"
        $CurrentHour = Get-Date -Format "HH:mm:ss"
        Write-Output "LOG;SKIP;$VmName;$CurrentDay;$CurrentHour;$ImageDefinitionTag"
    }
} catch {
    throw $_
}

if ($error) {
    Write-Error "Error: $($Error[0].message)"
    throw $_
}