# Standalone code

## Project setup
There are two powershell scripts in this directory that need to be used as powershell runbooks. These runbooks are stored in an automation account and can be ran with automatic schedules. Using this setup there is no manual action needed to update a hostpool.

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
To use the runbooks go to your Azure automation account and create a new Powershell 7.2 runbook.
Place the code from AIR-Hostpool-runbook.ps1 in the script area of this runbook.
Ensure that all default parameters in this script are set to something that is relevant for your AVD setup.

#### Variables
These are the required variables for each possible setup.

| Variable            | Value                                                          |
| --------            | -------------------------------------------------------------- |
| ResourveGroup       | The resource group where the AVD instances are stored          |
| HostpoolName        | The name of the AVD hostpool it needs to check                 |
| KvName              | Name of key vault storing all needed credentials               |
| Location            | Location of resources in Azure                                 |
| LocalAdminUserName  | Change name in query to secret name of corresponding user      |
| LocalAdminPassword  | Change name in query to secret name of corresponding password  |
| DomainAdminUsername | Change name in query to secret name of corresponding user      |
| DomainAdminPassword | Change name in query to secret name of corresponding password  |
| OuPath              | OU path where virtual machines should be placed                |
| FileshareLocation   | Location of domain joined file share to store FSLogix accounts |

After filling out the variables, publish the runbook in your automation account.

Create a new runbook that will be used to check each individual virtual machine in the hostpool.
The code for this runbook is in AIR-VM-runbook.ps1.
In this runbook, no parameters are required because they are passed by the other runbook you just created.

### Setting a schedule
After publishing both runbook in the automation account, ensure that the managed identity of this runbook has viewer rights on the image gallery where you store the custom images if you utilize this.

When automating this script, you can create a new schedule and select a prefered interval of times when this script needs to run and when it should stop running. I personally start the schedule each 4 hours, but it is fully up to you to select an interval that best suits your needs.

![automaticredeploy-schedule][image-automaticredeploy-schedule]

When the schedule is linked to your script, you are all set for the automatic updates of your hostpool.
Instructions for doing this can be found here: https://learn.microsoft.com/en-us/azure/automation/automation-manage-send-joblogs-log-analytics

Use the code in LogAnalyticsQuery.sql as the query in the logs, changing the names to the names relevant for your setup.
After letting the automation run for a certain time, the graph should get generated a little like this.

![automaticredeploy-graph][image-automaticredeploy-graph]

<!-- MARKDOWN LINKS & IMAGES -->
[image-interactivecli-nochanges]: ../images/interactivecli-nochanges.png
[image-interactivecli-changeimage]: ../images/interactivecli-changeimage.png
[image-interactivecli-changename]: ../images/interactivecli-changename.png
[image-hpool-redeploy-noparameters]: ../images/hpool-redeploy-noparameters.png
[image-hpool-redeploy-noparameters-portal]: ../images/hpool-redeploy-noparameters-portal.png
[image-hpool-redeploy-withparameters]: ../images/hpool-redeploy-withparameters.png
[image-hpool-redeploy-withparameters-portal]: ../images/hpool-redeploy-withparameters-portal.png
[image-hpool-redeploy-withparameters-vms-portal]:../images/hpool-redeploy-withparameters-vms-portal.png
[image-automaticredeploy-schedule]: ../images/automaticredeploy-schedule.png
[image-automaticredeploy-graph]: ../images/automaticredeploy-graph.png