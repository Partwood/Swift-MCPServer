# Description
Provides operation for reading a file by specifying a line offset and amount of lines (*length*), with length limited to at most 10

## read_lines
### Description
Returns a part of the content of a file, using a line offset (*offset*) from start and the number of lines (*length*) to read, where a line is defined as a string of characters up to a line delimiter.
### Arguments
*path* The directory where the file is located
*name* The name of the file
*offset* The integer number of lines from the start
*length* The integer number of lines to read from the provided offset value. Should not exceed 10
