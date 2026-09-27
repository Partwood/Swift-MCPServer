# Description
Provides operation for finding string occurences by specifying a regex pattern within file content. The search is always case insensitive. Returns locations found specifying the line number (starting at 1), character based offset and byte offset (using UTF8 chars)
## find_in_file
### Description
Allows caller to find a regex pattern in file content using case insensitive search.
### Arguments
*path* The directory where the file is located
*name* The name of the file
*find* The regex pattern to find in the file content
