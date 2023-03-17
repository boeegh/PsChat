# auto save chat messages to a file
Invoke-PsChat -AutoSave -AutoSavePath ./chat.json

# load chat messages from a file
Invoke-PsChat -PreLoadMessagesPath ./chat.json

# the json reflect the request body of the api call (minus the model specification)
