$parameters = @{
    Path        = "./src/PsChat"
    NuGetApiKey = $env:PS_GALLERY_KEY
    ReleaseNote = $env:LAST_COMMIT_MESSAGE
}
Update-ModuleManifest -ModuleVersion "0.0.$env:RUN_NO" -Path ./src/PsChat/PsChat.psd1
Publish-Module @parameters
