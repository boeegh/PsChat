using module ..\Dialog.psm1
using module ..\OpenAiChat.psm1
using module ..\Options.psm1
using module "..\..\Private\OutHelper.psm1"

class WordCountWarning {
    [bool]$Enabled = $false
    [int]$Threshold = 500

    [Dialog] BeforeQuestion([Dialog]$dialog) {
        if($this.Enabled -and $dialog.GetWordCount() -gt $this.Threshold) {
            [OutHelper]::Info("Current word count is $($dialog.GetWordCount())")
        }
        return $dialog
    }
}
