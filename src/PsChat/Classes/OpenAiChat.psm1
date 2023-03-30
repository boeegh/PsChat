using module "..\Private\OutHelper.psm1"
using namespace System
using namespace System.Text
using namespace System.IO
using namespace System.Net.Http
using namespace System.Net.Http.Formatting
using namespace System.Net.Http.Headers
using namespace System.Web
using namespace System.Web.Extensions

class OpenAiChatMessage {
    [string]$Role
    [string]$Content

    OpenAiChatMessage([string]$role, [string]$content) {
        $this.Role = $role
        $this.Content = $content
    }

    static [OpenAiChatMessage] ToAssistant([string]$message) {
        return [OpenAiChatMessage]::new("user", $message)
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

    OpenAiChat([string]$authToken) {
        $this.AuthToken = $authToken
        if(!$this.AuthToken) {
            throw "OpenAiChat requires an auth token (authToken argument on constructor)"
        }
    }

    # messages is an array of objects with 'role' and 'content' properties
    [object] ChatCompletion([object]$messages, [bool]$useStream, [Func[HttpResponseMessage, object]]$success) {
        $encoded = @()
        $messages | ForEach-Object {
            $encoded += @{ "role" = $_.role; "content" = $_.content; }
        }

        # construct body
        $body = @{
            "model" = $this.Model
            "messages" = $encoded
        }

        # set optional parameters for the request
        if($this.Temperature) { $body.temperature = $this.Temperature }
        if($this.Top_p) { $body.top_p = $this.Top_p }
        if($this.N) { $body.n = $this.N }
        if($useStream) {
            $body.stream=$true
        }

        return $this.InvokeRequestObject("chat/completions", $body, $useStream, $success)
    }

    # call the api, requestObject is a object/hashtable with the full request body
    [object] InvokeRequestObject($url, [object]$requestBody, [bool]$useStream, [Func[HttpResponseMessage, object]]$success) {
        # $useStream = $true
        $url = "$($this.Baseurl)$url"

        $headers = @{
            "Authorization" = "Bearer $($this.AuthToken)"
        }

        $requestBodyJson = $requestBody | ConvertTo-Json -Depth 10

        $response = $null
        try {
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
            if($useStream) {
                $request.Headers.Range = [RangeHeaderValue]::new(0, 1024)
            }
            $request.Content = [StringContent]::new($requestBodyJson, [Encoding]::UTF8, $this.httpContentType)

            # send the HTTP request and get the response
            $response = $this.httpClient.SendAsync($request, [HttpCompletionOption]::ResponseHeadersRead).Result
            if(!$response.IsSuccessStatusCode) {
                throw "An error occurred: $($response.StatusCode)"
            }

            if($success) {
                if($this._debug) {
                    Write-Debug "Response:`n$($response | ConvertTo-Json -Depth 10)"
                }
                return $success.Invoke($response)
            }
        } catch {
            $failureBody = ""
            # try to get the response body
            try {
                $failureBody = $response.Content.ReadAsStringAsync().Result
            } catch {
            }
            if($this._debug) {
                [OutHelper]::NonCriticalError("$($_)")
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

    # calls the api and streams the response as it comes in
    [object] ReadAndStreamResponse($response) {

        $choices = @{}
        [OutHelper]::GptDelta("", $true) # writes GPT:

        $streamReader = [StreamReader]::new($response.Content.ReadAsStreamAsync().Result)
        try {
            # read the response content as a stream of JSON data
            $dataPrefix = "data: "
            while (!$streamReader.EndOfStream)
            {
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
                if(!$chunk.choices -or $chunk.choices.Count -ne 1) {
                    continue
                }

                # update the choices array with the new choice
                $delta = $chunk.choices[0].delta # {"content":" you"}
                $index = "i$($chunk.choices[0].index)" # 0

                if(!$choices[$index]) {
                    $choices[$index] = @{}
                }

                # merge the delta into the choices array
                $initalValue = $false
                foreach($nameValue in $delta.PSObject.Properties) {
                    $key = $nameValue.Name
                    $value = $nameValue.Value

                    if(!$choices[$index].$key) {
                        $choices[$index].$key = $value
                        $initalValue = $true
                    } else {
                        $choices[$index].$key += $value
                    }

                    # output new content (delta) to user
                    if($index -eq "i0" -and $key -eq "content") {
                        if($initalValue) {
                            $value = $value.TrimStart()
                        }
                        [OutHelper]::GptDelta($value, $false)
                    }
                }
            }
        } finally {
            $streamReader.Dispose()
        }
        [OutHelper]::GptDelta("`n", $false)

        # convert the choices hashtable to an array of answers (strings)
        $answers = @()
        foreach($choice in $choices.Values) {
            $answers += $choice.content.Trim()
        }

        return $answers
    }

    [string] Ask([string]$message) {
        return $this.GetAnswer(@([OpenAiChatMessage]::ToAssistant($message)), $false)
    }

    [object] ReadResponseAsObject([HttpResponseMessage]$response) {
        return $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json -AsHashtable
    }

    [object] ReadChoices([HttpResponseMessage]$response) {
        $res = $this.ReadResponseAsObject($response)
        if($null -eq $res) {
            return $null
        }

        return $res.choices | ForEach-Object { $_.message.content.Trim() }
    }

    [object] GetAnswer([object]$messages) {
        return $this.GetAnswer($messages, $false)
    }

    [object] GetAnswer([object]$messages, $useStream) {
        $choices = if($useStream) {
            $this.ChatCompletion($messages, $true, $this.ReadAndStreamResponse)
        } else {
            $this.ChatCompletion($messages, $false, $this.ReadChoices)
        }

        if($null -ne $choices) {
            if($choices.Length -gt 1) {
                return $choices
            } else {
                return $choices[0]
            }
        }
        return $null
    }
}