<#
.SYNOPSIS
Invoke OpenAI/LLM API to analyze files for sensitive data.

.PARAMETER Path
The path to analyze. Defaults to current directory.

.PARAMETER PromptSuffix
The prompt suffix to use for each chunk of code/text. Defaults to a generic prompt.

.PARAMETER Model
The OpenAI/LLM model to use. Defaults to gpt-4.

.PARAMETER Temperature
The OpenAI/LLM temperature to use. Defaults to 0.4.

.PARAMETER Files
The files to analyze. Defaults to source code-like files in the path.

.PARAMETER DisplayJsonParseErrors
Whether to display JSON parse errors or not. Defaults to false.

.PARAMETER IgnoreCostPrompt
Whether to ignore the cost prompt or not. Defaults to false.
#>
[CmdletBinding()]
param(
  [Parameter()]
  [string]$Path = ".",
  [Parameter()]
  [string]$PromptSuffix = ""+
    "Given the above source code snippet, try to find any mentions of "+
    "user names, passwords, PII, secret tokens, ANY even slightly offensive language, ip-adresses "+
    "or anything else that's considered sensitive in a corporate environment.`n"+
    "Answer with a JSON-array containing each line of sensitive data, example: [ 'line 1', 'line 2' ].`n"+
    "If no sensitive data is found, answer with an empty JSON-array, example: []. Reply only with JSON.",
  [Parameter()]
  [string]$Model = "gpt-4",
  [Parameter()]
  [decimal]$Temperature = 0.4,
  [Parameter()]
  [object[]]$Files,
  [Parameter()]
  [Switch]$DisplayJsonParseErrors,
  [Parameter()]
  [Switch]$IgnoreCostPrompt
)

function Get-Relevant-Files-Recursive {
  param(
    [string]$Path,
    [string[]]$Extensions = @(
      ".cs", ".cshtml", ".csproj", ".sln",        # c#
      ".ps1", ".psm1", ".psd1",                   # powershell
      ".md", ".txt", ".html",                     # html
      ".py",                                      # python
      ".js", ".jsx", ".ts", ".tsx",               # javascript
      ".go",                                      # go
      ".java",                                    # java
      ".php",                                     # php
      ".rb",                                      # ruby
      ".cpp", ".hpp", ".h", ".c", ".cc", ".cxx",  # c++
      ".rs",                                      # rust
      ".sh",                                      # bash
      ".css", ".less", ".scss",                   # css
      ".yaml", ".yml",                            # yaml
      ".toml", ".ini",                            # configs
      ".config", ".yml", "yaml", ".json", ".env"  # configs
      ),
      [string[]]$Exclude = @(
        "node_modules", "bin", "obj", "packages", "dist", "build", "out"
      )
  )

  $files = Get-ChildItem -File -Path $Path -Exclude $Exclude -Recurse
  $files = $files | Where-Object { $Extensions.Contains($_.Extension.ToLower()) }
  return $files
}

function Get-OpenAI-Model-Info($modelName) {
  $map = @{
    "gpt-4" = @{ "context"=8000; "costInput"=0.03; "costOutput"=0.06 }
    "gpt-3.5-turbo" = @{ "context"=4000; "costInput"=0.0015; "costOutput"=0.002 }
  }
  $info = $map[$modelName]
  if($null -eq $info) {
    throw "Unknown model: $modelName"
  }
  return $info
}

# calculate buffer/chunk size based on model
$modelInfo = Get-OpenAI-Model-Info($Model)
$modelInfoDate = Get-Date -Date "2023-10-26" -Format "d"
$charsPerToken = 3.7
$maxSuspectLinesPerChunk = 12
$completionSize = ($maxSuspectLinesPerChunk * 80)
$characterBufferLength = $modelInfo.context * $charsPerToken - $PromptSuffix.Length - $completionSize
$fileCount = 0

# fetch relevant files to analyze
$files = if($null -eq $Files) { Get-Relevant-Files-Recursive -Path $Path } else { $Files }

# approximate cost
if($IgnoreCostPrompt -eq $false) {
  $sizeTotal = $files | Measure-Object -Property Length -Sum  
  $sizeKb = [Math]::Round($sizeTotal.Sum / 1000)
  $costInput = $sizeKb / $charsPerToken * $modelInfo.costInput
  $costOutput = $files.Count * $modelInfo.costOutput # assume max one suspect line per file
  $costApprox = [Math]::Round($costInput + $costOutput, 2)
  $confirm = Read-Host -Prompt "Approximate cost ($sizeKb kB; prices from $modelInfoDate): $costApprox USD. Continue? [y/n]"
  if($confirm -ne "y") {
    Write-Output "Aborted."
    return
  }
}

# analyze each input file
foreach($file in $files) {
  Write-Debug "Analyzing: $($file.FullName)"
  $content = Get-Content -Path $file.FullName -Raw
  
  # get each chunk of content (max characterBufferLength)
  for($i=0; $i -lt $content.Length; $i += $characterBufferLength) {        
    # construct prompt consisting of chunk of code/text + promptSuffix
    $chunk = $content.Substring($i, [Math]::Min($characterBufferLength, $content.Length - $i))
    $prompt = "###`n$chunk`n###`n$promptSuffix"

    # invoke openai/llm api 
    $json = Invoke-PsChat -Question $prompt -Single -NonInteractive `
      -Api_Temperature $Temperature `
      -Api_Model $Model `
      -ResultType LastAnswerAsText

    if($null -eq $json -or $json.Length -eq 0) {
      Write-Debug "Unable to get valid answer from OpenAI/LLM"
      continue
    }

    # try parse, because LLMs aren't an exact science
    try {
      $result = ConvertFrom-Json $json
    } catch {
      if($DisplayJsonParseErrors) {
        Write-Error -ErrorRecord $_ -RecommendedAction "Invalid JSON: $json"             
      }
      continue
    }

    # output each line of suspect code
    foreach($line in $result) {
      $out = [PSCustomObject]@{ File=$file.FullName; Line=$line }
      Write-Output -InputObject $out
    }
  }

  $fileCount++
  Write-Progress -Activity "Analyzing files" `
      -Status "Files analyzed: $fileCount/$($files.Count). Suspect lines: $($suspectLines.Count)" `
      -PercentComplete ($fileCount / $files.Count * 100)
}
