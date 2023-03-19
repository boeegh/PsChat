using module .\BaseCommand.psm1
using module ..\Dialog.psm1
using module "..\..\Private\OutHelper.psm1"

# write messages to disk, either formatted (w) or as json (wj)
class SaveMessagesCommand : BaseCommand {
    [string]$RegEx = "^w[js]?$"

    [Dialog] Handle([Dialog]$dialog) {
        if($dialog.Question -eq "ws") {
            [OutHelper]::Info("`n$($dialog.ExportMessages($false))`n`n")
            $dialog.ClearQuestion()
            return $dialog
        }

        $fn = Read-Host -Prompt "File name (press enter for automatic)"
        if(!$fn) {
            $fn = "dialog-$(Get-Date -Format "yyyyMMdd_HHmmss").json"
        }

        $fileContent = $dialog.ExportMessages($dialog.Question -eq "wj")

        Out-File -FilePath $fn -InputObject $fileContent
        [OutHelper]::Info("Wrote messages to: $fn")
        $dialog.ClearQuestion()
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "w   → Write messages to a file in formatted plaintext",
            "wj  → Write messages to a file as JSON",
            "ws  → Write messages to the screen"
        )
    }
}
