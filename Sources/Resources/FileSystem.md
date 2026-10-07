# Description
Provides file system operations for creating directories, listing directory contents, and recursively finding a file or directory under a path.
When using paths, use the appropriate format for mac, windows or linux

## list
### Description
Given a path, list the contents with details for the children under that path. Details include the following list:

1. **Name**: The name of the file or directory.
2. **Type**: Whether the item is a file or a directory (e.g. "file", "directory", "symbolic link" or similar).
3. **ContentType:** For files, returns the discovered content type (e.g. "binary", "text", "jpeg", "png", "markdown", "unknown")
4. **Size**: The size of the item in bytes (if it is a file).
5. **Path**: The full path to the item (constructed by combining the provided path with the item's name).
6. **Permissions**: File permissions (e.g., read, write, execute).
7. **Modification Date**: The date and time when the item was last modified.
8. **Creation Date**: The date and time when the item was created (if available).

The exact details may vary slightly depending on the system 
### Arguments
*path* The location on disk<br>

## create_directory
### Description
Given a path and name, create a directory with the given name in the path location

### Arguments
*path* The location on disk<br>
*name* The file or directory name<br>

## recursive_find_file
### Description
Given a path and name, search in path and all its children recursively, reporting anywhere name is found that is a file. The name can be a regex pattern or an exact name.

### Arguments
*path* The location on disk<br>
*name* The file name, can be a regex pattern or an exact name<br>

## recursive_find_dir
### Description
Given a path and name, search in path and all its children recursively, reporting anywhere name is found that is a directory. The name can be a regex pattern or an exact name.

### Arguments
*path* The location on disk<br>
*name* The directory name, can be a regex pattern or an exact name<br>
