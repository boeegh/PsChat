using module .\BaseCommand.psm1
using module ..\Dialog.psm1
using module "..\..\Private\OutHelper.psm1"

# write messages to disk, either formatted (w) or as json (wj)
class ApiSettingsCommand : BaseCommand {
    [string]$RegEx = "^a[tpmv]$"

    [Dialog] Handle([Dialog]$dialog) {
        switch($dialog.Question) {
            "av" {
                $this.ChatApi._debug = !$this.ChatApi._debug
                [OutHelper]::Info("API debug-mode is now: $($this.ChatApi._debug)")
            }
            "am" {
                $val = Read-Host -Prompt "Model (current: $($this.ChatApi.Model))"
                if($val) { $this.ChatApi.Model = $val }
            }
            "at" {
                $val = Read-Host -Prompt "Temperature (current: $($this.ChatApi.Temperature))"
                if($val) { $this.ChatApi.Temperature = $val }
            }
            "ap" {
                $val = Read-Host -Prompt "Top_p (current: $($this.ChatApi.Top_p))"
                if($val) { $this.ChatApi.Top_p = $val }
            }
        }
        $dialog.ClearQuestion()
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "am  → Set Chat Completion API model (currently: $($this.ChatApi.Model))",
            "ap  → Set Chat Completion API top_p (currently: $($this.ChatApi.Top_p))",
            "at  → Set Chat Completion API temperature (currently: $($this.ChatApi.Temperature))",
            "av  → Toggle API debug-mode (currently: $($this.ChatApi._debug))"
        )
    }
}
