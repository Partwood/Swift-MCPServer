Inserts content at a specific line number in a file. This adds new content as a new line or replaces an existing line, depending on the context. Should not be run in parallel with other operations, and file should be read back in for validation. The content is inserted exactly as provided, if newlines are needed they must be part of the content.
   - **Example**: Adding a new line after line 5 in a file.
- **Use Case**: Suitable for adding new entries, headers, or blocks of text where structural changes (e.g., adding a paragraph) are desired.
