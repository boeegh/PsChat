pwsh -NoProfile -Command { 
  Remove-Module PsChat -Force 2> $null
  # $DebugPreference="Continue"; 
  Import-Module ../src/PsChat/PsChat.psd1 -Force 

  $scriptPath = "./tests.ps1"
  $scriptPath = Resolve-Path -Path $scriptPath
  . $scriptPath

  function PadRightUntil([string]$inputString, [int]$totalLength, [string]$padChar = ".") {
    $dots = $padChar * ($totalLength - $inputString.Length)
    return "$inputString$dots"
  }  

  $tests = Get-Command -CommandType Function | Where-Object { $_.ScriptBlock.File -eq $scriptPath }
  foreach ($test in $tests) {
    if($test.Name.StartsWith("Assert")) {
      continue
    }

    Write-Host "Running test '$(PadRightUntil $test.Name 50)': " -NoNewline    
    
    $success = Invoke-Command -ScriptBlock { param($command) & $command } -ArgumentList $test.Name
    if ($success) {
      Write-Host "Success" -ForegroundColor Green
    } else {
      Write-Host "Failed" -ForegroundColor Red
    }
  }
}