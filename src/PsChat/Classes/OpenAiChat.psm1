using module "..\Private\OutHelper.psm1"
using namespace System
using namespace System.Text
using namespace System.IO
using namespace System.Net.Http
using namespace System.Net.Http.Formatting
using namespace System.Net.Http.Headers
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

class OpenAiChat {
    [string]$AuthToken
    [string]$Model = "gpt-3.5-turbo"
    [decimal]$Temperature
    [decimal]$Top_p
    [int]$N

    OpenAiChat([string]$authToken) {
        $this.AuthToken = $authToken
        if(!$this.AuthToken) {
            throw "OpenAiChat requires an auth token (authToken argument on constructor)"
        }
    }

    # messages is an array of objects with 'role' and 'content' properties
    # 'content' is url encoded before sending to the API
    [object] Invoke([object]$messages, [bool]$useStream) {
        $encoded = @()
        $messages | ForEach-Object {
            $encoded += @{ "role" = $_.role; "content" = [System.Web.HttpUtility]::UrlEncode($_.content); }
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

        return $this.InvokeRequestObject($body, $useStream)
    }

    # requestObject is a object/hashtable with the full request body
    [object] InvokeRequestObject([object]$requestObject, [bool]$useStream) {
        # $useStream = $true
        $url = "https://api.openai.com/v1/chat/completions"

        $headers = @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $($this.AuthToken)"
        }

        if($useStream) {
            $requestObject.stream=$true
        }
        $body = $requestObject | ConvertTo-Json -Depth 10

        $response = $null
        try {
            Write-Debug "Request:`n$body"
            # [OutHelper]::Gpt("Request:`n$body")

            if($useStream) {
                return $this.InvokeRequestObjectStream($url, $headers, $body)
            } else {
                $response = Invoke-RestMethod -Method 'POST' -Uri $url -Headers $headers -Body $body
            }

            Write-Debug "`n`nResponse:`n$($response | ConvertTo-Json -Depth 10)"
            # [OutHelper]::Gpt("`n`nResponse:`n$($response | ConvertTo-Json -Depth 10)")
            return $response
        } catch {
            [OutHelper]::NonCriticalError("$($_.Exception)")
            [OutHelper]::NonCriticalError("Request:`n$body")
            [OutHelper]::NonCriticalError("Response:`n$($response | ConvertTo-Json -Depth 10)")
            return $null
        }
    }

    [object] InvokeRequestObjectStream($url, $headers, $body) {
        # [OutHelper]::Gpt("STREAMING")

        $client = [HttpClient]::new()

        # create an HTTP request with a range header to receive only a specific chunk of data
        $request = [HttpRequestMessage]::new([HttpMethod]::Post, [Uri]::new($url))
        foreach($key in $headers.Keys) {
            if($key -eq "Content-Type") {
                continue
            }
            $request.Headers.Add($key, $headers[$key])
        }
        $request.Headers.Range = [RangeHeaderValue]::new(0, 1024)
        $request.Content = [StringContent]::new($body, [Encoding]::UTF8, $headers["Content-Type"])

        # send the HTTP request and get the response
        $response = $client.SendAsync($request, [HttpCompletionOption]::ResponseHeadersRead).Result
        if(!$response.IsSuccessStatusCode) {
            throw "An error occurred: $($response.StatusCode)"
        }

        $choices = @{}
        [OutHelper]::GptDelta("", $true) # writes GPT:
        try {
            # read the response content as a stream of JSON data
            $streamReader = New-Object System.IO.StreamReader($response.Content.ReadAsStreamAsync().Result)
            $dataPrefix = "data: "
            while (!$streamReader.EndOfStream)
            {
                $line = $streamReader.ReadLine()
                if (!$line.StartsWith($dataPrefix)) {
                    continue
                }
                $line = $line.Substring($dataPrefix.Length)
                if($line -eq "[DONE]") {
                    break
                }
                # [OutHelper]::Gpt($line)

                $chunk = $line | ConvertFrom-Json
                if($chunk.choices -and $chunk.choices.Count -eq 1) { # assuming 1 choice per chunk
                    # update the choices array with the new choice
                    $delta = $chunk.choices[0].delta # {"content":" you"}
                    $index = "i$($chunk.choices[0].index)" # 0

                    if(!$choices[$index]) {
                        $choices[$index] = @{}
                    }

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

                        if($index -eq "i0" -and $key -eq "content") {
                            if($initalValue) {
                                $value = $value.TrimStart()
                            }
                            [OutHelper]::GptDelta($value, $false)
                        }
                    }
                }
            }
        } finally {
            # $streamReader.Dispose()
        }
        [OutHelper]::GptDelta("`n", $false)

        # [OutHelper]::Gpt(($choices | ConvertTo-Json -Depth 10))

        $answers = @()
        foreach($choice in $choices.Values) {
            $answers += $choice.content.Trim()
        }
        # [OutHelper]::Gpt(($answers | ConvertTo-Json -AsArray -Depth 10))

        return $answers
    }

    [string] Ask([string]$message) {
        return $this.GetAnswer(@([OpenAiChatMessage]::ToAssistant($message)))
    }

    [object] GetStreamedAnswer([object]$messages) {
        $response = $this.Invoke($messages, $true)
        if($null -ne $response) {
            if($response.Length -gt 1) {
                return $response
            } else {
                return $response[0]
            }
        } else {
            return $null
        }
    }

    [object] GetAnswer([object]$messages) {
        $response = $this.Invoke($messages, $false)
        if($null -ne $response) {
            # if multiple choices are requested, return an array of strings
            if($this.N -gt 1) {
                Write-Debug "N=$($this.N), returning array of $($response.choices.length) strings"
                return $response.choices | ForEach-Object { [System.Web.HttpUtility]::UrlDecode($_.message.content.Trim()) }
            }

            return [System.Web.HttpUtility]::UrlDecode($response.choices.message.content.Trim())
        } else {
            return $null
        }
    }
}