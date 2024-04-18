param(
    [Parameter(Mandatory = $true)][string]$FileshareLocation,
    [Parameter(Mandatory = $true)][string]$HostpoolToken
)

# Install RSAT GPO tools
Write-Output "Installing RSAT Tools - Group Policy"
Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat.GroupPolicy*" -AND $_.State -eq "NotPresent"} | Add-WindowsCapability -Online

# Install RSAT AD tools
Write-Output "Installing RSAT Tools - AD"
Get-WindowsCapability -Online | Where-Object {$_.Name -like "Rsat.ActiveDirectory*" -AND $_.State -eq "NotPresent"} | Add-WindowsCapability -Online

# Define the path to the FSLogix Profiles registry key
$fsLogixProfilesPath = "HKLM:\SOFTWARE\FSLogix\Profiles"

# Set the registry keys
Set-ItemProperty -Path $fsLogixProfilesPath -Name "ConcurrentUserSessions" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "DeleteLocalProfileWhenVHDShouldApply" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "Enabled" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "FlipFlopProfileDirectoryName" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "InstallAppxPackages" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "IsDynamic" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "KeepLocalDir" -Value 0 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "LockedRetryCount" -Value 30 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "LockedRetryInterval" -Value 2 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "ProfileType" -Value 0 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "ReAttachIntervalSeconds" -Value 2 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "ReAttachRetryCount" -Value 30 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "RedirXMLSourcefolder" -Value $FileshareLocation -Type String
Set-ItemProperty -Path $fsLogixProfilesPath -Name "RemoveOrphanedOSTFilesOnLogoff" -Value 1 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "SizeInMBs" -Value 30000 -Type DWord
Set-ItemProperty -Path $fsLogixProfilesPath -Name "VHDLocations" -Value $FileshareLocation -Type String
Set-ItemProperty -Path $fsLogixProfilesPath -Name "VolumeType" -Value "VHDX" -Type String

$uris = @(
    "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv"
    "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH"
)

$installers = @()
foreach ($uri in $uris) {
    $download = Invoke-WebRequest -Uri $uri -UseBasicParsing

    $fileName = ($download.Headers.'Content-Disposition').Split('=')[1].Replace('"','')
    $output = [System.IO.FileStream]::new("$pwd\$fileName", [System.IO.FileMode]::Create)
    $output.write($download.Content, 0, $download.RawContentLength)
    $output.close()
    $installers += $output.Name
}

foreach ($installer in $installers) {
    Unblock-File -Path "$installer"
}

$AgentInstaller = $installers[0].Split("\")[-1]
$BootLoaderInstaller = $installers[1].Split("\")[-1]

Write-Host $BootLoaderInstaller

msiexec /i $AgentInstaller REGISTRATIONTOKEN=$HostpoolToken

msiexec /i $BootLoaderInstaller