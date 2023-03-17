using module ".\BaseCommand.psm1"
using module "..\Dialog.psm1"
using module "..\..\Private\OutHelper.psm1"

# produce a variant of the former reply
class VariantCommand : BaseCommand {
    [string]$RegEx = "^v$"

    [Dialog] Handle([Dialog]$dialog) {
        $dialog.ClearQuestion()
        if($dialog.Messages.count -gt 1) {
            $dialog.Question = $dialog.Messages[-2].content # pop former question
            $dialog.Messages = $dialog.Messages | Select-Object -SkipLast 2
            if($dialog.Messages.count -eq 0) {
                $dialog.Messages = @()
            }
            [OutHelper]::Info("Repeating question: $($dialog.Question)")
        } else {
            [OutHelper]::Info("Please ask a question before requesting a variant.")
        }
        return $dialog
    }

    [string[]] GetHelp() {
        return @(
            "v   → Asks for same question again, which provides another answer/variant"
        )
    }
}
