<#
  .SYNOPSIS
  Dual-minded makes OpenAI have a conversation with itself.

  .PARAMETER ConversationLength
  Length of the conversation to generate.
#>
param(
  [int]$ConversationLength = 8,
  [string]$WrapUpPrompt = `
    "The conversation is nearing its end. What's the final thoughts on the subject that will wrap up the conversation?",
  [string]$Topic = "What is the nature of reality?",
  [string]$Character1 = "Student",
  [string]$Character2 = "Teacher",
  [string]$ContextPrompt = `
    "Socratic style talk between two characters: A wise but scientific $Character2 and a bright $Character1. "+`
    "Stick to the initial topic, keep answers interesting, fairly short and do not repeat unnecessarily. "+ `
    "Use examples and analogies. No praise or thanks between the characters. "+`
    "Prefix each answer with who's saying it and switch back and forth. "+`
    "Each answer must only stem from one of the two characters, reply must never be a mix of both.",
  [switch]$SaveAudio
)

$InitialQuestion = "$($Character1): $Topic"
$ContextPrompt += " Expect about $([Math]::Floor($ConversationLength / 2)) questions from the $($Character1)."
$messages = @(
  @{ "Role"="system"; "Content"="$ContextPrompt"; "Locked"=$true },
  @{ "Role"="user"; "Content"="$InitialQuestion" }
)

# make sure ConversationLength is an odd number, if wrap-up prompt is enabled
if($WrapUpPrompt) {
  if($ConversationLength % 2 -eq 0) { $ConversationLength++ }
}

$allMessages = @( $messages[1] )
for($i = 0; $i -lt $ConversationLength; $i++) {
  Write-Progress -Activity "Conversation" -Status "Playing it out $($i+1)/$ConversationLength" -PercentComplete (($i+1)/$ConversationLength*100)

  # injects a wrap-it-up prompt
  if($i -eq $ConversationLength - 1) {
    $messages += @{ "Role"="system"; "Content"="$WrapUpPrompt"; "Locked"=$true }
  }

  $messages = (Invoke-PsChat -Single -SkipQuestion -PreLoad_Objects $messages -NonInteractive -ResultType Objects)
  $allMessages += $messages[-1]

  # skip reversal if last round (ending with teacher message)
  if($i -eq $ConversationLength - 1 -and $messages[1].Role -eq "user") {
    continue
  }

  # reverse roles, making the assistant the user and vice versa
  foreach($message in $messages) {
    if($message.Role -eq "system") { continue }
    $message.Role = if($message.Role -eq "user") { "assistant" } else { "user" }
  }
}

$allMessages

if($SaveAudio) {
  foreach($message in $allMessages) {
    if($message.Locked -eq $true) { continue }
    $message.Content = $message.Content -replace "^($Character1|$Character2): ", ""
    $message.Role = if($roleSwitch = $roleSwitch -bxor $true) { "user" } else { "assistant" }      
  }

  Invoke-PsChat -SaveAudio_Enabled $true -Single -NonInteractive -PreLoad_Objects $allMessages
}
