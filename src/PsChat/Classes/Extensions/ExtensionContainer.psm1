using module "..\Dialog.psm1"
using module "..\OpenAiChat.psm1"
using module "..\Options.psm1"
using module "..\..\Private\OutHelper.psm1"

class ExtensionContainer {
    [OpenAiChat]$ChatApi
    [Options]$Options
    [object[]]$Extensions

    ExtensionContainer($chatApi, $options, $extensions) {
        $this.ChatApi = $chatApi
        $this.Options = $options
        $this.Extensions = $extensions
        $this.InjectOptionalProperties()
        $this.InitializeParameters()
    }

    # If Extension has a property of type OpenAiChat or Options, inject the instance
    InjectOptionalProperties() {
        $this.Extensions | ForEach-Object {
            $type = $_.GetType()
            $props = $type.GetProperties()
            foreach($prop in $props) {
                if($prop.PropertyType -eq [OpenAiChat]) {
                    $prop.SetValue($_, $this.ChatApi)
                }
                if($prop.PropertyType -eq [Options]) {
                    $prop.SetValue($_, $this.Options)
                }
            }
        }
    }

    # Inject additional parameters from the command line, e.g. -WordCountWarning_Threshold 1000
    InitializeParameters() {
        foreach($ext in $this.Extensions) {
            $type = $ext.GetType()
            Write-Debug "ExtensionContainer: Loaded $($type.Name)"
            $opt = $this.Options.AdditionalArguments
            for($i = 0; $i -lt $opt.Length; $i+=2) {
                $optName = $opt[$i] # -ExtenionName_PropertyName
                if(!($optName -is [string])) {
                    [OutHelper]::NonCriticalError("ExtensionContainer: Parameter name must be a String: $($optName)")
                    continue
                }

                if(!$optName.StartsWith("-")) {
                    continue
                }
                $optName = $optName.Substring(1)

                if($optName.IndexOf("_") -eq -1 -or $optName.Split("_")[0] -ne $type.Name) {
                    # Write-Debug "ExtensionContainer: Skipping $($optName)"
                    continue
                }

                $propName = $optName.Split("_")[1]
                $propValue = $opt[$i+1]

                $prop = $ext.GetType().GetProperty($propName)
                if($prop) {
                    Write-Debug "ExtensionContainer: Setting $($propName) on $($type.Name) with value: $($propValue)"
                    $prop.SetValue($ext, $propValue)
                } else {
                    [OutHelper]::NonCriticalError("ExtensionContainer: $($prop.Name) not found on $($type.Name)")
                }
            }
        }
    }

    [object] Invoke([string]$eventName, [object]$inputObject) {
        $outputObject = $inputObject
        $this.Extensions | ForEach-Object {
            $method = $_.GetType().GetMethod($eventName)
            if($method) {
                Write-Debug "ExtensionContainer: Invoking $($method.Name) on $($_.GetType().Name)"
                $arguments = @( $inputObject )
                $outputObject = $method.Invoke($_, $arguments)
            }
        }
        return $outputObject
    }
}