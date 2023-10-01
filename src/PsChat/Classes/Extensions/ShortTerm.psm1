using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class ShortTerm {
    [OpenAiChat]$ChatApi
    [int]$WordCountThreshold = 0
    [int]$TokenCountThreshold = 0
    [bool]$Enabled = $true
    [bool]$Verbose = $false
    [bool]$Compress = $true
    [string]$CompressPrompt = "Provide a short summary of the previous messages? Start with: Our dialog is about"

    [bool] IsTokenBased() {
        return $this.WordCountThreshold -eq 0
    }

    [string] CountUnit() {
        if($this.IsTokenBased()) {
            return "tokens"
        }
        return "words"
        # return (if($this.IsTokenBased()) { "tokens" } else { "words" })
#        return "tokens"
    }

    [string] CompressMessages([DialogMessage[]]$messages) {
        if($this.Verbose) {
            [OutHelper]::Info("Compressing $($messages.Count) messages")
        }

        $prompt = $this.CompressPrompt
        $messages += [DialogMessage]::FromUser($prompt)
        # $messages += @{
        #     "role" = "user";
        #     "content" = $prompt;
        # }

        $streamState = $this.ChatApi.Stream
        $this.ChatApi.Stream = $false
        $compressed = $this.ChatApi.GetAnswer($messages).Content
        $this.ChatApi.Stream = $streamState
        if($null -ne $compressed) {
            # [OutHelper]::Info($compressed)
            Write-Debug("ShortTerm compressed messages to: $compressed")
            return $compressed
        }

        return ""
    }

    [int] EstimateModelTokenCount() {
        if($this.ChatApi.Model.Contains("16k")) {
            return 16768
        }
        if($this.ChatApi.Model.Contains("32k")) {
            return 32768
        }
        if($this.ChatApi.Model.Contains("gpt-4")) {
            return 8192
        }
        return 4097
    }

    [Dialog] AfterAnswer([Dialog]$dialog) {
        if(!$this.Enabled) { return $dialog }

        $count = if($this.IsTokenBased()) { $dialog.GetWordCount() } else { $dialog.GetTokenCount() }
        $threshold = if($this.IsTokenBased()) { $this.TokenCountThreshold } else { $this.WordCountThreshold }
        if($count -gt $threshold) {
            # remove messages that oldest message, that is not locked
            $removeCount = $count - $threshold
            $removedCount = 0

            # remove messages that are not locked up until the word count is below the threshold
            $removedMessages = @()
            $dialog.Messages = $dialog.Messages | Where-Object {
                if($_.Locked) {
                    return $true
                }

                if($removedCount -ge $removeCount) {
                    return $true
                }

                # $removedWords += [Dialog]::CalculateWords(@($_))
                $removedCount += if($this.IsTokenBased()) { $_.ApproxTokenCount() } else { $_.WordCount() }
                $removedMessages += $_

                $snipLength = if($_.Content.Length -gt 20) { 20 } else { $_.Content.Length }
                Write-Debug "Removing message: $($_.Content.Substring(0,$snipLength))... ($removedCount/$removeCount $($this.CountUnit()) to be removed)"
                return $false
            }

            if($this.Compress) {
                $compressed = $this.CompressMessages($removedMessages)
                if($compressed) {
                    $dialog.InsertMessage("assistant", $compressed)
                }
            }

            if($this.Verbose) {
                $count = if($this.IsTokenBased()) { $dialog.GetWordCount() } else { $dialog.GetTokenCount() }
                [OutHelper]::Info("ShortTerm removed $removedCount $($this.CountUnit()), current $($this.CountUnit()) count is $count of $threshold")
            }
        }

        return $dialog
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if($this.WordCountThreshold -eq 0 -and $this.TokenCountThreshold -eq 0) {
            $this.TokenCountThreshold = $this.EstimateModelTokenCount() - 1000
            if($this.Verbose) {
                [OutHelper]::Info("- ShortTerm: No defined threshold set, will use $($this.TokenCountThreshold).")
            }
        }
        return $dialog
    }
}