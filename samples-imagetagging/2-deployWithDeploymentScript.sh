resourceGroupName=rg-aca-tests
environmentName=caetest
appName=acatest
location='West Europe'

az deployment group create \
    --resource-group $resourceGroupName \
    --template-file 2-with-deployment-script.bicep \
    --parameters environmentName="$environmentName" appName="$appName" location="$location"
