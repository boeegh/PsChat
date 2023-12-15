pwsh -NoProfile -Command {
  function PadRightUntil([string]$inputString, [int]$totalLength, [string]$padChar = ".") {
    $dots = $padChar * ($totalLength - $inputString.Length)
    return "$inputString$dots"
  }

  Remove-Module PsChat -Force 2> $null
  Import-Module ../src/PsChat/PsChat.psd1 -Force
  # $DebugPreference="Continue"

  $scriptPath = "./tests.ps1"
  $scriptPath = Resolve-Path -Path $scriptPath
  . $scriptPath

  # get tests from script and run them
  $tests = Get-Command -CommandType Function | `
    Where-Object { $_.ScriptBlock.File -eq $scriptPath -and $_.Name.StartsWith("Assert") -eq $false }
  $failed = @()
  foreach ($test in $tests) {
    $pctComplete = [Math]::Floor(($tests.IndexOf($test)+1) / $tests.Count * 100)
    Write-Progress -Activity "Running tests" -Status $test.Name -PercentComplete $pctComplete
    $success = Invoke-Command -ScriptBlock {
      param($command)
      & $command
    } -ArgumentList $test.Name
    if ($success -eq $false) {
      $failed += $test.Name
    }
  }

  @{
    "TestsAll" = $tests | ForEach-Object { $_.Name }
    "TestsFailed" = $failed
  }
}