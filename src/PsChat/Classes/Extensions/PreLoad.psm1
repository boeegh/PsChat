using module "..\Dialog.psm1"
using module "..\..\Private\OutHelper.psm1"

class PreLoad {
    [string]$Path

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        $p = $this.Path
        if($p -and (Test-Path $p)) {
            [OutHelper]::Info("Reading message from: $p")
            $dialog.Messages = Get-Content $p | ConvertFrom-Json -NoEnumerate
            [OutHelper]::Info("$($dialog.Messages.count) messages loaded, approx. $($dialog.GetWordCount()) words.")
        }
        return $dialog
    }
}