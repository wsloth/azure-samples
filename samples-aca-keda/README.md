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
export RESOURCE_GROUP_NAME=rg-aca-keda
export CONTAINER_REGISTRY_NAME=acrkedascaling.azurecr.io
export ENVIRONMENT_NAME=cae-keda
export ACR_PULL_IDENTITY_NAME='acr-pull'

# Deploying 01-http
```
Deploy the container app with the following command:

```bash
az deployment group create \
    --name httpscaling-$(date +%Y%m%d-%H%M%S) \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file ./01-http/main.bicep \
    --parameters location=$LOCATION \
        containerRegistryName=$CONTAINER_REGISTRY_NAME \
        environmentName=$ENVIRONMENT_NAME \
        acrPullIdentityName=$ACR_PULL_IDENTITY_NAME \
        containerAppName='ca-keda-httpscaling' \
        dockerImageName='httpscaling:latest'
```

You can verify the HTTP Scaling works by running a simple loadtest against the app:

```bash
hey -c 10 -z 2m https://ca-keda-httpscaling.<your-containerapp>.<region>.azurecontainerapps.io/weatherforecast
```

It should pretty much directly scale up to 5 instances and then scale down to 1 instance again after a few minutes when you stop the test.

# Deploying 02-servicebus

First, deploy the infrastructure and container app:

```bash
az deployment group create \
    --name servicebusscaling-$(date +%Y%m%d-%H%M%S) \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file ./02-servicebus/main.bicep \
    --parameters location=$LOCATION \
        containerRegistryName=$CONTAINER_REGISTRY_NAME \
        environmentName=$ENVIRONMENT_NAME \
        acrPullIdentityName=$ACR_PULL_IDENTITY_NAME \
        containerAppName='ca-keda-servicebusscaling' \
        dockerImageName='servicebusscaling:latest' \
        serviceBusNamespace='sb-aca-keda-demo'
```

You can verify the Service Bus scaling works by sending messages to the topic using the UI in the portal. The container app should scale based on the number of messages in the subscription. When the messages are processed, it will scale back down to 0.

# Deploying 03-blobstorage

First, deploy the infrastructure and container app:

```bash
az deployment group create \
    --name blobstoragescaling-$(date +%Y%m%d-%H%M%S) \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file ./03-blobstorage/main.bicep \
    --parameters location=$LOCATION \
        containerRegistryName=$CONTAINER_REGISTRY_NAME \
        environmentName=$ENVIRONMENT_NAME \
        acrPullIdentityName=$ACR_PULL_IDENTITY_NAME \
        containerAppName='ca-keda-blobstoragescaling' \
        dockerImageName='blobstoragescaling:latest' \
        storageAccountName='stacakedademo'
```

You can verify the Blob Storage scaling works by uploading files to the 'samples' container in the storage account. The container app will "process" these files and delete them afterwards. When there are no more files to process, it will scale back down to 0 after a few minutes.

# Deploying 04-cron

Deploy the container app with the following command:

```bash
az deployment group create \
    --name cronscaling-$(date +%Y%m%d-%H%M%S) \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file ./04-cron/main.bicep \
    --parameters location=$LOCATION \
        containerRegistryName=$CONTAINER_REGISTRY_NAME \
        environmentName=$ENVIRONMENT_NAME \
        acrPullIdentityName=$ACR_PULL_IDENTITY_NAME \
        containerAppName='ca-keda-cronscaling' \
        dockerImageName='cronscaling:latest'
```

This sample demonstrates scaling based on a cron schedule. The container app will:
- Scale to 1 replica during business hours (8 AM - 6 PM, Monday-Friday, Europe/Amsterdam timezone)
- Scale to 0 replicas outside of business hours
- Additionally scale up to 5 replicas if there is HTTP load (more than 2 concurrent requests)

You can verify the scheduling works by:
1. Watching the replica count change at 8 AM and 6 PM local time
2. Testing HTTP scaling during business hours using:
```bash
hey -c 10 -z 2m https://ca-keda-cronscaling.<your-containerapp>.<region>.azurecontainerapps.io/weatherforecast
```

# Deploying 05-custom

This sample demonstrates how to build and deploy custom scaling sources.
It includes deploying two services:
- A custom scaling source that generates metrics between 0 and 200
- A custom scalable service that scales based on the metrics from the scaling source

To build the custom scaling source and service, run the following commands:
- Scaling Source: `docker build --platform linux/amd64 -t custom-scalingsource:latest -f ./05-custom/Dockerfile.ScalingSource ./05-custom --no-cache`
- Scalable Service: `docker build --platform linux/amd64 -t custom-scalableservice:latest -f ./05-custom/Dockerfile.ScalableService ./05-custom --no-cache`

Deploy the infrastructure and container apps:

```bash
az deployment group create \
    --name customscaling-$(date +%Y%m%d-%H%M%S) \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file ./05-custom/main.bicep \
    --parameters location=$LOCATION \
        containerRegistryName=$CONTAINER_REGISTRY_NAME \
        environmentName=$ENVIRONMENT_NAME \
        acrPullIdentityName=$ACR_PULL_IDENTITY_NAME \
        scalingSourceContainerAppName='ca-keda-custom-scalingsource' \
        scalingSourceDockerImageName='custom-scalingsource:latest' \
        scalableServiceContainerAppName='ca-keda-custom-scalableservice' \
        scalableServiceDockerImageName='custom-scalableservice:latest'
```

