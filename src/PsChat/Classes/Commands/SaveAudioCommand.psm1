using module .\BaseCommand.psm1
using module ..\Dialog.psm1
using module "..\..\Private\OutHelper.psm1"
using module "..\AudioHelper.psm1"

# write messages to disk, either formatted (w) or as json (wj)
class SaveAudioCommand : BaseCommand {
    [string]$RegEx = "^au$"

    [Dialog] Handle([Dialog]$dialog) {
        $fn = Read-Host -Prompt "File name (press enter for automatic)"

        $helper = [AudioHelper]::new()
        $helper.AuthToken = $this.ChatApi.AuthToken
        try {
            $helper.DialogToAudioFile($dialog, $fn)
            [OutHelper]::Info("Wrote audio to: $fn")
        }
        catch {
            [OutHelper]::NonCriticalError("$($_.Exception.Message)")
        }

        $dialog.ClearQuestion()
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "au  → Save audio to file"
        )
    }
}
