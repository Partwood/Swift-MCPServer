# Description
Allows reading all of the full context for the session, or parts of the full context.

## find
### Description
Allows caller to find locations of an exact string in the context archive.
### Arguments
*path* The directory where the file is located.<br>
*string* The exact string to find in the context archive.
<br>

## read
### Description
Returns the entire context archive.
### Arguments
*path* The directory where the context archive is located.
<br>

## read_range
### Description
Returns a part of the context archive, using either a byte offset (*offset_in_bytes*) from start or a line offset (*line_offset*) from start combined with the number of bytes to read.
### Arguments
*path* The directory where the context archive is located.<br>
*offset_in_bytes* Number of bytes from the start<br>
*line_offset* Number of lines from the start, delineated by newline characters<br>
*length_in_bytes* Number of bytes to read from the provided offset value<br>
