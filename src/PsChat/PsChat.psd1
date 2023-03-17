@{
    RootModule = 'PsChat.psm1'
    ModuleVersion = '0.0.0' # auto updated by build/publish.ps1
    GUID = '65f36a25-9987-4e19-bcee-f7291f95c73a'
    Author = 'boeegh'
    CompanyName = ''
    Copyright = '(c) boeegh. All rights reserved.'
    Description = 'This module is a simple OpenAI/ChatGPT client for PowerShell'

    # Minimum version of the PowerShell engine required by this module
    # PowerShellVersion = ''

    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''

    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''

    # Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # DotNetFrameworkVersion = ''

    # Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
    # ClrVersion = ''

    FunctionsToExport = 'Get-PsChatAnswer', 'Invoke-PsChat'

    PrivateData = @{
        PSData = @{
            Tags        = 'OpenAi','ChatGPT','Terminal','Chat','Completion', 'PSEdition_Desktop', 'PSEdition_Core', 'Windows', 'Linux', 'MacOS'
            ProjectUri  = "https://github.com/boeegh/PsChat/"
            LicenseUri  = "https://github.com/boeegh/PsChat/blob/main/LICENSE"
            IconUri     = 'https://github.com/boeegh/PsChat/raw/main/assets/logo.png'
        }
    }

    # HelpInfo URI of this module
    HelpInfoURI = 'https://github.com/boeegh/PsChat/'
}

