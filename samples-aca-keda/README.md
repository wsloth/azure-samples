# Samples for ACA + KEDA

## Note: These samples are not production ready and are only meant to be used as a starting point for your own projects.

# Requirements for deploying

1. An Azure Container Registry deployed somewhere
2. A user-assigned managed identity named 'acr-pull' with AcrPull role assigned to your ACR
```
To create the user-assigned managed identity and assign ACR pull role:

1. Create identity:
az identity create -g <resource-group> -n acr-pull

2. Get identity client ID:
export IDENTITY_CLIENT_ID=$(az identity show -g <resource-group> -n acr-pull --query clientId -o tsv)

3. Get ACR resource ID: 
export ACR_REGISTRY_ID=$(az acr show -n <acr-name> -g <resource-group> --query id -o tsv)

4. Assign AcrPull role:
az role assignment create \
    --assignee $IDENTITY_CLIENT_ID \
    --role AcrPull \
    --scope $ACR_REGISTRY_ID
```
3. An existing Container App Environment where the apps are deployed to
    - The name of the environment is stored in the environment variable `$ENVIRONMENT_NAME`
4. The projects in these folders should be built and pushed to the existing ACR
    - You can use this guide to easily do this from your local machine: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-docker-cli?tabs=azure-cli
    - Make sure to build the images on the `linux/amd64` platform using a command like: `docker build --platform linux/amd64 -t httpscaling:latest .`
5. Your exact docker image repository name + tags should be specified in the commands below

Set the following environment variables:

```bash
export LOCATION=germanywestcentral
export CONTAINER_REGISTRY_NAME=acrkedascaling.azurecr.io
export ENVIRONMENT_NAME=cae-keda
export ACR_PULL_IDENTITY_NAME='acr-pull'

# Deploying 01-httpscaling
```
Deploy the container app with the following command:

```bash
az deployment group create \
    --name httpscaling-$(date +%Y%m%d-%H%M%S) \
    --resource-group rg-aca-keda \
    --template-file ./01-httpscaling/main.bicep \
    --parameters location=$LOCATION \
        containerRegistryName=$CONTAINER_REGISTRY_NAME \
        environmentName=$ENVIRONMENT_NAME \
        acrPullIdentityName=$ACR_PULL_IDENTITY_NAME \
        containerAppName='ca-keda-httpscaling' \
        dockerImageName='httpscaling:latest'
```