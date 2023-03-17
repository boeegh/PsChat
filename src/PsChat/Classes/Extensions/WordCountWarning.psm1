using module ..\Dialog.psm1
using module ..\OpenAiChat.psm1
using module ..\Options.psm1
using module "..\..\Private\OutHelper.psm1"

class WordCountWarning {
    [Dialog] BeforeQuestion([OpenAiChat]$chatApi, [Options]$options, [Dialog]$dialog) {
        if($dialog.GetWordCount() -gt $options.WordCountWarningThreshold) {
            [OutHelper]::Info("Current word count is $($dialog.GetWordCount())")
        }
        return $dialog
    }
}

