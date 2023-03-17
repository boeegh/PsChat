class OutHelper {
    static Info([string]$message) {
        Write-Host "INF: $message" -ForegroundColor Blue
    }

    static NonCriticalError([string]$message) {
        Write-Host "ERR: $message" -ForegroundColor Red
    }

    static Gpt([string]$message) {
        if($message -eq $null) {
            return
        }
        Write-Host "GPT: $message" -ForegroundColor Yellow
    }

    static GptDelta([string]$message, [bool]$initial = $false) {
        if($initial) {
            Write-Host "GPT: " -ForegroundColor Yellow -NoNewline
        }
        Write-Host "$message" -ForegroundColor Yellow -NoNewline
    }
}