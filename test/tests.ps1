# function Get-Random-Number-Test {
#   Invoke-PsChat -Question "Give me a random number" -Single -Functions_Names @("Get-Random-Number") >> ./out.tmp
#   Write-Output "$(cat ./out.tmp)"
#   rm ./out.tmp
# }
$NAME_QUESTION = "What is your name?"
$NAME_ANSWER = "OpenAI"

function Get-PsChatAnswer-Direct-String-Input {
  (Get-PsChatAnswer -Temperature 0.1 $NAME_QUESTION).Contains($NAME_ANSWER)
}

function Get-PsChatAnswer-Piped-String-Input {
  ($NAME_QUESTION | Get-PsChatAnswer -Temperature 0.1).Contains($NAME_ANSWER)
}

function Get-PsChatAnswer-Object-As-Input {
  $message = @{ "role"="user"; "content"=$NAME_QUESTION }
  (Get-PsChatAnswer -InputObject $message -Temperature 0.1).Contains($NAME_ANSWER)
}

function Get-PsChatAnswer-Object-As-Input-Array {
  $message = @(
    @{ "role"="user"; "content"="Please answer using markdown." }
    @{ "role"="user"; "content"=$NAME_QUESTION }
  )
  (Get-PsChatAnswer -InputObject $message -Temperature 0.1).Contains($NAME_ANSWER)
}

# todo:
# * extensions in non-interaction mode
# * object output from functions
# * token calculation
# *  