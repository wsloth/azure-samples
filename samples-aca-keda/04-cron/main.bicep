targetScope = 'resourceGroup'

// Parameters
param location string = resourceGroup().location
param environmentName string = 'cae-keda'
param containerAppName string = 'ca-keda-cronscaling'
param dockerImageName string = 'cronscaling:latest'
param containerRegistryName string = 'acrkedascaling.azurecr.io'
param acrPullIdentityName string = 'acr-pull'

// Container App Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: environmentName
}

// Managed Identity for pulling images from ACR
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: acrPullIdentityName
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: containerAppName
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
          image: '${containerRegistryName}/${dockerImageName}'
          resources: {
            cpu: 1
            memory: '2Gi'
          }
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '2'
              }
            }
          }
          {
            name: 'cron-business-hours'
            custom: {
              type: 'cron'
              metadata: {
                timezone: 'Europe/Amsterdam'
                start: '0 8 * * 1-5' // 8 AM mon-fri
                end: '0 18 * * 1-5' // 6 PM mon-fri
                desiredReplicas: '1' // A minimum of 1 replica during business hours to prevent cold starts
              }
            }
          }
        ]
      }
    }
  }
}
