using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"
using module "..\AudioHelper.psm1"

class SaveAudio {
    [string]$Path
    [OpenAiChat]$ChatApi
    [bool]$Enabled = $false
    [string]$Model = $null
    [string]$UserVoice = "fable"
    [string]$AssistantVoice = "onyx"
    [string]$Response_Format = $null
    [decimal]$Speed = $null

    [string] GetName() {
        return "./pschat-$(Get-Date -Format "yyyy-MM-dd-HHmmss").mp3"
    }

    Save([Dialog]$dialog) {
        if(!$this.Enabled) { return }
        $helper = [AudioHelper]::new()
        if($this.Model) { $helper.Model = $this.Model }
        if($this.Speed) { $helper.Speed = $this.Speed }  
        if($this.Response_Format) { $helper.Response_Format = $this.Response_Format }
        if($this.UserVoice) { $helper.UserVoice = $this.UserVoice }
        if($this.AssistantVoice) { $helper.AssistantVoice = $this.AssistantVoice }

        $helper.AuthToken = $this.ChatApi.AuthToken
        try {
            $helper.DialogToAudioFile($dialog, $this.Path)
            [OutHelper]::Info("SaveAudio: Wrote audio to: $($this.Path)")
        }
        catch {
            [OutHelper]::NonCriticalError("$($_.Exception.Message)")
        }
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }
        $this.Path = if($this.Path) { $this.Path } else { $this.GetName() }
        [OutHelper]::Info("- SaveAudio: Saving to $($this.Path) after chat")
        return $dialog
    }

    [Dialog] AfterChatLoop([Dialog]$dialog) {
        $this.Save($dialog)
        return $dialog
    }
}