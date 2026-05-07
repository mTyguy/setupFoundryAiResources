<#
Script deploys necessary Foundry resources to create an agent that is capable of doing web searches.
Model is gpt-4.1
#>
Write-Host "Make sure you are logged into Az PowerShell first!!!" -Foregroundcolor Red

$rgGroupName = Read-Host "Enter the name of the resource group you want to create"
$location = Read-Host "Enter the region you want the resources to reside in, example: eastus"
$foundryResourceName = Read-Host "Enter the name for your Foundry resource"
$foundryDomainName = Read-Host "Enter the subdomain name you would like to use -- it most be GLOBALLY unique"
$foundryProjectName = Read-Host "Enter what you want your project name to be"

# Check if RG exists first
$rgGroupExist = az group exists --name $rgGroupName

# If group not exist, create. else say it already exists
if ($rgGroupExist -eq $false) {
  $createRgResponse = (($createRgAction = az group create --name $rgGroupName --location $location) | ConvertFrom-Json)

  if ($createRgResponse.properties.provisioningState -eq "Succeeded") {
    Write-Host "$($createRgResponse.name) created" -Foregroundcolor DarkCyan 
    Write-Host "resouce id = $($createRgResponse.id)" -Foregroundcolor DarkCyan
  } else {
      Write-Host "Resource was not created... exiting" -Foregroundcolor DarkRed
      exit
    }

} elseif ($rgGroupExist -eq $true) {
    Write-Host "$rgGroupName already exists... continuing" -Foregroundcolor Yellow
  }

# Check if Foundry resource already exists
$foundryResourceExist = (az cognitiveservices account list -g $rgGroupName | ConvertFrom-Json)

# Create Foundry resource
if ($foundryResourceExist.name -ne $foundryResourceName) {

  Write-Host "Creating $foundryResourceName... this can take a few moments"

  $foundryCreateResponse = (($foundryCreate = az cognitiveservices account create --name $foundryResourceName --resource-group $rgGroupName --kind AIServices --sku s0 --location $location --allow-project-management) | ConvertFrom-Json)

  if ($foundryCreateResponse.properties.provisioningState -eq "Succeeded") {
    Write-Host "$($foundryCreateResponse.name) created" -Foregroundcolor DarkCyan
    Write-Host "resouce id = $($foundryCreateResponse.id)" -Foregroundcolor DarkCyan
  } else {
      Write-Host "Resource was not created... exiting" -Foregroundcolor DarkRed
      exit
    }

} elseif ($foundryResourceExist.name -eq $foundryResourceName) {
    Write-Host "$foundryResourceName already exists... continuing" -Foregroundcolor Yellow
  }

#
# Check if custom subdomain is null or not
#if ($foundryCreateResponse.properties.customSubDomainName -eq $null) {

  Write-Host "Adding subdomain $foundryDomainName... this can take a few moments"

  $foundryDomainNameResponse = (($foundryDomainCreate = az cognitiveservices account update --name $foundryResourceName --resource-group $rgGroupName --custom-domain $foundryDomainName) | ConvertFrom-Json)

# Create Project
Write-Host "Creating $foundryProjectName... this can take a few moments"

$foundryProjectCreateResponse = (($foundryProjectCreate = az cognitiveservices account project create --name $foundryResourceName --resource-group $rgGroupName --project-name $foundryProjectName --location $location) | ConvertFrom-Json)

if ($foundryProjectCreateResponse.properties.provisioningState -eq "Succeeded") {
  Write-Host "$($foundryProjectCreateResponse.name) created" -Foregroundcolor DarkCyan
  Write-Host "resouce id = $($foundryProjectCreateResponse.id)" -Foregroundcolor DarkCyan
} else {
    Write-Host "Resource was not created... exiting" -Foregroundcolor DarkRed
    exit
  }

$deployModel = (az cognitiveservices account deployment create --name $foundryResourceName --resource-group $rgGroupName --deployment-name gpt-4.1 --model-name gpt-4.1 --model-version 2025-04-14 --model-format OpenAI --sku-capacity 1 --sku-name Standard | ConvertFrom-Json)

if ($deployModel.properties.provisioningState -eq "Succeeded") {
  Write-Host "$($deployModel.name) created" -Foregroundcolor DarkCyan
  Write-Host "resouce id = $($deployModel.id)" -Foregroundcolor DarkCyan
} else {
  Write-Host "model not deployed... exiting" -Foregroundcolor DarkRed
}

Write-Host "environment setup!" -Foregroundcolor DarkCyan

# Deploy Agent
$agentName = Read-Host "enter agent's name"

$azureAiToken = (az account get-access-token --resource https://ai.azure.com/ --query accessToken -o tsv)

$Headers = @{
  Authorization = "Bearer $azureAiToken"
}

$Body = @"
  {
   "name": "$agentName",
   "definition": {
      "kind": "prompt",
      "instructions": "You are a helpful assistant that answers general questions",
      "model": "gpt-4.1",
      "tools": [
        { "type": "web_search" }
      ]
    }
  }
"@

$Uri = "https://$foundryDomainName.services.ai.azure.com/api/projects/$foundryProjectName/agents?api-version=v1"

$response = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -Body $Body -ContentType "application/json"

if ($response.StatusCode -eq "200") {
  Write-Host "agent successfully deployed" -Foregroundcolor DarkCyan
  Write-Host "view your resources at https://ai.azure.com"
  Write-Host "make sure you have at least Azure AI Owner permissions on $($rgGroupName)" -Foregroundcolor Yellow
} else {
   Write-Host "deployment of agent errored" -Foregroundcolor Red
  }
  
  
  # need to add model deployment for the project
