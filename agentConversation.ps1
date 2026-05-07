# site variables
$foundryDomainName = ""
$projectName       = ""
$agentName         = ""

if ($foundryDomainName -eq "" -or $projectName -eq "" -or $agentName -eq "") {
  Write-Host "empty variables, fill required variables" -Foregroundcolor Red
  break
}

# ask for input
$userInput = Read-Host "Message the agent..."

$azureAiToken = (az account get-access-token --resource https://ai.azure.com/ --query accessToken -o tsv)

$Headers = @{
  Authorization = "Bearer $azureAiToken"
}

$initialBody = @"
  {
   "agent_reference": {
      "type": "agent_reference",
       "name": "$agentName"
       },
    "input": [
      {
        "role": "user",
        "content": "$userInput"
        }
      ]
    }
"@

#
Write-Host "awaiting reply..." -Foregroundcolor Yellow

# start a timer
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

# build initial query uri
$Uri = "https://$foundryDomainName.services.ai.azure.com/api/projects/$projectName/openai/v1/responses"

# initial send query
$initialResponse = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -Body $initialBody -ContentType "application/json"

# print initial response
Write-Host "$(($initialResponse.content | ConvertFrom-Json).output.content.text)" -Foregroundcolor DarkGreen

# end timer and display
$stopWatch.Stop()
Write-Host "This response took " -NoNewLine -Foregroundcolor DarkCyan
Write-Host "$($stopWatch.Elapsed.TotalSeconds) " -NoNewLine -Foregroundcolor Yellow
Write-Host "seconds" -Foregroundcolor DarkCyan

# display token usage
$initialTokenUsage = ($initialResponse.content | ConvertFrom-Json).usage.total_tokens
Write-Host "This action consumed " -NoNewLine -Foregroundcolor DarkCyan
Write-Host "$initialTokenUsage " -NoNewLine -Foregroundcolor Yellow
Write-Host "tokens" -Foregroundcolor DarkCyan

########################
# Conversation ID logic
$bodyConversation = @"
  {
    "items": [
       {
        "type": "message",
        "role": "user",
        "content": [
          {
            "type": "input_text",
            "text": "$userInput"
          }
        ]
      }
    ]
  }
"@

# build conversation query uri - send to /v1/conversations
$Uri = "https://$foundryDomainName.services.ai.azure.com/api/projects/$projectName/openai/v1/conversations"

# conversationId send query
$responseConversation = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -Body $bodyConversation -ContentType "application/json"

# conversation ID variable
$conversationId = ($responseConversation.content | ConvertFrom-Json).id

################

# loop to continue the conversation as long as user wants until they kill the script
do {

# continuing conversation
Write-Host "This will run forever. Press Ctrl+C to stop." -Foregroundcolor Red
$userInput = Read-Host "Message the agent..."

$followupBody = @"
  {
   "agent_reference": {
      "type": "agent_reference",
       "name": "$agentName"
       },
    "conversation": "$conversationId",
    "input": [
      {
        "role": "user",
        "content": "$userInput"
        }
      ]
    }
"@

# start a timer
$stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-Host "awaiting reply..." -Foregroundcolor Yellow

# followup Uri
$Uri = "https://$foundryDomainName.services.ai.azure.com/api/projects/$projectName/openai/v1/responses"

# followup send query
$conversationResponse = Invoke-WebRequest -Method Post -Uri $Uri -Headers $Headers -Body $followupBody -ContentType "application/json"

# followup initial response
Write-Host "$(($conversationResponse.content | ConvertFrom-Json).output.content.text)" -ForegroundColor DarkGreen

# end timer and display
$stopWatch.Stop()
Write-Host "This response took " -NoNewLine -Foregroundcolor DarkCyan
Write-Host "$($stopWatch.Elapsed.TotalSeconds) " -NoNewLine -Foregroundcolor Yellow
Write-Host "seconds" -Foregroundcolor DarkCyan

# display token usage
$tokenUsage = ($conversationResponse.content | ConvertFrom-Json).usage.total_tokens
Write-Host "This action consumed " -NoNewLine -Foregroundcolor DarkCyan
Write-Host "$tokenUsage " -NoNewLine -Foregroundcolor Yellow
Write-Host "tokens" -Foregroundcolor DarkCyan

} while ($true)
