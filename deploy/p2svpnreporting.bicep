@description('Resource Location')
param resourceLocation string = resourceGroup().location

@description('function project name')
param functionProjectName string

var MGstorageAccountName = 'mg${functionProjectName}${uniqueString(resourceGroup().id)}'
var APstorageAccountName = 'ap${functionProjectName}${uniqueString(resourceGroup().id)}'
var hostingPlanName = 'apphp${functionProjectName}${uniqueString(resourceGroup().id)}'
var appInsightsName = 'appin${functionProjectName}${uniqueString(resourceGroup().id)}'
var functionAppName = 'app${functionProjectName}'
var keyVaultName = 'kv${functionProjectName}'
//Key Vault
resource r_keyVault 'Microsoft.KeyVault/vaults@2021-04-01-preview' = {
  name: keyVaultName
  location: resourceLocation
  properties: {
    tenantId: subscription().tenantId
    enabledForDeployment: true
    enableSoftDelete: true
    sku: {
      name: 'standard'
      family: 'A'
    }
    // networkAcls: {
    //   defaultAction: (networkIsolationMode == 'vNet') ? 'Deny' : 'Allow'
    //   bypass: 'AzureServices'
    // }
    accessPolicies: [
      // "tenantId": "[reference(resourceId('Microsoft.Web/sites/', variables('functionAppName')), '2020-12-01', 'Full').identity.tenantId]"
      {
        objectId: r_functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
        tenantId: subscription().tenantId
      }
    ]
  }
  resource secret 'secrets' = {
    name: 'p2svpnstatsconn'
    properties: {
      value: 'DefaultEndpointsProtocol=https;AccountName=${r_mgmntStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(r_mgmntStorageAccount.id, r_mgmntStorageAccount.apiVersion).keys[0].value}'
    }
  }
}

// storage
resource r_mgmntStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: MGstorageAccountName
  location: resourceLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  resource blobLogs 'blobServices@2021-06-01' = {
    name: 'default'
    resource blob 'containers@2021-06-01' = {
      name: 'p2svpnstats'
    }
  }
}

//app service for function
resource r_storageAccountAppService 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: APstorageAccountName
  location: resourceLocation
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
}
resource r_appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: appInsightsName
  location: resourceLocation
  kind: 'web'
  properties: {
    Application_Type: 'web'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    // circular dependency means we can't reference functionApp directly  /subscriptions/<subscriptionId>/resourceGroups/<rg-name>/providers/Microsoft.Web/sites/<appName>"
    'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${functionAppName}': 'Resource'
  }
}

resource r_hostingPlan 'Microsoft.Web/serverfarms@2021-02-01' = {
  name: hostingPlanName
  location: resourceLocation
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource r_functionApp 'Microsoft.Web/sites@2020-06-01' = {
  name: functionAppName
  location: resourceLocation
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    httpsOnly: true
    serverFarmId: r_hostingPlan.id
    clientAffinityEnabled: true
    siteConfig: {
      appSettings: [
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': r_appInsights.properties.InstrumentationKey
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${r_storageAccountAppService.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(r_storageAccountAppService.id, r_storageAccountAppService.apiVersion).keys[0].value}'
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~4'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'powershell'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${r_storageAccountAppService.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(r_storageAccountAppService.id, r_storageAccountAppService.apiVersion).keys[0].value}'
        }
        // WEBSITE_CONTENTSHARE will also be auto-generated - https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings#website_contentshare
        // WEBSITE_RUN_FROM_PACKAGE will be set to 1 by func azure functionapp publish
        {
          name: 'example tag'
          value: 'val'
        }
      ]
    }
  }

  dependsOn: []
  resource webconfig 'config@2021-02-01' = {
    name: 'web'
    properties: {
      powerShellVersion: '~7'
    }
  }
}
