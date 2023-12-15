using module ".\OpenAiAudio.psm1"
using module ".\Dialog.psm1"
using module "..\Private\OutHelper.psm1"

class AudioHelper {
    [string]$Model = $null
    [string]$UserVoice = "fable"
    [string]$AssistantVoice = "onyx"
    [string]$Response_Format = $null
    [decimal]$Speed = $null
    [string]$AuthToken
    [bool]$ShowProgress = $true

    DialogToAudioFile([Dialog]$dialog, [string]$fileName = "") {
        $audioApi = [OpenAiAudio]::new($this.AuthToken)
        $audioApi._debug = $true
        if(!$fileName) {
            $ext = if($this.Response_Format) { $this.Response_Format } else { "mp3" }
            $fileName = "dialog-$(Get-Date -Format "yyyyMMdd_HHmmss").$ext"
        }

        $tmpFiles = @()
        $audioRequest = [OpenAiAudioSpeechRequest]::new()
        if($this.Model) { $audioRequest.Model = $this.Model }
        if($this.Speed) { $audioRequest.Speed = $this.Speed }  
        if($this.Response_Format) { $audioRequest.Response_Format = $this.Response_Format }

        $messages = $dialog.Messages | Where-Object { $_.Role -ne "system" }
        $step = 0; $stepsTotal = $messages.Count + 2
        function Update-Progress($stepNo, $description) {
            if($this.ShowProgress) {
                Write-Progress -Activity "AudioHelper" -Status "$description $($stepNo)/$stepsTotal" -PercentComplete (($stepNo/$stepsTotal*100))
            }
        }

        foreach($dm in $messages) {
            Update-Progress (++$step) "Getting audio snippet"

            if($dm.Role -eq "system") { continue }
            $audioRequest.Voice = if($dm.Role -eq "user") { $this.UserVoice } else { $this.AssistantVoice }
            $audioRequest.Input = $dm.Content

            $tmpFile = "$fileName-tmp-$($dm.Role)-$($tmpFiles.Count).$($fileName.Split(".")[-1])"
            Write-Debug "AudioHelper: Getting audio snippet: $tmpFile"
            $tmpFiles += $tmpFile
            $audioApi.SpeechToFile($audioRequest, $tmpFile)       
        }

        # build ffmpeg command that will stich all the audio files (tmpFiles) together
        # ffmpeg -i "file1.mp3" -i "file2.opus" -i "file3.aac"
        #  -filter_complex "[0:0][1:0][2:0]concat=n=3:v=0:a=1[out]" 
        #  -map "[out]" "output.mp3"
        $ffmpegApp = "ffmpeg"
        $ffmpegInputArgs = ""
        $ffmpegFilterArgs = ""
        $ffmpegConcat = ""
        $delay = 800
        Update-Progress (++$step) "Concating audio files"
        foreach($tmpFile in $tmpFiles) {
            $ffmpegInputArgs += "-i `"$tmpFile`" "
            $index = $tmpFiles.IndexOf($tmpFile)
            $ffmpegFilterArgs += "[$($index):0]adelay=$delay[a$($index)];"
            $ffmpegConcat += "[a$($index)]"
        }
        $ffmpegFilterArgs += $ffmpegConcat + "concat=n=$($tmpFiles.Count):v=0:a=1[out]"
        $ffmpegCmd = "$ffmpegApp $ffmpegInputArgs -filter_complex `"$($ffmpegFilterArgs)`" -map `"[out]`" `"$fileName`""
        Write-Debug "AudioHelper: Executing ffmpeg command: $ffmpegCmd"

        Invoke-Expression -Command $ffmpegCmd
        if($LASTEXITCODE -ne 0) {
            throw "ffmpeg failed with exit code: $LASTEXITCODE. Command: $ffmpegCmd"
        }

        Update-Progress (++$step) "Cleaning up"
        Remove-Item $tmpFiles
    }
}

