# PsChat - OpenAIs ChatGPT for PowerShell
PsChat is a Powershell module that allows the user to use OpenAI Chat Completion in the shell. If you spend a lot of time in Powershell, this may be useful to you.

The module consists of two functions:
* `Invoke-PsChat` - Chat UI, similiar to OpenAI web interface
* `Get-PsChatAnswer` - Pipeable function that allows more direct access to the API

I made it to use and explore ChatGPT the place, I mostly find myself: In the shell.

The module requires OpenAI API access. You can get an API key from: https://platform.openai.com/signup

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

# does the same using Get-PsChatAnswer
Get-PsChatAnswer "What is your name?"

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

## Extensions
Extension-framework is wip, but a few built-in extensions are available:
* `AutoSave` - Saves the chat to json (which can later be loaded back in)
* `WordCountWarning` - Informs the user when a certain word-count is reached (for cost-saving purposes)
* `PreLoad` - Preloads messages from a file or string. Optionally "lock" the loaded messages
* `Commands` - In-chat commands, such as clipboard access and API settings
* `ShortTerm` - ShortTerm(Memory) starts pruning early messages when a certain word threshold is reached - in order to avoid token limit

## Commands
Commands are extensions for the UI chat. These are available when the user enters `'h'` in the chat.

## Dev notes
For development this approach seems to work best:
```Powershell
# open chat ui (talkative, with debug)
pwsh -NoProfile -Command { Remove-Module PsChat -Force; $DebugPreference="Continue"; Import-Module ./src/PsChat/PsChat.psd1 -Verbose -Force && Invoke-PsChat }

# get anwer (quiet)
pwsh -NoProfile -Command { Remove-Module PsChat -ErrorAction SilentlyContinue; Import-Module ./src/PsChat/PsChat.psd1 -Force && Get-PsChatAnswer "hello" }
```
