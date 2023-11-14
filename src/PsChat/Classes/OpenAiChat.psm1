using module "..\Private\OutHelper.psm1"
using namespace System
using namespace System.Text
using namespace System.IO
using namespace System.Net.Http
using namespace System.Net.Http.Formatting
using namespace System.Net.Http.Headers
using namespace System.Web
using namespace System.Web.Extensions

class OpenAiChatFunctionCall {
    [string]$Name
    [object]$Arguments

    static [OpenAiChatFunctionCall] Parse([object]$rawFunctionCall) {
        $fc = [OpenAiChatFunctionCall]::new()
        $fc.Name = $rawFunctionCall.name
        #Write-Debug "$($rawFunctionCall.arguments), type=$($rawFunctionCall.arguments.GetType())"
        if($rawFunctionCall.arguments -ne "()") {
            try {
                $fc.Arguments = $rawFunctionCall.arguments | ConvertFrom-Json -AsHashtable
            } catch {
                Write-Debug "Failed to parse arguments: $($_)"
            }
        }
        #Write-Debug "Successfully parsed function call: $($fc | ConvertTo-Json -Depth 10)"
        return $fc
    }
}

class OpenAiChatMessage {
    [string]$Role
    [string]$Content
    [OpenAiChatFunctionCall]$FunctionCall = $null
    [OpenAiChatMessage[]]$AltChoices = @()
    
    OpenAiChatMessage() {
    }

    OpenAiChatMessage([string]$role, [string]$content) {
        $this.Role = $role
        $this.Content = $content
    }

    [object] AsRaw() {
        $raw = @{
            "role" = $this.Role
            "content" = $this.Content
        }
        if($this.FunctionCall) {
            $raw.name = $this.FunctionCall.Name
        }
        return $raw
    }

    static [OpenAiChatMessage] ParseChoices([object[]]$rawMessages) {
        if($rawMessages.Count -eq 0) {
            return $null
        }

        $messages = @()
        foreach($rawMessage in $rawMessages) {
            $messages += [OpenAiChatMessage]::Parse($rawMessage)
        }
        $message = $messages[0]
        if($messages.Count -gt 1) {
            $message.AltChoices = $messages[1..($messages.Count-1)]
        }
        return $message
    }

    static [OpenAiChatMessage] Parse([object]$rawMessage) {
        $message = [OpenAiChatMessage]::new($rawMessage.role, $rawMessage.content)
        if($rawMessage.function_call) {
            $message.FunctionCall = [OpenAiChatFunctionCall]::Parse($rawMessage.function_call)
        }
        return $message
    }

    static [OpenAiChatMessage] FromUser([string]$message) {
        return [OpenAiChatMessage]::new("user", $message)
    }

    static [OpenAiChatMessage] FromFunction([string]$functionName, [object]$contentObject) {
        $contentJson = $contentObject | ConvertTo-Json -Depth 10
        $message = [OpenAiChatMessage]::new("function", $contentJson)
        $message.FunctionCall = [OpenAiChatFunctionCall]::new()
        $message.FunctionCall.Name = $functionName
        return $message
    }

    static [OpenAiChatMessage] FromAssistant([string]$message) {
        return [OpenAiChatMessage]::new("assistant", $message)
    }
}

class OpenAiResponseReader {
}

class OpenAiStreamingResponseReader {
    # delegate to call on each delta
}

class OpenAiChat {
    [string]$AuthToken
    [string]$Model = "gpt-3.5-turbo"
    [decimal]$Temperature
    [decimal]$Top_p
    [int]$N
    [HttpClient]$httpClient
    [string]$httpContentType = "application/json"
    [bool]$_debug = $false
    [string]$Baseurl = "https://api.openai.com/v1/"
    [bool]$Stream = $false
    [object]$Functions
    [int]$Max_Tokens = 0
    [object]$Response_Format

    OpenAiChat([string]$authToken) {
        $this.AuthToken = $authToken
        if(!$this.AuthToken) {
            throw "OpenAiChat requires an auth token (authToken argument on constructor)"
        }
    }

    [object] ChatCompletion([OpenAiChatMessage[]]$messages, [Func[HttpResponseMessage, object]]$success) {
        # translate OpenAiChatMessages to raw json-ready messages
        $rawMessages = @()
        $messages | ForEach-Object {
            $rawMessages += $_.AsRaw()
        }

        # construct body
        $body = @{
            "model" = $this.Model
            "messages" = $rawMessages
        }
        if($this.Functions) {
            $body.functions = $this.Functions
        }

        # set optional parameters for the request
        if($this.Temperature) { $body.temperature = $this.Temperature }
        if($this.Top_p) { $body.top_p = $this.Top_p }
        if($this.N) { $body.n = $this.N }
        if($this.Stream) {
            $body.stream=$true
        }
        if($this.Max_Tokens -ne 0) {
            $body.max_tokens = $this.Max_Tokens
        }
        if($this.Response_Format) {
            $body.response_format = $this.Response_Format | ConvertTo-Json
        }

        return $this.InvokeRequestObject("chat/completions", $body, $success)
    }

    # call the api, requestObject is a object/hashtable with the full request body
    [object] InvokeRequestObject($url, [object]$requestBody, [Func[HttpResponseMessage, object]]$success) {
        # $useStream = $true
        $url = "$($this.Baseurl)$url"

        $headers = @{
            "Authorization" = "Bearer $($this.AuthToken)"
        }

        $requestBodyJson = $requestBody | ConvertTo-Json -Depth 10

        $response = $null
        if($this._debug) {
            Write-Debug "Request:`n$requestBodyJson"
        }

        if(!$this.httpClient) {
            $this.httpClient = [HttpClient]::new()
        }

        # create an HTTP request with a range header to receive only a specific chunk of data
        $request = [HttpRequestMessage]::new([HttpMethod]::Post, [Uri]::new($url))
        foreach($key in $headers.Keys) {
            $request.Headers.Add($key, $headers[$key])
        }
        if($this.Stream) {
            $request.Headers.Range = [RangeHeaderValue]::new(0, 1024)
        }
        $request.Content = [StringContent]::new($requestBodyJson, [Encoding]::UTF8, $this.httpContentType)

        # send the HTTP request and get the response
        try {
            $response = $this.httpClient.SendAsync($request, [HttpCompletionOption]::ResponseHeadersRead).Result
            if(!$response.IsSuccessStatusCode) {
                throw "An error occurred: $($response.StatusCode)"
            }
            
            if($success) {
                if($this._debug) {
                    Write-Debug "Response:`n$($response | ConvertTo-Json -Depth 10)"
                }
                return $success.Invoke($response)
            } else {
                Write-Debug "Success handler not provided (is null)"
            }
        } catch {
            $failureBody = ""
            # try to get the response body
            try {
                $failureBody = $response.Content.ReadAsStringAsync().Result
            } catch {
            }
            if($this._debug) {
                [OutHelper]::NonCriticalError("Error while calling api", $_)    
                [OutHelper]::NonCriticalError("Request:`n$requestBodyJson")
                [OutHelper]::NonCriticalError("Response:`n$failureBody")
            }

            if($failureBody.StartsWith("{")) {
                $failure = $failureBody | ConvertFrom-Json
                [OutHelper]::NonCriticalError("$($failure.error.message)")
            } else {
                [OutHelper]::NonCriticalError("$($failureBody)")
            }
        }

        return $null
    }

    [object] ApplyDelta($obj, $objDelta) {
        #Write-Debug "obj-before: $($obj | ConvertTo-Json -Depth 10)"
        foreach($nameValue in $objDelta.PSObject.Properties) {
            $key = $nameValue.Name
            $value = $nameValue.Value
            if($null -eq $value) {
                $value = ""
            }

            if(!$obj.$key) {
                $obj.$key = $value
            } else {
                if($value -is [PSObject]) {
                    $obj.$key = $this.ApplyDelta($obj.$key, $value)                           
                } else {
                    $obj.$key += $value
                }    
            }
        }
        #Write-Debug "obj-after: $($obj | ConvertTo-Json -Depth 10)"
        return $obj
    }

    # calls the api and streams the response as it comes in
    [object] ReadAndStreamResponse($response) {

        $choices = @{}
        $streamReader = [StreamReader]::new($response.Content.ReadAsStreamAsync().Result)
        $firstContent = $true
        try {
            # read the response content as a stream of JSON data
            $dataPrefix = "data: "
            while (!$streamReader.EndOfStream)
            {
                # allow escape from streaming
                if ([Console]::KeyAvailable) {
                    $key = [Console]::ReadKey($true)
                    if($key.Key -eq [ConsoleKey]::Escape) {
                        break
                    }
                }

                # each line will begin with "data: ", the final line will be "data: [DONE]"
                $line = $streamReader.ReadLine()
                if (!$line.StartsWith($dataPrefix)) {
                    continue
                }
                $line = $line.Substring($dataPrefix.Length)
                if($line -eq "[DONE]") {
                    break
                }
                # [OutHelper]::Gpt($line)
                if($this._debug) {
                    Write-Host "($line)" -ForegroundColor DarkGray -NoNewLine
                }

                $chunk = $line | ConvertFrom-Json
                if(!$chunk.choices -or $chunk.choices.Count -lt 1) {
                    continue
                }

                # update the choices array with the new choice
                foreach($choice in $chunk.choices) {
                    # $delta = $chunk.choices[0].delta # {"content":" you"}
                    # $index = "i$($chunk.choices[0].index)" # 0
                    $delta = $choice.delta # eg. {"content":" you"}
                    $index = "i$($choice.index)" # eg. 0
    
                    $c = $choices[$index] 
                    if($null -eq $c) {
                        $c = $choices[$index] = @{}
                        $c.content = ""
                    }
    
                    $contentPreDelta = $c.content
                    $c = $choices[$index] = $this.ApplyDelta($c, $delta)
    
                    # only stream first choice (index: 0)
                    if($index -ne "i0") {
                        continue
                    }

                    # output content-delta if any
                    $contentDelta = $c.content.Substring($contentPreDelta.Length)
                    if($contentDelta -ne "") {
                        if($firstContent) {
                            [OutHelper]::GptDelta("", $true) # writes GPT:
                            $firstContent = $false
                        }
                        [OutHelper]::GptDelta($contentDelta, $false)
                    }    
                }
            }
        } catch {
            [OutHelper]::NonCriticalError("Error while streaming response", $_)    
        } finally {
            $streamReader.Dispose()
        }

        if(!$firstContent) {
            [OutHelper]::GptDelta("`n", $false)
        }

        Write-Debug "Choices: $($choices | ConvertTo-Json -Depth 10)"

        return [OpenAiChatMessage]::ParseChoices($choices.Values)
    }

    [string] Ask([string]$message) {
        return $this.GetAnswer(@([OpenAiChatMessage]::ToAssistant($message))).Content
    }

    [object] ReadResponseAsObject([HttpResponseMessage]$response) {
        if($this.PsClassic()) {
            return [HashTable]($response.Content.ReadAsStringAsync().Result | ConvertFrom-Json)
        } else {
            return $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json -AsHashtable
        }
    }

    [OpenAiChatMessage] ReadChoices([HttpResponseMessage]$response) {
        $res = $this.ReadResponseAsObject($response)
        # Write-Debug $($res | ConvertTo-Json -Depth 10)
        if($null -eq $res) {
            return $null
        }

        return [OpenAiChatMessage]::ParseChoices($res.choices.message)
    }

    [OpenAiChatMessage] GetAnswer([OpenAiChatMessage[]]$messages) {
        $cb = if($this.Stream) {
            # this is purposely kept clumsy to support PS 5.1 (which may be removed in the future)
            [System.Func[HttpResponseMessage, object]]{param($response) return $this.ReadAndStreamResponse($response) }
        } else {
            [System.Func[HttpResponseMessage, object]]{param($response) return $this.ReadChoices($response) }
        }
        $message = $this.ChatCompletion($messages, $cb)
        # Write-Debug "$($message.AltChoices.Count) alt choices"

        return $message
    }

    [bool] PsClassic() {
        return (Get-Host).Version.Major -lt 6
    }
}