using namespace System.Runtime.InteropServices
using module .\BaseCommand.psm1
using module ..\Dialog.psm1
using module "..\..\Private\OutHelper.psm1"

# show chords
class ChordsCommand : BaseCommand {
    [string]$RegEx = "^ch$"

    [bool] IsMacOS() {
        return [RuntimeInformation]::IsOSPlatform([OSPlatform]::OSX)
    }

    [Dialog] Handle([Dialog]$dialog) {
        switch($dialog.Question) {
            "ch" {
                $alt = if($this.IsMacOS()) { "Option ⌥" } else { "Alt" }
                [OutHelper]::Info("Available chords (activated pressing $alt-P + chord-key):")
                [OutHelper]::Info("  E - Activate/deactivate alternative ENTER-mode, where ENTER adds a new line instead of sending the message")
                [OutHelper]::Info("  V - Paste content from the clipboard")
            }
        }
        $dialog.ClearQuestion()
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "ch  → Shows available keyboard chords"
        )
    }
}
