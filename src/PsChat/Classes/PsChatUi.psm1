using module "..\Private\OutHelper.psm1"
using module ".\Dialog.psm1"
using module ".\Options.psm1"
using module ".\OpenAiChat.psm1"
using module ".\Extensions\ExtensionContainer.psm1"
using module ".\Extensions\Api.psm1"
using module ".\Extensions\WordCountWarning.psm1"
using module ".\Extensions\AutoSave.psm1"
using module ".\Extensions\PreLoad.psm1"
using module ".\Extensions\Commands.psm1"
using module ".\Extensions\ShortTerm.psm1"
using module ".\Extensions\Functions.psm1"

class PsChatUi {
    [string]$OpenAiAuthKey
    [Options]$Options
    [OpenAiChat]$ChatApi
    [Dialog]$Dialog
    [ExtensionContainer]$ExtensionContainer
#     [bool]$Stream = $true

    PsChatUi([string]$openAiAuthKey, [Options]$options) {
        $this.OpenAiAuthKey = $openAiAuthKey
        $this.Options = $options

        $this.ChatApi = [OpenAiChat]::new($this.OpenAiAuthKey)
        $this.ChatApi.Stream = $true
        $this.Dialog = [Dialog]::new()
        $this.ExtensionContainer = [ExtensionContainer]::new($this.ChatApi, $this.Options, @(
                [Api]::new()
                [AutoSave]::new()
                [PreLoad]::new()
                [Commands]::new()
                [ShortTerm]::new()
                [Functions]::new()
                [WordCountWarning]::new()
            ))
    }

    [object] Start() {
        [OutHelper]::Info("Starting PsChat v$((Get-Module -Name PsChat).Version). Press 'q' to quit.")
        $dlg = $this.Dialog
        $dlg.Question = $this.Options.InitialQuestion
        $dlg = $this.ExtensionContainer.Invoke("BeforeChatLoop", $dlg)

        do {
            # call api with all previous messages
            if (![string]::IsNullOrEmpty($dlg.Question)) {
                $dlg = $this.ExtensionContainer.Invoke("BeforeAnswer", $dlg)
                $dlg = $this.Invoke($dlg)
                $dlg = $this.ExtensionContainer.Invoke("AfterAnswer", $dlg)
                if ($this.Options.SingleQuestion) { 
                    break
                }
            }

            # execute extension logic before a question
            $dlg = $this.ExtensionContainer.Invoke("BeforeQuestion", $dlg)

            $dlg.PromptUser()

            # execute extension logic after a question
            $dlg = $this.ExtensionContainer.Invoke("AfterQuestion", $dlg)

        } while ($dlg.Question -ne "q" )

        $this.ExtensionContainer.Invoke("AfterChatLoop", $dlg) | Out-Null
        return $dlg
    }

    [Dialog] Invoke([Dialog]$dlg) {
        $qm = [DialogMessage]::FromUser($dlg.Question)
        $dlg.AddMessage($qm)
        $message = $this.ChatApi.GetAnswer($dlg.AsOpenAiChatMessages())
        $message = $this.ExtensionContainer.Invoke("PostOpenAiChatResponse", @{ "message" = $message; "dialog" = $dlg }) # hmf

        if ($null -ne $message.Content) {
            if ($this.ChatApi.Stream -eq $false) {
                [OutHelper]::Gpt($message.Content)
            }
            $dlg.AddOpenAiMessage($message)
        }

        return $dlg
    }
}