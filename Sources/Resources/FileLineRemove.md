Removes content at a specific line number in a file. This removes lines starting at the offset and continues for the specified count. Should not be run in parallel with other operations, and file should be read back in for validation.
   - **Example**: Removing 3 lines starting at line 5 in a file.
- **Use Case**: Suitable for removing lines of code that need to be modified (use this to remove and then call insert), or just removed entirely.
