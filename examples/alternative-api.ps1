param(
	[switch]$Dev
)

$script = {
	Invoke-PsChat -Api_Verbose $true `
		-Api_Model "WizardLM-30B-Uncensored.Q4_K_M" `
		-Api_Baseurl "http://local-llm:8000/v1/" `
		-Api_Temperature 0.6 `
		-Api_Stream $true `
		-Api_Max_Tokens 1024 `
		-Single `
		-Question "Hello, in what year was the first Star Wars movie released?"
}

# dev mode, use local code
if($Dev) {
	pwsh -NoProfile -Command {
		param($inScript)
		Remove-Module PsChat -ErrorAction SilentlyContinue
		$DebugPreference="Continue"
		Import-Module ../src/PsChat/PsChat.psd1 -Force
		Invoke-Expression $inScript
	} -args $script
	return
}

# prod mode, use installed module
Invoke-Command -ScriptBlock $script

