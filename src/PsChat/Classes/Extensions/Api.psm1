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
    [bool]$Stream = $true
    [int]$Max_Tokens = 0
    [object]$Response_Format
    [int]$N = 0

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }
    
        $verboseInfoList = @()
    
        if($this.AuthToken) {
            $this.ChatApi.AuthToken = $this.AuthToken
            $verboseInfoList += "AuthToken: $($this.AuthToken)"
        }
    
        if($this.Model) {
            $this.ChatApi.Model = $this.Model
            $verboseInfoList += "Model: $($this.Model)"
        }
    
        if($this.Temperature) {
            $this.ChatApi.Temperature = $this.Temperature
            $verboseInfoList += "Temperature: $($this.Temperature)"
        }
    
        if($this.Top_P) {
            $this.ChatApi.Top_P = $this.Top_P
            $verboseInfoList += "Top_P: $($this.Top_P)"
        }
    
        if($this.Baseurl) {
            $this.ChatApi.Baseurl = $this.Baseurl
            $verboseInfoList += "Baseurl: $($this.Baseurl)"
        }
    
        $this.ChatApi.Stream = $this.Stream
        $verboseInfoList += "Stream: $($this.Stream)"
    
        if($this.Max_Tokens -ne 0) {
            $this.ChatApi.Max_Tokens = $this.Max_Tokens
            $verboseInfoList += "Max_Tokens: $($this.Max_Tokens)"
        }
    
        if($this.Response_Format) {
            $this.ChatApi.Response_Format = $this.Response_Format
            $verboseInfoList += "Response_Format: $($this.Response_Format | ConvertTo-Json -Compress -Depth 1)"
        }

        if($this.N -ne 0) {
            $this.ChatApi.N = $this.N
            $verboseInfoList += "N: $($this.N)"
        }
    
        if($this.Verbose) {
            $verboseInfo = "- Setting API parameters: " + ($verboseInfoList -join ", ")
            [OutHelper]::Info($verboseInfo)
        }
    
        return $dialog
    }
}