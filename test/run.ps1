# using module PsChat
# # using module "..\src\PsChat\PsChat.psm1"

# function Invoke-Api-Test {
#     $chatApi = New-OpenAiChat -AuthToken $env:OPENAI_AUTH_TOKEN
#     $reply = $chatApi.Ask("hello")
#     Write-Output "GPT says: $reply"
# }

# Invoke-Api-Test

pwsh -NoProfile -Command { 
  Remove-Module PsChat -Force 2> $null
  # $DebugPreference="Continue"; 
  Import-Module ../src/PsChat/PsChat.psd1 -Force 

  $scriptPath = "./tests.ps1"
  $scriptPath = Resolve-Path -Path $scriptPath
  . $scriptPath

  $tests = Get-Command -CommandType Function | Where-Object { $_.ScriptBlock.File -eq $scriptPath }
  foreach ($test in $tests) {
    Write-Host "Running test '$($test.Name)': " -NoNewline    
    
    $success = Invoke-Command -ScriptBlock { param($command) & $command } -ArgumentList $test.Name
    #$success = $test.Invoke()
    if ($success) {
      Write-Host "Success" -ForegroundColor Green
    } else {
      Write-Host "Failed" -ForegroundColor Red
    }
  }
}