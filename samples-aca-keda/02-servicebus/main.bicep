targetScope = 'resourceGroup'

// Parameters
param location string = resourceGroup().location
param environmentName string = 'cae-keda'
param containerAppName string = 'ca-keda-httpscaling'
param dockerImageName string = 'httpscaling:latest'
param containerRegistryName string = 'acrkedascaling.azurecr.io'
param acrPullIdentityName string = 'acr-pull'
param serviceBusNamespace string = 'sb-aca-keda-demo'
param serviceBusSku string = 'Standard'
param topicName string = 'aca-keda-sample'
param subscriptionName string = 'ca-servicebusscaling-subscription'

// Service Bus Namespace
resource serviceBus 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: serviceBusNamespace
  location: location
  sku: {
    name: serviceBusSku
    tier: serviceBusSku
  }
}

// Service Bus Topic
resource topic 'Microsoft.ServiceBus/namespaces/topics@2022-10-01-preview' = {
  parent: serviceBus
  name: topicName
  properties: {
    maxSizeInMegabytes: 1024
    defaultMessageTimeToLive: 'P14D'
  }
}

// Service Bus Subscription
resource subscription 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2022-10-01-preview' = {
  parent: topic
  name: subscriptionName
  properties: {
    maxDeliveryCount: 10
    defaultMessageTimeToLive: 'P14D'
  }
}

// Container App Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' existing = {
  name: environmentName
}

// Managed Identity
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: acrPullIdentityName
}

// Role assignment for Service Bus access
resource serviceBusRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, containerApp.id, 'Azure Service Bus Data Receiver')
  properties: {
    principalId: containerApp.identity.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0') // Azure Service Bus Data Receiver
    principalType: 'ServicePrincipal'
  }
}

// Container App
resource containerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: containerAppName
  location: location
  identity: {
    type: 'SystemAssigned, UserAssigned'
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
          env: [
            {
              name: 'ServiceBus__ConnectionString'
              value: '${serviceBus.name}.servicebus.windows.net'
            }
            {
              name: 'ServiceBus__TopicName'
              value: topicName
            }
            {
              name: 'ServiceBus__SubscriptionName'
              value: subscriptionName
            }
          ]
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
            name: 'service-bus-scale-rule'
            custom: {
              type: 'azure-servicebus'
              metadata: {
                topicName: topicName
                subscriptionName: subscriptionName
                messageCount: '2'
              }
              auth: [
                {
                  triggerParameter: 'connection'
                  secretRef: 'servicebusconnection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}
