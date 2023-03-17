using module "..\Private\OutHelper.psm1"

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
    [object] Invoke([object]$messages) {
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

        return $this.InvokeRequestObject($body)
    }

    # requestObject is a object/hashtable with the full request body
    [object] InvokeRequestObject([object]$requestObject) {
        $url = "https://api.openai.com/v1/chat/completions"

        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Content-Type", "application/json")
        $headers.Add("Authorization", "Bearer $($this.AuthToken)")

        $body = $requestObject | ConvertTo-Json -Depth 10

        $response = $null
        try {
            Write-Debug "Request:`n$body"
            $response = Invoke-RestMethod -Method 'POST' -Uri $url -Headers $headers -Body $body
            Write-Debug "`n`nResponse:`n$($response | ConvertTo-Json -Depth 10)"
            return $response
        } catch {
            [OutHelper]::NonCriticalError("An error occurred: $($_.Exception.Message)")
            [OutHelper]::NonCriticalError("Request:`n$body")
            [OutHelper]::NonCriticalError("Response:`n$($response | ConvertTo-Json -Depth 10)")
            return $null
        }
    }

    [string] Ask([string]$message) {
        return $this.GetAnswer(@([OpenAiChatMessage]::ToAssistant($message)))
    }

    [object] GetAnswer([object]$messages) {
        $response = $this.Invoke($messages)
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