using module .\BaseCommand.psm1
using module ..\Dialog.psm1
using module "..\..\Private\OutHelper.psm1"

# compress and reset the dialog to a message describing the context
class CompressionCommand : BaseCommand {
    [string]$RegEx = "^z$"

    [Dialog] Handle([Dialog]$dialog) {
        $dialog.ClearQuestion()

        [OutHelper]::Info("Preparing context from $($dialog.GetWordCount()) words.")
        $prompt = "Describe the context and topics of our dialog starting with the phrase: The context of our dialog is. Please use bullets for the topics."

        $dialog.AddMessage("user", $prompt)
        $answer = $this.ChatApi.GetAnswer($dialog.Messages)
        if($null -ne $answer) {
            [OutHelper]::Gpt($answer)
            $dialog.ClearMessages()
            $dialog.AddMessage("assistant", $answer)
        }

        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "z   → Compresses the dialog into a single statement that provides context. Removes all other messages."
        )
    }
}
