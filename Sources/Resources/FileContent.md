# Description
Provides operations for reading and finding string occurences within files.

## find_in_file
### Description
Allows caller to find an exact string in a file.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*find* The exact string to find in the file.<br>

## read_all
### Description
Returns the entire content of a file.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>

## read_range
### Description
Returns a part of the content of a file, using either a byte offset (*offset_in_bytes*) from start or a line offset (*line_offset*) from start combined with the number of bytes to read.
### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*offset_in_bytes* Number of bytes from the start<br>
*line_offset* Number of lines from the start, delineated by newline characters<br>
*length_in_bytes* Number of bytes to read from the provided offset value<br>
