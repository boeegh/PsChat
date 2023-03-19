using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class ShortTerm {
    [string]$WordCountThreshold = 2000
    [bool]$Enabled = $true
    [bool]$Verbose = $true

    [Dialog] AfterAnswer([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }

        $wordCount = $dialog.GetWordCount()
        if($wordCount -gt $this.WordCountThreshold) {
            # remove messages that oldest message, that is not locked
            $removeWordCount = $wordCount - $this.WordCountThreshold

            $removedWords = 0
            $dialog.Messages = $dialog.Messages | Where-Object {
                if($_.locked) {
                    return $true
                }

                if($removedWords -ge $removeWordCount) {
                    return $true
                }

                $removedWords += [Dialog]::CalculateWords(@($_))
                # Write-Debug "Removing message: $($_.content) ($removedWords/$removeWordCount)"
                return $false
            }

            if($this.Verbose) {
                [OutHelper]::Info("ShortTerm removed $removedWords words, current word count is $($dialog.GetWordCount())")
            }
        }

        return $dialog
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        return $dialog
    }
}