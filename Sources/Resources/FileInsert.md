# Description
Provides operations for inserting content into a file.

## insert
### Description
Inserts the provided content starting at the insertion byte offset (*offset_in_bytes*) from start or a line offset (*line_offset*) from start. If multiple inserts are occurring together they should be down from largest offset first (largest to smallest order), so that insertions don't end up in the wrong location. Should not be run in parallel with other operations, and file should be read back in for validation.

### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*offset_in_bytes* Number of bytes from the start<br>
*line_offset* Number of lines from the start, delineated by newline characters<br>
*content* The content that should be inserted.<br>
