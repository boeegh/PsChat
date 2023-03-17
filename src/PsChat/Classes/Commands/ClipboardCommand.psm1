using module .\BaseCommand.psm1
using module ..\Dialog.psm1
using module "..\..\Private\OutHelper.psm1"

class ClipboardCommand : BaseCommand {
    [string]$RegEx = "^c(g|sc?)$"

    [Dialog] QuestionWithClipboard([Dialog]$dialog) {
        [OutHelper]::Info("Getting content from clipboard.")
        $content = (Get-Clipboard -Raw | Select-Object -First 1)
        $content = "$content`n`---"
        Out-Host -InputObject $content
        $dialog.PromptUser()
        $dialog.Question = "$content`n$($dialog.Question)"
        return $dialog
    }

    [Dialog] AnswerToClipboard([Dialog]$dialog) {
        if($dialog.Messages.count -eq 0) {
            [OutHelper]::Info("There are no answers to put on the clipboard.")
        } else {
            $content = $dialog.Messages[-1].content
            if($dialog.Question -eq "csc") {
                # assuming ``` code delimiter
                $pattern = "(?sm)\``{3}(.*)\``{3}"
                $m = [regex]::Matches($content, $pattern)
                if($m.Count) {
                    # $matches | ConvertTo-Json | Out-Host
                    $content = $m[0].Groups[1].Value
                } else {
                    [OutHelper]::NonCriticalError("No code found. Putting entire answer on clipboard.")
                }
            }
            Set-Clipboard $content
            [OutHelper]::Info("Last answer copied to clipboard.")
        }
        $dialog.ClearQuestion()
        return $dialog
    }

    [Dialog] Handle([Dialog]$dialog) {
        switch -regex ($dialog.Question) {
            "^cg$" { $dialog = $this.QuestionWithClipboard($dialog) }
            "^csc?$" { $dialog = $this.AnswerToClipboard($dialog) }
        }
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "cg  → Insert content from clipboard and ask a question about it",
            "cs  → Put last answer on clipboard",
            "csc → Puts the code part of last answer on the clipboard"
        )
    }
}