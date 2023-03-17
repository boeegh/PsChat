using module ..\Dialog.psm1
using module ..\OpenAiChat.psm1

class BaseCommand {
    [string]$RegEx
    [OpenAiChat]$ChatApi
    SetApi($chatApi) { $this.ChatApi = $chatApi }
    [Dialog] Handle([Dialog]$dialog) { throw "Handle() not implemented" }
    [string[]] GetHelp() { return @() }
}
