<#
  .SYNOPSIS
  Dual-minded makes OpenAI have a conversation with itself.

  .PARAMETER ConversationLength
  Length of the conversation to generate.
#>
param(
  [int]$ConversationLength = 3,
  [string]$SystemPrompt = "Socratic style talk between a wise teacher and a young student. Stick to the topic of philosophy, leave out praise etc. between.",
  [string]$InitialQuestion = "Student: What is the nature of reality?",
  [switch]$SaveAudio
)

$messages = @(
  @{ "Role"="system"; "Content"="$SystemPrompt"; "Locked"=$true },
  @{ "Role"="user"; "Content"="$InitialQuestion" }
)

for($i = 0; $i -lt $ConversationLength; $i++) {
  Write-Progress -Activity "Generating conversation" -Status "Playing it out $($i+1)/$ConversationLength" -PercentComplete (($i+1)/$ConversationLength*100)
  $messages = (Invoke-PsChat -Single -SkipQuestion -PreLoad_Objects $messages -NonInteractive -ResultType Objects)

  # reverse roles, making the assistant the user and vice versa
  foreach($message in $messages) {
    if($message.Locked -eq $true) { continue }
    $message.Role = if($message.Role -eq "user") { "assistant" } else { "user" }
  }
}

$messages

if($SaveAudio) {
  # Write-Progress -Activity "Generating audio" -Status "Fetching and stiching audio" -PercentComplete 50
  Invoke-PsChat -SaveAudio_Enabled $true -Single -NonInteractive -PreLoad_Objects $messages
}
