using module "..\Private\OutHelper.psm1"
using module "..\Private\SpecialCommands.psm1"
using module ".\Options.psm1"
using module ".\OpenAiChat.psm1"
using module ".\Dialog.psm1"
using module ".\Extensions\ExtensionContainer.psm1"
using module ".\Extensions\WordCountWarning.psm1"
using module ".\Extensions\AutoSave.psm1"

class PsChatUi {
    [string]$OpenAiAuthKey
    [Options]$Options
    [OpenAiChat]$ChatApi
    [Dialog]$Dialog
    [ExtensionContainer]$ExtensionContainer

    PsChatUi([string]$openAiAuthKey, [Options]$options) {
        $this.OpenAiAuthKey = $openAiAuthKey
        $this.Options = $options

        $this.ChatApi = [OpenAiChat]::new($this.OpenAiAuthKey)
        $this.Dialog = [Dialog]::new()
        $this.ExtensionContainer = [ExtensionContainer]::new($this.ChatApi, $this.Options, @(
            [WordCountWarning]::new()
            [AutoSave]::new()
        ))
    }

    Start([string]$question, [bool]$single) {
        [OutHelper]::Info("Starting PsChat v$((Get-Module -Name PsChat).Version).$(if(!$single) { " Press 'h' for help." })")

        $dlg = $this.Dialog
        $dlg.Question = $Question

        if($this.Options.PreLoadMessagesPath) {
            $dlg.LoadMessages($this.Options.PreLoadMessagesPath)
        }

        $dlg = $this.ExtensionContainer.Invoke("BeforeChatLoop", $dlg)

        do {
            # call api with all previous messages
            if(![string]::IsNullOrEmpty($dlg.Question)) {
                $dlg = $this.ExtensionContainer.Invoke("BeforeAnswer", $dlg)
                $dlg = $this.Invoke($dlg)
                if($Single) { break }
            }

            # execute extension logic before a question
            $dlg = $this.ExtensionContainer.Invoke("BeforeQuestion", $dlg)

            $dlg.PromptUser()

            # execute extension logic after a question
            $dlg = $this.ExtensionContainer.Invoke("AfterQuestion", $dlg)

            # handle special commands
            $dlg = Invoke-SpecialCommand $this.ChatApi $dlg
        } while($dlg.Question -ne "q" )

        $this.ExtensionContainer.Invoke("AfterChatLoop", $dlg) | Out-Null
    }

    [Dialog] Invoke([Dialog]$dlg) {
        $dlg.AddMessage("user", $dlg.Question)
        $answer = $this.ChatApi.GetAnswer($dlg.Messages)
        if($null -ne $answer) {
            [OutHelper]::Gpt($answer)
            $dlg.AddMessage("assistant", $answer)
        }
        return $dlg
    }
}