<#
  .SYNOPSIS
  Dual-minded makes OpenAI have a conversation with itself.

  .PARAMETER ConversationLength
  Length of the conversation to generate.
#>
param(
  [int]$ConversationLength = 10,
  [string]$SystemPrompt = "Talk between a cop (Stan) and a robber (Peter). Prefix the characters role at the beginning of the reply.",
  [string]$InitialQuestion = "Cop: Where were you yesterday at 8pm?"
)

$messages = @(
  @{ "Role"="system"; "Content"="$SystemPrompt"; "Locked"=$true },
  @{ "Role"="user"; "Content"="$InitialQuestion" }
)

function Out-LastMessage {
  $messages | Select-Object -Last 1 -ExpandProperty Content
}

for($i = 0; $i -lt $ConversationLength; $i++) {
  Out-LastMessage
  $messages = (Invoke-PsChat -Single -SkipQuestion -PreLoad_Objects $messages -NonInteractive -ResultType Objects)

  # reverse roles, making the assistant the user and vice versa
  foreach($message in $messages) {
    $message.Role = if($message.Role -eq "user") { "assistant" } else { "user" }
  }
}
Out-LastMessage
