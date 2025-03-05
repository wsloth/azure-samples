targetScope = 'resourceGroup'

// Parameters
param location string = resourceGroup().location
param environmentName string = 'cae-keda'
param containerRegistryName string = 'acrkedascaling.azurecr.io'
param acrPullIdentityName string = 'acr-pull'

param scalingSourceContainerAppName string = 'ca-keda-custom-scalingsource'
param scalingSourceDockerImageName string = 'custom-scalingsource:latest'

param scalableServiceContainerAppName string = 'ca-keda-custom-scalableservice'
param scalableServiceDockerImageName string = 'custom-scalableservice:latest'

// Container App Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: environmentName
}

// Managed Identity for pulling images from ACR
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: acrPullIdentityName
}

resource scalingSourceApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: scalingSourceContainerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: containerRegistryName
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${containerRegistryName}/${scalingSourceDockerImageName}'
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

resource scalableServiceApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: scalableServiceContainerAppName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: containerRegistryName
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${containerRegistryName}/${scalableServiceDockerImageName}'
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 8
        cooldownPeriod: 30
        pollingInterval: 15
        rules: [
          {
            name: 'custom-scalingsource'
            custom: {
              type: 'external'
              metadata: {
                // Point to the scaling source app
                // Port is 80 here, because the container app is listening on port 80
                // The port 8080 you see earlier file is the port the docker container is listening on, ACA jus
                // forwards incoming port 80 traffic to port 8080 on the docker container
                scalerAddress: 'http://${scalingSourceApp.properties.configuration.ingress.fqdn}:80'
              }
            }
          }
        ]
      }
    }
  }
}
