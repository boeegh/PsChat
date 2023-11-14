$NAME_QUESTION = "What is your name?"
$NAME_ANSWER = "OpenAI"

function AssertContains($result, $expected) {
  $success = ($result -join "").Contains($expected)
  if($success -eq $false) {
    Write-Host "Expected: ""$expected"". Actual: ""$result"". " -NoNewline
  } 
  return $success
} 

function AssertNotNull($result) {
  return $null -ne $result
}

function Get-PsChatAnswer-Direct-String-Input {
  AssertContains (Get-PsChatAnswer -Temperature 0.1 $NAME_QUESTION) $NAME_ANSWER
}

function Get-PsChatAnswer-Piped-String-Input {
  AssertContains ($NAME_QUESTION | Get-PsChatAnswer -Temperature 0.1) $NAME_ANSWER
}

function Get-PsChatAnswer-Object-As-Input {
  $message = @{ "role"="user"; "content"=$NAME_QUESTION }
  AssertContains (Get-PsChatAnswer -InputObject $message -Temperature 0.1) $NAME_ANSWER
}

function Get-PsChatAnswer-Object-As-Input-Array {
  $message = @(
    @{ "role"="user"; "content"="Please short answers." }
    @{ "role"="user"; "content"=$NAME_QUESTION }
  )
  AssertContains (Get-PsChatAnswer -InputObject $message -NoEnumerate -Temperature 0.1) $NAME_ANSWER
}

function Invoke-PsChat-Function-Test {
  $result = Invoke-PsChat -Single -Question "Whats the uptime?" `
     -Functions_Names @("Get-Uptime") `
     -NonInteractive `
     -ResultType Objects
  $message = ($result | Where-Object { $_.Role -match "assistant" })
  AssertContains $message "uptime"
}

function Invoke-PsChat-PreLoad-Prompt {
  $result = Invoke-PsChat -Single -Question "Make a short Powershell Hello-World script" `
     -PreLoad_Prompt "Answer using markdown" `
     -NonInteractive `
     -ResultType Objects
  $message = ($result | Where-Object { $_.Role -match "assistant" })
  AssertContains $message "```powershell"
}
