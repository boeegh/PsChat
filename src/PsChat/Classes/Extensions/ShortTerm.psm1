using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class ShortTerm {
    [OpenAiChat]$ChatApi
    [string]$WordCountThreshold = 1000
    [bool]$Enabled = $true
    [bool]$Verbose = $true
    [bool]$Compress = $true
    [string]$CompressPrompt = "Can you provide a short summary of the previous messages? Start the summary with: Our dialog is about"

    [string] CompressMessages([hashtable[]]$messages) {
        if($this.Verbose) {
            [OutHelper]::Info("Compressing $($messages.Count) messages")
        }

        $prompt = $this.CompressPrompt
        $messages += @{
            "role" = "user";
            "content" = $prompt;
        }

        $compressed = $this.ChatApi.GetAnswer($messages)
        if($null -ne $compressed) {
            [OutHelper]::Info($compressed)
            return $compressed
        }

        return ""
    }

    [Dialog] AfterAnswer([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }

        $wordCount = $dialog.GetWordCount()
        if($wordCount -gt $this.WordCountThreshold) {
            # remove messages that oldest message, that is not locked
            $removeWordCount = $wordCount - $this.WordCountThreshold
            $removedWords = 0

            # remove messages that are not locked up until the word count is below the threshold
            $removedMessages = @()
            $dialog.Messages = $dialog.Messages | Where-Object {
                if($_.locked) {
                    return $true
                }

                if($removedWords -ge $removeWordCount) {
                    return $true
                }

                $removedWords += [Dialog]::CalculateWords(@($_))
                $removedMessages += $_
                Write-Debug "Removing message: $($_.content) ($removedWords/$removeWordCount)"
                return $false
            }

            if($this.Compress) {
                $compressed = $this.CompressMessages($removedMessages)
                if($compressed) {
                    $dialog.InsertMessage("assistant", $compressed)
                }
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