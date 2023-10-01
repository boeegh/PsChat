using module ".\ConsoleInput.psm1"
using module "..\Private\OutHelper.psm1"
using module ".\OpenAiChat.psm1"

class DialogMessage : OpenAiChatMessage {
    DialogMessage([string]$role, [string]$content) {
        parent::new($role, $content)
    }
}

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

    AddOpenAiMessage([OpenAiChatMessage]$message) {
        $this.Messages += @{
            "role" = $message.Role;
            "content" = $message.Content;
        }
    }

    [OpenAiChatMessage[]] AsOpenAiChatMessages() {
        $openAiMessages = @()
        foreach($m in $this.Messages) {
            $openAiMessages += [OpenAiChatMessage]::new($m.role, $m.content)
        }
        return $openAiMessages
    }

    AddMessage($role,$content) {
        $this.Messages += @{
            "role" = $role;
            "content" = $content;
        }
    }

    InsertMessage($role,$content) {
        $this.Messages = @( @{
            "role" = $role;
            "content" = $content;
        } ) + $this.Messages
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

    [string] GetMessageFormatted([object]$message) {
        $from = "SYS"
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

    static [int] CalculateWords($messages) {
        return $messages | ForEach-Object { $_.content.split(" ").count } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
    }

    static [int] ApproximateTokens($messages) {
        $factor = 0.36787944117144
        $charSum = $messages | ForEach-Object { $_.content.length } | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $tokens = $charSum * $factor
        return [Math]::Round($tokens)
   }

    [int] GetTokenCount() {
        return [Dialog]::ApproximateTokens($this.Messages)
    }

    [int] GetWordCount() {
        return [Dialog]::CalculateWords($this.Messages)
    }
}