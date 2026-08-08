# Description
Provides operations for reading, writing, inserting, appending and finding string occurences within files.

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

## write_all
### Description
Writes out the content provided to the given file, replacing any existing content or creating a new file with the content. Should not be run in parallel with other operations, and file should be read back in for validation.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*content* The content of the file.<br>

## insert
### Description
Inserts the provided content starting at the insertion byte offset (*offset_in_bytes*) from start or a line offset (*line_offset*) from start. If multiple inserts are occurring together they should be down from largest offset first (largest to smallest order), so that insertions don't end up in the wrong location. Should not be run in parallel with other operations, and file should be read back in for validation.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*offset_in_bytes* Number of bytes from the start<br>
*line_offset* Number of lines from the start, delineated by newline characters<br>
*content* The content that should be inserted.<br>

## append
### Description
Appends the provided content to the end of a file. Should not be run in parallel with other operations, and file should be read back in for validation.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*content* The content that should be inserted.<br>
