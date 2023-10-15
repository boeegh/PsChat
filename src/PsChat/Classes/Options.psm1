class Options {
    [object[]]$AdditionalArguments
    [string]$InitialQuestion
    [bool]$SingleQuestion
    [bool]$SkipQuestion
    [bool]$NonInteractive
}

Enum ResultType {
    None
    Objects
    LastAnswerAsText
}