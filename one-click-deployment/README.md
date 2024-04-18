# One-click deployment of Arxus AVD PoC

## Project setup
This project contains the bicep code and powershell script to deploy an Azure Virtual Desktop PoC for customers without the need to interact once started. This deployment setup creates a hostpool, application group, workspace and session hosts.

### Prerequisites
There are certain Azure components that already need to be set up before the deployment can succeed. There is the need for a virtual **subnet** with access to an **Active Directory**. There needs to be a **key vault** with the credentials of the domain admin as well as for the local machine admin. Lastly, there is the need for a **storage account** with a **file share** that is joined to that same domain. All of these things can be grouped in 1 **resource group**.

#### List of prerequisites
- [ ] Resource group
- [ ] Storage account with domain joined fileshare
- [ ] Virtual network with subnet and AD connection
- [ ] Key vault with admin credentials stored

## Start the deployment
### 1. Gather all needed parameters
There is a `main.parameters.json` that contains all the needed parameters for the deployment of the PoC. These parameters should be provided by the customer as they setup the needed infrastructure.

These parameters can easily be gathered by the usage of the web interface found in <a href="./index.html">`index.html`</a>

### 2. Update powershell code
All the needed powershell commands are stored as 1 file <a href="./run.ps1">`run.ps1`</a>. This powershell script needs an Azure tenant ID and a subscription ID. When running the script, a browser window will pop up to verify the user and his Azure subscription. Then the location of the folder is asked to ensure the script runs in the right directory.

### 3. Run the deployment
After updating the parameters and the powershell script it is time to start the deployment. Simply run `.\run.ps1` in the root of this folder and the deployment should start.

## Flow of deployment
![Main bicep code flow][image-maincodeflow]


<!-- MARKDOWN LINKS & IMAGES -->
[image-maincodeflow]: images/main-oneclick-flow.png