using module "..\Classes\Commands\BaseCommand.psm1"
using module "..\Classes\Commands\SaveMessagesCommand.psm1"
using module "..\Classes\Commands\VariantCommand.psm1"
using module "..\Classes\Commands\CompressionCommand.psm1"
using module "..\Classes\Commands\ClipboardCommand.psm1"
using module "..\Classes\Commands\ApiSettingsCommand.psm1"
using module "..\Classes\Dialog.psm1"
using module "..\Classes\OpenAiChat.psm1"
using module ".\OutHelper.psm1"

function Show-Help([BaseCommand[]] $handlers) {
    foreach($handler in $handlers | Sort-Object { $_.RegEx }) {
        foreach($text in $handler.GetHelp() | Sort-Object { $_ }) {
            [OutHelper]::Info($text)
        }
    }
    [OutHelper]::Info("q   → Quits PsChat")
}

function Invoke-SpecialCommand([OpenAiChat]$chatApi, [Dialog]$dialog) {
    $handlers = @(
        [SaveMessagesCommand]::new(),
        [VariantCommand]::new(),
        [CompressionCommand]::new(),
        [ClipboardCommand]::new(),
        [ApiSettingsCommand]::new()
    )

    # help
    if($dialog.Question -match "^h$") {
        Show-Help($handlers)
        $dialog.ClearQuestion()
        return $dialog
    }

    # commands
    $handlers | ForEach-Object { $_.SetApi($chatApi) }
    foreach($handler in $handlers) {
        if(!($dialog.Question -match $handler.RegEx)) {
            continue
        }
        $dialog = $handler.Handle($dialog)
    }

    return $dialog
}

