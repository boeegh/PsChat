using module "./ConsoleInput.psm1"
using module "..\Private\OutHelper.psm1"

class Dialog {
    [string]$Question
    [object[]]$Messages

    [ConsoleInput] $ConsoleInput
    [ConsoleInputHistory] $ConsoleInputHistory

    Dialog() {
        $this.Question = $null
        $this.Messages = @()
        $this.ConsoleInput = [ConsoleInput]::new()
        $this.ConsoleInputHistory = [ConsoleInputHistory]::new()
        $this.ConsoleInput.Extensions = @( $this.ConsoleInputHistory )
    }

    AddMessage($role,$content) {
        $this.Messages += @{
            "role" = $role;
            "content" = $content;
        }
    }

    PromptUser() {
        $this.Question = $this.ConsoleInput.ReadLine("YOU: ")
        if($this.Question) {
            $this.ConsoleInputHistory.AddHistory($this.Question)
        }
    }

    ClearMessages() {
        $this.Messages = @()
    }

    ClearQuestion() {
        $this.Question = $null
    }

    LoadMessages([string]$path) {
        if($path -and (Test-Path $path)) {
            [OutHelper]::Info("Reading message from: $path")
            $this.Messages = Get-Content $path | ConvertFrom-Json -NoEnumerate
            [OutHelper]::Info("$($this.Messages.count) messages loaded, approx. $($this.GetWordCount()) words.")
        }
    }

    [string] GetMessageFormatted([object]$message) {
        $from = "SYSTEM"
        switch($message.role) {
            "assistant" { $from = "GPT"; }
            "user" { $from = "YOU"; }
        }
        return "${from}: $($message.content)"
    }

    [string] ExportMessages([bool]$asJson) {
        $export = if($asJson)
            { $(ConvertTo-Json $this.Messages) }
            else
            { $($this.Messages | ForEach-Object { $this.GetMessageFormatted($_) }) -join "`n" }
        return $export
    }

    [int] GetWordCount() {
        return $this.Messages | ForEach-Object { $_.content.split(" ").count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    }
}