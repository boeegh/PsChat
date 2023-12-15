# PsChat - OpenAIs ChatGPT for PowerShell
PsChat is a Powershell module that allows the user to use OpenAI Chat Completion in the shell. If you spend a lot of time in Powershell, this may be useful to you.

The module consists of two functions:
* `Invoke-PsChat` - Chat UI, similiar to OpenAI web interface
* `Get-PsChatAnswer` - Pipeable function that allows more direct access to the API

I made it to use and explore ChatGPT the place, I mostly find myself: In the shell.

The module requires OpenAI API access. You can get an API key from: https://platform.openai.com/signup

## News
* 2023-12-15 - Audio (TTS) support, see `SaveAudio` extension
* 2023-11-14 - Example of using [non-OpenAI API in examples](examples/alternative-api.ps1)
* 2023-10-22 - Better copy-paste support (press ALT-P + V)
* 2023-10-01 - Support for function calling, end-to-end tests

## Getting started
```Powershell
# install module from PSGallery
Install-Module PsChat -Force

# get an openai api key and put it in a env variable
$ENV:OPENAI_AUTH_TOKEN="my-secret-token"

# start a chat session
Invoke-PsChat
```

## Usage
```Powershell
# start a chat session with a question
Invoke-PsChat "Lets talk Powershell"

# ask single question
Invoke-PsChat "How is Powershell compared to Zsh" -Single

# ask single question using functions, result as PSObject
Invoke-PsChat -Single -Question "Whats the uptime?" `
     -Functions_Names @("Get-Uptime") `
     -NonInteractive

# does the same using Get-PsChatAnswer
Get-PsChatAnswer "What is your name?

# pipe in question
"Hello OpenAI" | Get-PsChatAnswer

# post an entire dialog to the api
$dialog = @(
    @{ "role"="user"; "content"="Hello OpenAI. Can we talk Powershell?" },
    @{ "role"="assistant"; "content"="Hello! Of course, we can talk about PowerShell. What would you like to know or discuss?" },
    @{ "role"="user"; "content"="How does piping work?" }
)
Get-PsChatAnswer -InputObject $dialog -NoEnumerate

# for parameters you can use Get-Help
Get-Help Invoke-PsChat
Get-Help Get-PsChatAnswer
```

## Screenshot(s)
Started using alias 'q':
![Screenshot of the chat UI.](/assets/Screenshot-Invoke-PsChat.png)

Asking for help (available commands) in the chat:
![Screenshot of the chat having pressed H.](/assets/Screenshot-In-Chat-Help.png)

## Examples
* [Bad Code Finder](examples/bad-code-finder.ps1): Powershell script that traverses source codes and uses GPT to find sensitive data. Usage: Download the ps1-file, run it (with $ENV:OPENAI_AUTH_TOKEN set) in a directory containing source code.
* [Dual Minded](examples/dual-minded.ps1): Dual-minded makes OpenAI have both sides of a conversation.
* [Save and Load](examples/save-and-load-chats.ps1): Simple examples of saving and preloading context for chats.
* [Alternative API](examples/alternative-api.ps1): Using another API, such as a local model using https://github.com/abetlen/llama-cpp-python/.

## Extensions
Extension-framework is wip, but a few built-in extensions are available:
* `AutoSave` - Saves the chat to json (which can later be loaded back in using `PreLoad`)
* `WordCountWarning` - Informs the user when a certain word-count is reached (for cost-saving purposes)
* `PreLoad` - Preloads messages from a file or string. Optionally "lock" the loaded messages
* `Commands` - In-chat commands, such as clipboard access and API settings
* `ShortTerm` - ShortTerm(Memory) starts pruning early messages when a certain word threshold is reached - in order to avoid token limit
* `Functions` - Allows OpenAI chat to call Powershell functions during an answer/chat-completion
* `Api` - Allows you to set chat-completion API parameters, such as base-url, model and temperature
* `SaveAudio` - NEW: Allows you generate audio using the TTS api. Requires ffmpeg (install it using homebrew, apt or choco)

Extensions can have multiple parameters, that can be set when calling `Invoke-PsChat`, such as `Invoke-PsChat -Api_Model "gpt-4"`.
With multiple parameters a Powershell alias can come in handy:
```Powershell
# setup function
function Invoke-PsChat-Yaml { Invoke-PsChat -Api_Model "gpt-4" -PreLoad_Prompt "Answer only with YAML" -PreLoad_Lock $true }

# define alias
New-Alias -Name q -Value Invoke-PsChat-Yaml -Force -Option AllScope -Description 'Usage: q "What is consciousness?"'

# usage
q "Describe the rules of tic-tac-toe?"
```

### List of extension parameters
All extension parameters are optional.
| Extension | Parameter | Type | Description |
| --- | --- | --- | --- |
| Api | Enabled | bool | Enable/disable extension. Defaults to `$true`. |
| Api | Verbose | bool | If `$true` writes out parameters on startup |
| Api | AuthToken | string | OpenAI auth token to use |
| Api | Model | string | Model name, eg. `gpt-4` |
| Api | Temperature | decimal | Model temperature |
| Api | Top_P | decimal | Model top_p |
| Api | Baseurl | string | Base url for model API |
| AutoSave | Enabled | bool | Enable/disable extension. Defaults to `$false`. |
| AutoSave | Path | string | Specifies the path the chat will be saved to, eg. `~/my-chat.json`. If not specified the path `./pschat-$(Get-Date -Format "yyyy-MM-dd-HHmmss").json` will be used. |
| Functions | Enabled | bool | Enable/disable extension. Defaults to `$true`. |
| Functions | Names | string[] | Powershell functions to expose in the chat. Eg. `@( "Get-Uptime" )` |
| PreLoad | Prompt | string | Simple prompt to start chat with. |
| PreLoad | Role | string | Role for `Prompt`, for OpenAI can be `user`, `assistant` or `system`. |
| PreLoad | Path | string | Load chat from this path eg. `./my-chat.json`. |
| PreLoad | Objects | object[] | Allows preloading based on PsObjects, eg. `@( @{ "Role"="system"; "Content"="Hi!"; "Locked"=$true } )` |
| PreLoad | Verbose | bool | Makes the extension more talkative. |
| PreLoad | Lock | bool | Locks the preloaded prompt/chat, so an extension like `ShortTerm` does not affect them. |
| SaveAudio | Enabled | bool | Enable/disable extension. Defaults to `$true`. |
| SaveAudio | Path | string | Output file path. Defaults to autogenerated based on timestamp. |
| SaveAudio | Model | string | Optional TTS model to use |
| SaveAudio | UserVoice | string | Maps to OpenAI voice parameter for users voice |
| SaveAudio | AssistantVoice | string | Maps to OpenAI voice parameter for assistants voice |
| SaveAudio | Response_Format | string | Maps to OpenAI Response_Format paramter |
| SaveAudio | Speed | decimal | Maps to OpenAI speed parameter |
| ShortTerm | Enabled | bool | Enable/disable extension. Defaults to `$true`. |
| ShortTerm | Verbose | bool | Makes the extension more talkative. |
| ShortTerm | Compress | bool | Compresses messages that are due to be removed. |
| ShortTerm | CompressPrompt | string | Prompt to use when compressing messages to be "forgotten". |
| ShortTerm | TokenCountThreshold | int | Number of (approx) tokens that triggers removal of the oldest messages. Defaults to model context size minus 1.000. |
| ShortTerm | WordCountThreshold | int | Same as TokenCountThreshold, but based on words. Considered deprecated. |

## Commands
Commands are extensions for the UI chat, such as changing the model on-the-fly. These are available when the user enters `'h'` in the chat.

## Dev notes
For development this approach seems to work best:
```Powershell
# open chat ui (talkative, with debug)
pwsh -NoProfile -Command { Remove-Module PsChat -Force; $DebugPreference="Continue"; Import-Module ./src/PsChat/PsChat.psd1 -Verbose -Force && Invoke-PsChat }

# get anwer (quiet)
pwsh -NoProfile -Command { Remove-Module PsChat -ErrorAction SilentlyContinue; Import-Module ./src/PsChat/PsChat.psd1 -Force && Get-PsChatAnswer "hello" }
```
