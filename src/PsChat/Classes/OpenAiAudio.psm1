using module "..\Private\OutHelper.psm1"
using namespace System
using namespace System.Text
using namespace System.IO
using namespace System.Net.Http
using namespace System.Net.Http.Formatting
using namespace System.Net.Http.Headers
using namespace System.Web
using namespace System.Web.Extensions

class OpenAiAudioSpeechRequest {
    [string]$Model = "tts-1"
    [string]$Input = ""
    [string]$Voice = "alloy"
    [string]$Response_Format = "mp3"
    [decimal]$Speed = 1

    [string] AsJson() {
        # make new object that contains properties in lowercase
        $obj = [PSCustomObject]::new()
        $props = $this | Get-Member -MemberType Property
        foreach($prop in $props) {
            $obj | Add-Member -MemberType NoteProperty -Name $prop.Name.ToLower() -Value $this.$($prop.Name)
        }
        return $obj | ConvertTo-Json -Depth 10
    }
}

class OpenAiAudio {
    [string]$AuthToken
    [HttpClient]$httpClient
    [bool]$_debug = $false
    [string]$Baseurl = "https://api.openai.com/v1/"
    [string]$httpContentType = "application/json"

    OpenAiAudio([string]$authToken) {
        $this.AuthToken = $authToken
        if(!$this.AuthToken) {
            throw "OpenAiAudio requires an auth token (authToken argument on constructor)"
        }
    }

    [HttpRequestMessage] GetHttpRequestMessage([string]$url, [object]$requestObject) {
        $requestBodyJson = $requestObject.AsJson()
        if($this._debug) {
            Write-Debug "Request:`n$requestBodyJson"
        }
        $url = "$($this.Baseurl)$url"
        $headers = @{ "Authorization" = "Bearer $($this.AuthToken)" }
        $response = $null

        if(!$this.httpClient) {
            $this.httpClient = [HttpClient]::new()
        }

        $request = [HttpRequestMessage]::new([HttpMethod]::Post, [Uri]::new($url))
        foreach($key in $headers.Keys) {
            $request.Headers.Add($key, $headers[$key])
        }
        $request.Content = [StringContent]::new($requestBodyJson, [Encoding]::UTF8, $this.httpContentType)
        return $request
    }

    [HttpResponseMessage] GetResponse($httpRequest) {
        $response = $null
        try {
            $response = $this.httpClient.SendAsync($httpRequest, [HttpCompletionOption]::ResponseHeadersRead).Result
            if(!$response.IsSuccessStatusCode) {
                throw "An error occurred: $($response.StatusCode)"
            }
        
            if($this._debug) {
                Write-Debug "Response:`n$($response | ConvertTo-Json -Depth 10)"            
            }

            return $response
        } catch {
            $failureBody = ""
            # try to get the response body
            try {
                $failureBody = $response.Content.ReadAsStringAsync().Result
            } catch {
            }
            if($this._debug) {
                [OutHelper]::NonCriticalError("Error while calling api", $_)    
                [OutHelper]::NonCriticalError("Request:`n$($httpRequest.Body)")
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

    [byte[]] GetBytes([string]$url, [OpenAiAudioSpeechRequest]$request) {
        $httpRequest = $this.GetHttpRequestMessage($url, $request)
        $response = $this.GetResponse($httpRequest)
        $bytes = $response.Content.ReadAsByteArrayAsync().Result
        return $bytes
    }

    SpeechToFile([OpenAiAudioSpeechRequest]$request, [string]$filePath) {
        $bytes = $this.GetBytes("audio/speech", $request)
        [File]::WriteAllBytes($filePath, $bytes)
    }
}