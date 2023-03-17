using module PsChat
# using module "..\src\PsChat\PsChat.psm1"

function Invoke-Api-Test {
    $chatApi = New-OpenAiChat -AuthToken $env:OPENAI_AUTH_TOKEN
    $reply = $chatApi.Ask("hello")
    Write-Output "GPT says: $reply"
}

Invoke-Api-Test