using module ".\Private\OutHelper.psm1"
using module ".\Classes\Options.psm1"
using module ".\Classes\OpenAiChat.psm1"
using module ".\Classes\PsChatUi.psm1"

$ErrorActionPreference = "Stop"

function Get-PsChatAnswer {
    <#
    .SYNOPSIS
    Request an answer from OpenAI Chat Completion.

    .DESCRIPTION
    This function is a wrapper around OpenAI Chat Completion. It takes a question and returns an answer.

    Please note $ENV:OPENAI_AUTH_TOKEN must be set with a valid OpenAI API key.

    .PARAMETER InputObject
    The question (which may include message history) to ask. Must be either:
    1) A string or an array of strings, eg. "hello" or @("hello", "whats your name?")
    2) A hashtable/object, eg. @{ "role"="user"; "content"="hello" } or
       @( @{ "role"="user"; "content"="hello" }, @{ "role"="assistant"; "content"="hello" } )

    .PARAMETER NoEnumerate
    If set, the InputObject is not enumerated. This is useful if you want to pass an array of hashtables/objects, eg.:
    @(
        @{ "role"="user"; "content"="hello" }
        @{ "role"="assistant"; "content"="hello" }
        @{ "role"="user"; "content"="whats your name?" }
    )

    .PARAMETER NumberOfAnswers
    The number of answers to return. Default is 1.

    .PARAMETER OpenAiAuthToken
    The OpenAI API key. If not specified, the value of $ENV:OPENAI_AUTH_TOKEN is used.

    .PARAMETER Temperature
    The temperature of the model. Higher values means the model will take more risks. Default is 0.9.

    .PARAMETER Top_P
    The cumulative probability for top-p sampling. Default is 1.

    .EXAMPLE
    Get-PsChatAnswer "What is your name?" # Asks OpenAI Chat for its name.

    .EXAMPLE
    "Hello OpenAI" | Get-PsChatAnswer # Says hello to OpenAI using pipes.

    .EXAMPLE
    $dialog = @(
        @{ "role"="user"; "content"="Hello OpenAI. Can we talk Powershell?" },
        @{ "role"="assistant"; "content"="Hello! Of course, we can talk about PowerShell. What would you like to know or discuss?" },
        @{ "role"="user"; "content"="How does piping work?" }
        )
    Get-PsChatAnswer -InputObject $dialog -NoEnumerate # Asks OpenAI a question, based on previous messages.
    #>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline=$true)]
        [PSObject[]]$InputObject,
        [Switch]$NoEnumerate,
        [int]$NumberOfAnswers = 1,
        [string]$OpenAiAuthToken,
        [string]$Model,
        [decimal]$Temperature,
        [decimal]$Top_P
    )

    Begin {
        # Initialize any variables or resources needed for the function
        $authToken = if($OpenAiAuthToken) { $OpenAiAuthToken } else { $ENV:OPENAI_AUTH_TOKEN }
        $chatApi = [OpenAiChat]::new($authToken)
        if($Temperature) { $chatApi.Temperature = $Temperature }
        if($Top_P) { $chatApi.Top_p = $Top_P }
        if($NumberOfAnswers -ne 1) { $chatApi.N = $NumberOfAnswers }
        if($Model) { $chatApi.Model = $Model }
    }

    Process {
        # handle array of hashtable/object, eg. @( @{ "role"="user"; "content"="hello" } )
        if($NoEnumerate -and $InputObject -is [array]) {
            Write-Output -InputObject $chatApi.GetAnswer($InputObject)
        } else {
            # iterate over each item in the pipeline
            foreach ($item in $InputObject) {
                $messages = @()

                $answer = $null

                # handle string, eg. "hello"
                if($item -is [string]) {
                    $messages += [OpenAiChatMessage]::ToAssistant($item)
                    $answer = $chatApi.GetAnswer($messages)
                }

                # handle hashtable/object, eg. @{ "role"="user"; "content"="hello" }
                if($item -is [Hashtable]) {
                    $messages += $item
                    $answer = $chatApi.GetAnswer($messages)
                }

                if($null -ne $answer) {
                    Write-Output -InputObject $answer
                }
            }
        }
    }

    End {
    }
}

function Invoke-PsChat {
    <#
    .SYNOPSIS
    Create an interactive chat session with OpenAI Chat Completion in Powershell.

    .DESCRIPTION
    This function creates an interactive chat session with OpenAI Chat Completion in Powershell.

    You can press 'h' in the chat to get help.

    Please note $ENV:OPENAI_AUTH_TOKEN must be set with a valid OpenAI API key.

    .PARAMETER Question
    The initial question to ask the OpenAI Chat. This parameter is optional.

    .PARAMETER Single
    Specifies that the execution will end after the response to the initial question.
    This parameter is optional.

    .PARAMETER PreLoad_Path
    Specifies the path to a JSON-file containing chat messages (useful for providing context).
    This parameter is optional.

    .PARAMETER PreLoad_Lock
    The preloaded messages will always be prefixed to the dialog, keeping the context.
    This parameter is optional.

    .PARAMETER AutoSave_Enabled
    Specifies whether the chat messages should be autosaved or not.
    This parameter is optional, and takes a Switch datatype.

    .PARAMETER AutoSave_Path
    Specifies the path (file name) to where autosaved chat messages should be stored.
    This parameter is optional.

    .PARAMETER WordCountWarning_Threshold
    Specifies the maximum number of words before a warning should be issued.
    This parameter is optional, and takes an Integer datatype. Its default value is 300 to minimize cost.
    You can you the 'z' command to compress the dialog into a single message.

    .PARAMETER OpenAiAuthToken
    The OpenAI API key. If not specified, the value of $ENV:OPENAI_AUTH_TOKEN is used.

    .PARAMETER Temperature
    The temperature of the model. Higher values means the model will take more risks. Default is 0.9.

    .PARAMETER Top_P
    The cumulative probability for top-p sampling. Default is 1.

    .EXAMPLE
    Invoke-PsChat "What is your name?" # Start a chat by asking OpenAI Chat for its name.

    .EXAMPLE
    Invoke-PsChat "What is your name?" -Single # Asks the question and quits.
    #>
	param(
        # Initial invocation parameters
        [Parameter(Position=0)][string]$Question,
        [Parameter(Position=1)][Switch]$Single,
        # API parameters
        [string]$OpenAiAuthToken,
        [decimal]$Temperature,
        [decimal]$Top_P,
        [bool]$Stream = $true,
        [Parameter(ValueFromRemainingArguments=$true)]
        [object[]]$AdditionalArguments
        )

    $options = [Options]::new()
    $options.AdditionalArguments = $AdditionalArguments
    $options.InitialQuestion = $Question
    $options.SingleQuestion = $Single

    # initialize the api
    $authToken = if($OpenAiAuthToken) { $OpenAiAuthToken } else { $ENV:OPENAI_AUTH_TOKEN }
    $chat = [PsChatUi]::new($authToken, $options)
    $chat.Stream = $Stream

    if($Temperature) { $chat.ChatApi.Temperature = $Temperature }
    if($Top_P) { $chat.ChatApi.Top_p = $Top_P }

    $chat.Start()
    return
}

function New-OpenAiChat {
    <#
    .SYNOPSIS
    Instantiates the OpenAiChat API wrapper for external use cases.

    .DESCRIPTION
    This function creates an instance of OpenAiChat, the internal wrapper class for the OpenAI Chat Completion API.

    .PARAMETER AuthToken
    The OpenAI API key to use for authentication.

    .EXAMPLE
    #>
    param(
        [string]$OpenAiAuthToken
    )

    # initialize the api
    $authToken = if($OpenAiAuthToken) { $OpenAiAuthToken } else { $ENV:OPENAI_AUTH_TOKEN }
    return [OpenAiChat]::new($authToken)
}
