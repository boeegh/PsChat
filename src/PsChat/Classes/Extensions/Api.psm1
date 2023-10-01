using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class Api {
    [OpenAiChat]$ChatApi
    [bool]$Enabled = $true
    [bool]$Verbose = $false
    [string]$AuthToken
    [string]$Model
    [decimal]$Temperature
    [decimal]$Top_P
    [string]$Baseurl = "https://api.openai.com/v1/"

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }

        if($this.Verbose) {
            [OutHelper]::Info("- Setting API parameters: AuthToken: $($this.AuthToken), Model: $($this.Model), Temperature: $($this.Temperature), Top_P: $($this.Top_P), Baseurl: $($this.Baseurl)")
        }

        if($this.AuthToken) { $this.ChatApi.AuthToken = $this.AuthToken }
        if($this.Model) { $this.ChatApi.Model = $this.Model }
        if($this.Temperature) { $this.ChatApi.Temperature = $this.Temperature }
        if($this.Top_P) { $this.ChatApi.Top_P = $this.Top_P }
        if($this.Baseurl) { $this.ChatApi.Baseurl = $this.Baseurl }        

        return $dialog
    }
}