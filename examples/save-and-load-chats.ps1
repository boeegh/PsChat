# auto save chat messages to a file
Invoke-PsChat -AutoSave_Enabled $true -AutoSave_Path ./chat.json

# load chat messages from a file
Invoke-PsChat -PreLoad_Path ./chat.json

# the json reflect the request body of the api call (minus the model specification)
