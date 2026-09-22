# Description
Provides operations for inserting content into a file.

## line\_insert
### Description
Inserts content at a specific line number in a file. This adds new content as a new line or replaces an existing line, depending on the context. Should not be run in parallel with other operations, and file should be read back in for validation.
   - **Example**: Adding a new line after line 5 in a file.
- **Use Case**: Suitable for adding new entries, headers, or blocks of text where structural changes (e.g., adding a paragraph) are desired.
### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*offset* Number of lines from the start, delineated by newline characters<br>
*content* The content that should be inserted.<br>
