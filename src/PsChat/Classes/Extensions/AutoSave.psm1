using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class AutoSave {
    [string]$Path

    [string] GetName() {
        return "pschat-$(Get-Date -Format "yyyy-MM-dd-HHmmss").json"
    }

    [Dialog] AfterQuestion([OpenAiChat]$chatApi, [Options]$options, [Dialog]$dialog) {
        if(!$options.AutoSave) { return $dialog }

        $fileContent = $dialog.ExportMessages($true)
        Out-File -FilePath $this.Path -InputObject $fileContent
        return $dialog
    }

    [Dialog] BeforeChatLoop([OpenAiChat]$chatApi, [Options]$options, [Dialog]$dialog) {
        if(!$options.AutoSave) { return $dialog }

        $this.Path = if($options.AutoSavePath) { $options.AutoSavePath } else { $this.GetName() }
        [OutHelper]::Info("AutoSaving to $($this.Path)")
        return $dialog
    }
}