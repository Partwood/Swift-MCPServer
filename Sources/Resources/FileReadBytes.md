# Description
Provides operation for reading a file by specifying a byte offset and byte length.

## read_bytes
### Description
Returns a part of the content of a file, using a byte offset (*offset*) from start and the number of bytes (*length*) to read.
### Arguments
*path* The directory where the file is located
*name* The name of the file
*offset* The integer number of bytes from the start
*length* The integer number of bytes to read from the provided offset value. Should not exceed 8192
