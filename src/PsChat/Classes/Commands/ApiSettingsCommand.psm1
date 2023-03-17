using module .\BaseCommand.psm1
using module ..\Dialog.psm1

# write messages to disk, either formatted (w) or as json (wj)
class ApiSettingsCommand : BaseCommand {
    [string]$RegEx = "^a[tp]$"

    [Dialog] Handle([Dialog]$dialog) {
        switch($dialog.Question) {
            "at" {
                $foo = Read-Host -Prompt "Temperature (current: $($this.ChatApi.Temperature))"
                if($foo) { $this.ChatApi.Temperature = $foo }
            }
            "ap" {
                $foo = Read-Host -Prompt "Top_p (current: $($this.ChatApi.Top_p))"
                if($foo) { $this.ChatApi.Top_p = $foo }
            }
        }
        $dialog.ClearQuestion()
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "at  → Set chat completion temperature (currently: $($this.ChatApi.Temperature))",
            "ap  → Set chat completion top_p (currently: $($this.ChatApi.Top_p))"
        )
    }
}
