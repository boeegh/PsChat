using module ".\ConsoleInput.psm1"
using module "..\Private\OutHelper.psm1"
using module ".\OpenAiChat.psm1"

class DialogMessage : OpenAiChatMessage {
    [bool]$Locked

    DialogMessage([string]$role, [string]$content) {
        $this.Role = $role
        $this.Content = $content
    }

    static [DialogMessage] FromUser([string]$content) {
        # return [DialogMessage]::parent::FromUser($content)
        return [DialogMessage]::new("user", $content)
    }

    static [DialogMessage] FromOpenAiChatMessage([OpenAiChatMessage]$message) {
        # return [DialogMessage]::parent::FromUser($content)
        return [DialogMessage]::new($message.Role, $message.Content)
    }

    [string] GetMessageFormatted() {
        $from = "SYS"
        switch($this.Role) {
            "assistant" { $from = "GPT"; }
            "user" { $from = "YOU"; }
        }
        return "${from}: $($this.Content)"
    }

    static [DialogMessage[]] ImportMessages([string]$json) {
        $messages = @()
        foreach($obj in ConvertFrom-Json -InputObject $json -NoEnumerate -AsHashtable) {
            $dm = [DialogMessage]::new($obj.Role, $obj.Content)
            $dm.Locked = $obj.Locked
            $messages += $dm
        }
        return $messages
    }

    static [object[]] AsObjects([DialogMessage[]]$messages) {
        return ($messages | Select-Object -Property Locked, Role, Content)
    }

    static [string] AsJson([DialogMessage[]]$messages) {        
        $objs = [DialogMessage]::AsObjects($messages)
        return (ConvertTo-Json $objs)
    }

    [int] WordCount() {
        return $this.Content.split(" ").count
    }

    [int] ApproxTokenCount() {
        $factor = 0.36787944117144
        return [Math]::Round($this.Content.length * $factor)
   }
}

class Dialog {
    [string]$Question
    [OpenAiChatMessage[]]$Messages

    [ConsoleInput] $ConsoleInput
    [ConsoleInputHistory] $ConsoleInputHistory

    Dialog() {
        $this.Question = $null
        $this.Messages = @()
        $this.ConsoleInput = [ConsoleInput]::new()
        $this.ConsoleInputHistory = [ConsoleInputHistory]::new()
        $this.ConsoleInput.Extensions = @( $this.ConsoleInputHistory )
    }

    AddOpenAiMessage([OpenAiChatMessage]$message) {
        $this.Messages += [DialogMessage]::FromOpenAiChatMessage($message)
    }

    [OpenAiChatMessage[]] AsOpenAiChatMessages() {
        return $this.Messages
    }

    AddMessage([DialogMessage]$message) {
        $this.Messages += $message
    }

    InsertMessage($role,$content) {
        $this.Messages = @( [DialogMessage]::new($role, $content) ) + $this.Messages
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

    [string] GetMessageFormatted([DialogMessage]$message) {
        return $message.GetMessageFormatted()
    }

    [string] ExportMessages([bool]$asJson) {
        $export = if($asJson)
            { [DialogMessage]::AsJson($this.Messages) }
            else
            { $($this.Messages | ForEach-Object { $this.GetMessageFormatted($_) }) -join "`n" }
        return $export
    }

    static [int] CalculateWords([DialogMessage[]]$messages) {
        return $messages | ForEach-Object { $_.WordCount() } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    }

    static [int] ApproximateTokens([DialogMessage[]]$messages) {
        $tokens = $messages | ForEach-Object { $_.ApproxTokenCount() } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        return $tokens
   }

    [int] GetTokenCount() {
        return [Dialog]::ApproximateTokens($this.Messages)
    }

    [int] GetWordCount() {
        return [Dialog]::CalculateWords($this.Messages)
    }
}