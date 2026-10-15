Provides file system operations for creating directories, listing directory contents, and recursively finding a file or directory under a path.
When using paths, use the appropriate format for mac, windows or linux
## operation:list
Given a path, list the contents with details for the children under that path. Details include name and type (e.g. "file", "directory", "symbolic link" or similar)
## operation:info
Given a path and name, return information about the file or directory, such as content type (checks if binary, text jpeg, png, audio and video types, markdown and html), size, permissions, created date and modified date
## operation:create_directory
Given a path and name, create a directory with the given name in the path location
## operation:recursive_find_file
Given a path and name, search in path and all its children recursively, reporting anywhere name is found that is a file. The name can be a regex pattern or an exact name.
## operation:recursive_find_dir
Given a path and name, search in path and all its children recursively, reporting anywhere name is found that is a directory. The name can be a regex pattern or an exact name.
