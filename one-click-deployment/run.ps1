Connect-AzAccount -tenantID 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx' -Subscription 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxx'

set-location "C:\Users\[path-to-folder]"

$resourceGroup = '[resource-group-name]'

New-AzResourceGroupDeployment -name 'AVD-setup-deployment' `
    -ResourceGroupName $resourceGroup `
    -TemplateFile .\main.bicep `
    -TemplateParameterFile .\main.parameters.json