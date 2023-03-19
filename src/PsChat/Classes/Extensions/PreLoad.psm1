using module "..\Dialog.psm1"
using module "..\..\Private\OutHelper.psm1"

class PreLoad {
    [string]$Prompt
    [string]$Path
    [bool]$Lock # ensures that the initial messages are always the first in the dialog
    [object[]]$InitialMessages

    [Dialog] BeforeAnswer([Dialog]$dialog) {
        if(!$this.Lock) { return $dialog }

        # remove any "locked" messages
        $nlm = @()
        foreach($m in $dialog.Messages) {
            if($m.locked) {
                continue
            }
            $nlm += $m
        }

        # re-insert locked messages
        $dialog.Messages = $this.InitialMessages += $nlm

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
            $this.InitialMessages = Get-Content $p | ConvertFrom-Json -NoEnumerate -AsHashtable
        }

        # load from prompt
        if($this.Prompt) {
            $this.InitialMessages = @( @{ "role" = "user"; "content" = $this.Prompt } )
        }

        if(!$this.InitialMessages) {
            return $dialog
        }

        [OutHelper]::Info("- $($this.InitialMessages.Count) messages loaded, approx. $([Dialog]::CalculateWords($this.InitialMessages)) words.")

        if($this.Lock) {
            # mark messages as locked
            foreach($m in $this.InitialMessages) {
                $m.locked = $true
            }
        }

        $dialog.Messages = $this.InitialMessages

        return $dialog
    }
}