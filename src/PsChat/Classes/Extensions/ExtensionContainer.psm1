using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"

class ExtensionContainer {
    [OpenAiChat]$ChatApi
    [Options]$Options
    [object[]]$Extensions

    ExtensionContainer($chatApi, $options, $extensions) {
        $this.ChatApi = $chatApi
        $this.Options = $options
        $this.Extensions = $extensions
    }

    [Dialog] Invoke([string]$eventName, [Dialog]$dialog) {
        $this.Extensions | ForEach-Object {
            $method = $_.GetType().GetMethod($eventName)
            if($method) {
                Write-Debug "ExtensionContainer: Invoking $($method.Name) on $($_.GetType().Name)"
                $arguments = @( $this.ChatApi, $this.Options, $dialog)
                $method.Invoke($_, $arguments)
            }
        }
        return $dialog
    }
}