using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class Functions {
    [string]$Path
    [OpenAiChat]$ChatApi
    [bool]$Enabled = $true
    [object[]]$Names = @()

    [OpenAiChatMessage] PostOpenAiChatResponse([object]$messageDialog) {
        $message = $messageDialog.message
        $dialog = $messageDialog.dialog
        if(!$this.Enabled) { return $message }

        $openAiMessages = $dialog.AsOpenAiChatMessages()
        while($null -ne $message.FunctionCall)
        {            
            Write-Debug "Function call: $($message.FunctionCall.Name)"

            # call function that returns object
            $result = $this.InvokePsFunction($message.FunctionCall.Name, $message.FunctionCall.Arguments)

            # add function result to existing messages
            $openAiMessages += [OpenAiChatMessage]::FromFunction($message.FunctionCall.Name, $result)

            # call open ai again
            $message = $this.ChatApi.GetAnswer($openAiMessages)
        }

        # return final non-function-call message
        return $message
    }
    
    [object] InvokePsFunction($name, $arguments) {
        $func = Get-Command $name
        if($null -eq $func) {
            throw "Function '$name' not found"
        }

        return Invoke-Command -ScriptBlock { param($command, $params) & $command @params } -ArgumentList $name, $arguments
    }

    [Dialog] BeforeChatLoop([Dialog]$dialog) {
        if (!$this.Enabled) { return $dialog }

        # $scriptPath = "./myscript.ps1"
        # $scriptPath = Resolve-Path -Path $scriptPath
        # [OutHelper]::Info("Functions being loaded from $scriptPath.")
        # . $scriptPath

        $functions = Get-Command -CommandType Function
        $chatFunctions = @()
        # $importedFunctions = $functions | Where-Object { $_.ScriptBlock.File -eq $scriptPath }
        $importedFunctions = $functions | Where-Object { $this.Names.Contains($_.Name) }
        
        foreach ($func in $importedFunctions) {
            # get name and type
            $funcName = $func.Name
            $helpContent = Get-Help -Name $funcName
            $funcDesc = $helpContent.Details.Description.Text
            if($null -eq $funcDesc) {
                $funcDesc = ""
            }

            $chatFunction = @{
                "name" = $funcName
                "description" = $funcDesc
                "parameters" = @{
                    "type" = "object"
                    "properties" = @{}
                    "required" = @()
                }
            }

            $paramHelp = $helpContent.Syntax.SyntaxItem.Parameter
            foreach ($param in $func.Parameters.Values) {
                # check for system/default parameters
                if ($param.Attributes.Position -eq [Int32]::MinValue) {
                    continue
                }

                # get name, type and description
                $paramName = $param.Name
                $paramType = $param.ParameterType.Name.ToLower()
                switch($paramType) {
                    "int32" { $paramType = "integer" }
                    "int64" { $paramType = "integer" }
                    "boolean" { $paramType = "boolean" }
                    default { $paramType = "string" }
                }
                $paramRequired = $param.Attributes.Mandatory
                $paramDescription = ($paramHelp | Where-Object name -EQ $paramName).description.text
                if($null -eq $paramDescription) {
                    $paramDescription = ""
                }
                # Write-Debug " - Parameter: Name=$paramName, Type=$paramType, Required=$paramAttribute, Desc=$paramDescription"

               $chatFunction.parameters.properties.$paramName = @{
                   "type" = $paramType
                   "description" = $paramDescription
               }
               if($paramRequired) {
                   $chatFunction.parameters.required += $paramName
               }
            }

            $chatFunctions += $chatFunction            
        }

        $this.ChatApi.Functions = $chatFunctions
        
        Write-Debug "$($this.ChatApi.Functions | ConvertTo-Json -Depth 10)"
        # Display the functions
        # [OutHelper]::Info("$yourFunctions")

        #$this.Path = if($this.Path) { $this.Path } else { $this.GetName() }
        #[OutHelper]::Info("AutoSaving to $($this.Path)")
        [OutHelper]::Info("Functions activated.")
        return $dialog
    }
}