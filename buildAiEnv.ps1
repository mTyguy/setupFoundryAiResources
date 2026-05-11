<#
Script deploys necessary Foundry resources to create an agent that is capable of doing web searches.
Model is gpt-4.1
#>
Write-Host "Make sure you are logged into Az PowerShell first!!!" -Foregroundcolor Red

$scriptRunner = (az account show | ConvertFrom-Json)

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
    Write-Host "Resource id = $($createRgResponse.id)" -Foregroundcolor DarkCyan
  } else {
      Write-Host "Resource was not created... exiting" -Foregroundcolor DarkRed
      exit
    }

} elseif ($rgGroupExist -eq $true) {
    Write-Host "$rgGroupName already exists... continuing" -Foregroundcolor Yellow
  }
Write-Host "####################"


# Give appropriate Azure role
Write-Host "Would you like to give yourself Azure AI Developer Permissions (1) or Azure AI User Permissions? (2)" -Foregroundcolor DarkCyan
Write-Host "Azure AI Developer - Can perform all actions within an Azure AI resource besides managing the resource itself. Applies to Azure Machine Learning and Foundry hubs only." -Foregroundcolor Yellow
Write-Host "Azure AI User - Grants reader access to AI projects, reader access to AI accounts, and data actions for an AI project." -Foregroundcolor Yellow
$creatorRoleSelection = Read-Host "1 or 2"

if ($creatorRoleSelection -eq "1"){
  $creatorRoleAiDeveloper = az role assignment create --assignee "$($scriptRunner.user.name)" --role "Azure AI Developer" --scope "$($createRgResponse.id)"

  } elseif ($creatorRoleSelection -eq "2") {
    $creatorRoleAiUSer = az role assignment create --assignee "$($scriptRunner.user.name)" --role "Azure AI User" --scope "$($createRgResponse.id)"
}
Write-Host "####################"


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

Write-Host "####################"

Write-Host "Adding subdomain $foundryDomainName... this can take a few moments"

$foundryDomainNameResponse = (($foundryDomainCreate = az cognitiveservices account update --name $foundryResourceName --resource-group $rgGroupName --custom-domain $foundryDomainName) | ConvertFrom-Json)

Write-Host "####################"

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

Write-Host "####################"

Write-Host "Select what model to use -- placeholder" -Foregroundcolor Red

$deployModel = (az cognitiveservices account deployment create --name $foundryResourceName --resource-group $rgGroupName --deployment-name gpt-4.1 --model-name gpt-4.1 --model-version 2025-04-14 --model-format OpenAI --sku-capacity 1 --sku-name Standard | ConvertFrom-Json)

if ($deployModel.properties.provisioningState -eq "Succeeded") {
  Write-Host "$($deployModel.name) created" -Foregroundcolor DarkCyan
  Write-Host "resouce id = $($deployModel.id)" -Foregroundcolor DarkCyan
} else {
  Write-Host "model not deployed... exiting" -Foregroundcolor DarkRed
}

Write-Host "environment setup!" -Foregroundcolor DarkCyan

# Deploy Agent
$agentName = Read-Host "Enter agent's name"
$agentInstructions = Read-Host "Enter the Agent's instruction set... example: You are a helpful assistant that answers general questions"

$azureAiToken = (az account get-access-token --resource https://ai.azure.com/ --query accessToken -o tsv)

$Headers = @{
  Authorization = "Bearer $azureAiToken"
}

$Body = @"
  {
   "name": "$agentName",
   "definition": {
      "kind": "prompt",
      "instructions": "$agentInstructions",
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
  Write-Host "view your resources at https://ai.azure.com !"
} else {
   Write-Host "deployment of agent errored" -Foregroundcolor Red
  }

Write-Host "####################"

Write-Host "Resources Deployed!"

$continueWithIam = Read-Host "Would you like to grant others access to this resource while you are here? y/n"
Write-Host "This script assumes you have User Access Administrator role or similar permissions" -Foregroundcolor Red

if ($continueWithIAM -eq "y") {
  Write-Host "This script assumes you have User Access Administrator role or similar permissions" -Foregroundcolor Red
  do {
    $userToAdd = Read-Host "Who would you like to add to resource? UPN"
    Write-Host "Use Ctrl C to exit loop" -Foregroundcolor Yellow
    $userToAddPerm = Read-Host "Azure AI Developer (1) or Azure AI User (2)?"
      if ($userToAddPerm -eq "1") {$userToAddPerm = "Azure AI Developer"} elseif ($userToAddPerm -eq "2") {$userToAddPerm = "Azure AI User"}
    
    $addUserAIM = az role assignment create --assignee "$userToAdd" --role "$userToAddPerm" --scope "$($createRgResponse.id)"

    } while ($true)

  } else {
    Write-Host "exiting script..."
    exit
}
