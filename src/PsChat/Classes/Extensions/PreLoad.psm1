using module "..\Dialog.psm1"
using module "..\..\Private\OutHelper.psm1"

class PreLoad {
    [string]$Prompt
    [string]$Path
    [bool]$Lock # ensures that the initial messages are always the first in the dialog
    [object[]]$InitialMessages

    [bool]AreEqual($a, $b) {
        if($a.role -ne $b.role) { return $false }
        if($a.content -ne $b.content) { return $false }
        return $true
    }

    [Dialog] BeforeAnswer([Dialog]$dialog) {
        if(!$this.Lock) { return $dialog }

        $index = 0
        foreach($m in $this.InitialMessages) {
            if($this.AreEqual($m, $dialog.Messages[$index])) {
                # Write-Debug "PreLoad: skipping message $($index)"
                $index++
                continue
            }
            break
        }
        # Write-Debug "PreLoad: Conversation starts at $($index)"
        $dialog.Messages = $this.InitialMessages += $dialog.Messages[$index..($dialog.Messages.count)]

        # [OutHelper]::Info("`n$($dialog.ExportMessages($false))")

        return $dialog
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if($this.Path -and $this.Prompt) {
            [OutHelper]::NonCriticalError("PreLoad: Cannot use both -Preload_Prompt and -Preload_Path")
            return $dialog
        }

        # load from path
        $p = $this.Path
        if($p -and (Test-Path $p)) {
            [OutHelper]::Info("- Preloading messages from: $p")
            $this.InitialMessages = Get-Content $p | ConvertFrom-Json -NoEnumerate
            $dialog.Messages = $this.InitialMessages
            [OutHelper]::Info("- $($dialog.Messages.count) messages loaded, approx. $($dialog.GetWordCount()) words.")
        }

        # load from prompt
        if($this.Prompt) {
            $this.InitialMessages = @( @{ "role" = "user"; "content" = $this.Prompt } )
            $dialog.Messages = $this.InitialMessages
            [OutHelper]::Info("- Preloaded prompt, approx. $($dialog.GetWordCount()) words.")
        }

        return $dialog
    }
}