# Description
Provides operations for appending content to the end of a file.

## append
### Description
Appends the provided content to the end of a file. Should not be run in parallel with other operations, file should be read back in for validation.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*content* The content that should be inserted.<br>
