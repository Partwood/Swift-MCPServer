# Description
Provides operations for inserting content into a file.

## inline\_insert
### Description
Inserts content at a specific byte offset within a file. This is useful for making precise, granular changes, such as inserting a word or phrase within an existing line without adding a new line. Should not be run in parallel with other operations, and file should be read back in for validation.
   - **Example**: Inserting the word "test" before "papers" in a line like "This is a paper."
- **Use Case**: Ideal for modifying existing text without disrupting the structure or layout of the file.
### Arguments
*path* The directory where the file is located.<br>
*name* The name of the file.<br>
*offset* Number of bytes from the start<br>
*content* The content that should be inserted.<br>
