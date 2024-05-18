param (
    [Parameter(Mandatory = $false)][string]$ResourceGroup = "rg-xxx",
    [Parameter(Mandatory = $false)][string]$HostpoolName = "vdpool-xxx",
    [Parameter(Mandatory = $false)][string]$KvName = "kv-xxx",
    [Parameter(Mandatory = $false)][string]$Location = "westeurope",
    [Parameter(Mandatory = $false)][string]$LocalAdminUsernameKVSecret = "localadmin-username",
    [Parameter(Mandatory = $false)][string]$LocalAdminPasswordKVSecret = "localadmin-password",
    [Parameter(Mandatory = $false)][string]$DomainAdminUsernameKVSecret = "domainadmin-username",
    [Parameter(Mandatory = $false)][string]$DomainAdminPasswordKVSecret = "domainadmin-password",
    [Parameter(Mandatory = $false)][string]$OuPath = "OU=xxx,DC=domain,DC=com",
    [Parameter(Mandatory = $false)][string]$FileshareLocation = "\\xxx.file.core.windows.net\xxx"
)

# Connect to Azure
Connect-AzAccount -Identity

################
# START SCRIPT #
################
# Get Session Hosts from hostpool
Write-Output "Getting all session hosts from $HostpoolName."
$CurrentSessionHosts = Get-AzWvdSessionHost -ResourceGroupName $ResourceGroup -HostPoolName $HostpoolName

# Check for existing hosts
if ($CurrentSessionHosts.Count -eq 0) {
    Write-Warning "No existing hosts found"
    exit
} else {
    $CurrentVmNames = @()
    foreach ($SessionHost in $CurrentSessionHosts) {
        $CurrentVmNames += $SessionHost.Name.Split('/')[1].Split('.')[0]
    }

    Write-Output "Found session hosts: $CurrentVmNames"
}

# Loop over all session hosts
Write-Output "Starting parallel jobs for each host."
$CurrentSessionHosts | ForEach-Object -Parallel {
    # Defining all parameters
    $Parameters = @{
        ResourceGroup = $using:ResourceGroup
        Location = $using:Location
        HostpoolName = $using:HostpoolName
        KvName = $using:KvName
        LocalAdminUsernameKVSecret = $using:LocalAdminUsernameKVSecret
        LocalAdminPasswordKVSecret = $using:LocalAdminPasswordKVSecret
        DomainAdminUsernameKVSecret = $using:DomainAdminUsernameKVSecret
        DomainAdminPasswordKVSecret = $using:DomainAdminPasswordKVSecret
        OuPath = $using:OuPath
        FileshareLocation = $using:FileshareLocation
        SessionHostName = $_.Name.Split('/')[1]
    }

    # Starting a runbook for each found session host
    Start-AzAutomationRunbook -AutomationAccountName "aa-xxx" `
    -ResourceGroupName "rg-xxx" `
    -Name "AIR-VM-runbook" `
    -Parameters $Parameters
}

if ($error) {
    throw "Error occured while checking $VmName"
}