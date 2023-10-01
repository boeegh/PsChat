class OutHelper {
    static [bool]$HostOutput = $true

    static Info([string]$message) {
        if(![OutHelper]::HostOutput) { return }
        Write-Host "INF: $message" -ForegroundColor Blue
    }

    static NonCriticalError([string]$message) {
        if(![OutHelper]::HostOutput) { return }
        Write-Host "ERR: $message" -ForegroundColor Red
    }

    static Gpt([string]$message) {
        if(![OutHelper]::HostOutput) { return }
        if($message -eq $null) {
            return
        }
        Write-Host "GPT: $message" -ForegroundColor Yellow
    }

    static GptDelta([string]$message, [bool]$initial = $false) {
        if(![OutHelper]::HostOutput) { return }
        if($initial) {
            Write-Host "GPT: " -ForegroundColor Yellow -NoNewline
        }
        Write-Host "$message" -ForegroundColor Yellow -NoNewline
    }
}