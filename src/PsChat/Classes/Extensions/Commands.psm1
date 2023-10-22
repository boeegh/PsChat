using module "..\Dialog.psm1"
using module "..\Options.psm1"
using module "..\OpenAiChat.psm1"
using module "..\..\Private\OutHelper.psm1"
using module "..\Commands\BaseCommand.psm1"
using module "..\Commands\SaveMessagesCommand.psm1"
using module "..\Commands\VariantCommand.psm1"
using module "..\Commands\CompressionCommand.psm1"
using module "..\Commands\ClipboardCommand.psm1"
using module "..\Commands\ApiSettingsCommand.psm1"
using module "..\Commands\ChordsCommand.psm1"

class Commands {
    [Options]$Options
    [OpenAiChat]$ChatApi
    [BaseCommand[]]$ActiveCommands
    [bool]$_initialized = $false

    Commands() {
        $this.ActiveCommands = @(
            [SaveMessagesCommand]::new(),
            [VariantCommand]::new(),
            [CompressionCommand]::new(),
            [ClipboardCommand]::new(),
            [ApiSettingsCommand]::new(),
            [ChordsCommand]::new()
        )
    }

    ShowHelp() {
        foreach($cmd in $this.ActiveCommands | Sort-Object { $_.RegEx }) {
            foreach($text in $cmd.GetHelp() | Sort-Object { $_ }) {
                [OutHelper]::Info($text)
            }
        }
        [OutHelper]::Info("q   → Quits PsChat")
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if(!$this.Options.SingleQuestion) {
            [OutHelper]::Info("- Commands are available. Press 'h' for help.")
        }
        return $dialog
    }

    [Dialog] AfterQuestion([Dialog]$dialog) {
        if($this._initialized -eq $false) {
            $this.ActiveCommands | ForEach-Object { $_.SetApi($this.ChatApi) }
            $this._initialized = $true
        }

        # help
        if($dialog.Question -match "^h$") {
            $this.ShowHelp()
            $dialog.ClearQuestion()
            return $dialog
        }
    
        # commands
        foreach($cmd in $this.ActiveCommands) {
            if(!($dialog.Question -match $cmd.RegEx)) {
                continue
            }
            $dialog = $cmd.Handle($dialog)
        }
    
        return $dialog
    }
}