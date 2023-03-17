class OutHelper {
    static Info([string]$message) {
        Write-Host "INF: $message" -ForegroundColor Blue
    }

    static NonCriticalError([string]$message) {
        Write-Host "ERR: $message" -ForegroundColor Red
    }

    static Gpt([string]$message) {
        Write-Host "GPT: $message" -ForegroundColor Yellow
    }
}