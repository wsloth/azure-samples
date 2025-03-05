targetScope = 'resourceGroup'

param environmentName string
param appName string
param location string

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: environmentName
  location: location
  properties: {
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

// The managed identity used to run the script -- deploy this somewhere centrally
resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-aca-get-image-tag'
  location: location
}

param currentTime string = utcNow()
resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = {
  name: 'GetContainerAppImageTag-${appName}'
  location: location
  kind: 'AzurePowerShell'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    azPowerShellVersion: '9.7'
    environmentVariables: [
      {
        name: 'appName'
        value: appName
      }
      {
        name: 'resourceGroupName'
        value: resourceGroup().name
      }
    ]
    // Write-Host "Setting subscription to '$env:subscriptionId'..."
    // Set-AzContext -SubscriptionId $env:subscriptionId
    scriptContent: '''
      Write-Host "Installing Azure Container Apps Powershell module..."
      Install-Module -Name Az.App -Force
    
      Write-Host "Checking container app '$env:appName' in resource group '$env:resourceGroupName' for active revision..."
      try {
        $containerAppRevision = Get-AzContainerAppRevision -ResourceGroupName $env:resourceGroupName -ContainerAppName $env:appName
        $image = $containerAppRevision.TemplateContainer.Image
        $version = $image.Split(":")[-1]
        Write-Host "Found image: $image with tag: $version"
        $DeploymentScriptOutputs = @{}
        $DeploymentScriptOutputs['tag'] = $version
      } catch {
        Write-Host "Failed to get active revision. Error:"
        Write-Host $_
        Write-Host "No active revision found. Is this the first deployment? Using 'latest' as tag."
        $DeploymentScriptOutputs['tag'] = "latest"
      }
    '''
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H' // Keep it around for an hour after it finishes
    forceUpdateTag: currentTime // Ensures script will run every time
  }
}

output currentImageTag string = deploymentScript.properties.outputs.tag

resource containerApp 'Microsoft.App/containerApps@2024-10-02-preview' = {
  name: appName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        targetPort: 80
        external: true
      }
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:${deploymentScript.properties.outputs.tag}'
          name: 'simple-hello-world-container'
        }
      ]
    }
  }
}
