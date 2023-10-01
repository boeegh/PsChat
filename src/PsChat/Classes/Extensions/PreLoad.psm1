using module "..\Dialog.psm1"
using module "..\..\Private\OutHelper.psm1"

class PreLoad {
    [string]$Prompt
    [string]$Path
    [string]$Role = "user"
    [bool]$Verbose = $false
    [bool]$Lock # ensures that the initial messages are always the first in the dialog
    [DialogMessage[]]$InitialMessages

    [Dialog] BeforeAnswer([Dialog]$dialog) {
        if(!$this.Lock) { return $dialog }

        # remove any "locked" messages
        $nlm = @()
        foreach($m in $dialog.Messages) {
            if($m.Locked) {
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
            [OutHelper]::NonCriticalError("- PreLoad: Cannot use both -Preload_Prompt and -Preload_Path")
            return $dialog
        }

        # load from path
        $p = $this.Path
        if($p -and (Test-Path $p)) {
            [OutHelper]::Info("- Preload: From: $p")
            # $this.InitialMessages = Get-Content $p | ConvertFrom-Json -NoEnumerate -AsHashtable
            $this.InitialMessages = [DialogMessage]::ImportMessages((Get-Content $p))
        }

        # load from prompt
        if($this.Prompt) {
            $this.InitialMessages = @( [DialogMessage]::new($this.Role, $this.Prompt) )
            if($this.Verbose) {
                [OutHelper]::Info("- Preload: $($this.Role)-prompt: $($this.Prompt)")
            }
        }

        if(!$this.InitialMessages) {
            return $dialog
        }

        if($this.Verbose) {
            [OutHelper]::Info("- Preload: $($this.InitialMessages.Count) messages loaded, approx. $([Dialog]::ApproximateTokens($this.InitialMessages)) tokens.")
        }

        if($this.Lock) {
            # mark messages as locked
            foreach($m in $this.InitialMessages) {
                $m.Locked = $true
            }
        }

        $dialog.Messages = $this.InitialMessages

        return $dialog
    }
}