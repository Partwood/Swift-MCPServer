Inserts content at a specific byte offset within a file. This is useful for making precise, granular changes, such as inserting a word or phrase within an existing line without adding a new line. Should not be run in parallel with other operations, and file should be read back in for validation. The content is inserted exactly as provided, if newlines are needed they must be part of the content.
   - **Example**: Inserting the word "test" before "papers" in a line like "This is a paper."
- **Use Case**: Ideal for modifying existing text without disrupting the structure or layout of the file.
