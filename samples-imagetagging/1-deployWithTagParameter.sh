resourceGroupName=rg-aca-tests
environmentName=caetest
appName=acatest
location='West Europe'

# Get the running revision image tag
image=$(az containerapp revision list --name $appName --resource-group $resourceGroupName \
        --query "[0].properties.template.containers[0].image" --output tsv 2>/dev/null)
tag=${image##*:}

echo Found revision running with image $image and tag $tag

az deployment group create \
    --resource-group $resourceGroupName \
    --template-file 1-with-tag-parameter.bicep \
    --parameters environmentName="$environmentName" appName="$appName" location="$location" tag="$tag"
