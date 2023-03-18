using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class AutoSave {
    [string]$Path
    [bool]$Enabled = $false

    [string] GetName() {
        return "pschat-$(Get-Date -Format "yyyy-MM-dd-HHmmss").json"
    }

    Save([Dialog]$dialog) {
        if(!$this.Enabled) { return }

        $fileContent = $dialog.ExportMessages($true)
        Out-File -FilePath $this.Path -InputObject $fileContent
        Write-Debug("AutoSaved to $($this.Path)")
    }

    [Dialog] AfterAnswer([Dialog]$dialog) {
        $this.Save($dialog)
        return $dialog
    }

    [Dialog] AfterQuestion([Dialog]$dialog) {
        $this.Save($dialog)
        return $dialog
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }
        $this.Path = if($this.Path) { $this.Path } else { $this.GetName() }
        [OutHelper]::Info("AutoSaving to $($this.Path)")
        return $dialog
    }
}