# Swift MCP Server

A Swift-based Model Context Protocol (MCP) server designed to facilitate communication between clients and backend services. This project provides a framework for building scalable and efficient MCP servers in Swift.

## Features

- **Modular Architecture**: Easily extendable with custom tools and data structures.
- **Tool Integration**: Built-in support for various tools like file I/O, date operations, and Xcode interactions.
- **Data Structures**: Customizable data structures to handle complex data types.
- **Logging**: Integrated logging for debugging and monitoring.

## Components

### Core Server
The core server (`MCPServer.swift`) handles the primary logic for managing connections, requests, and responses. It integrates with various tools and extensions to provide a seamless experience.

### Tools
Tools are modular components that perform specific tasks:

- **File Content**: Handles file operations such as reading, writing, and searching for content within files.
  - **Operations**:
    - `find_in_file`: Find an exact string in a file.
    - `read_all`: Read the entire content of a file.
    - `read_range`: Read a part of the content of a file, using either a byte offset or a line offset.

- **File System**: Provides file system operations for creating directories, listing directory contents, and recursively finding a file or directory under a path.
  - **Operations**:
    - `list`: List directory contents.
    - `create_directory`: Create a directory.
    - `recursive_find_file`: Recursively find a file.
    - `recursive_find_dir`: Recursively find a directory.

- **Git**: A tool for interacting with Git repositories.
  - **Operations**:
    - `clone`: Clone a repository.
    - `init`: Initialize a repository.
    - `status`: Get the status of a repository.
    - `add`: Add files to the repository.
    - `commit`: Commit changes with a message.
    - `push`: Push changes to the repository.
    - `branch`: Create a new branch.
    - `switch`: Switch to an existing branch.

- **Dates**: Provides utilities for date and time manipulations.
  - **Operations**:
    - `date`: Get the current date and time.

- **TeamCity**: Interfaces with TeamCity to allow build monitoring and execution.
  - **Operations**:
    - `status`: Get the status of a build in TeamCity.

- **File Insert**: Provides operations for inserting content into a file.
  - **Operations**:
    - `insert`: Insert content at a specified offset (byte or line).

- **File Append**: Provides operations for appending content to the end of a file.
  - **Operations**:
    - `append`: Append content to the end of a file.

### Data Structures
Custom data structures to support complex data types:
- **AnyCodable**: A type-erased wrapper for `Encodable` and `Decodable` types.
- **DataStructs**: Additional utility structures for common use cases.

### Extensions
Extensions provide additional functionality to existing types:
- **URL Extensions**: Enhances URL handling capabilities.
- **Encodable Extensions**: Adds convenience methods for encoding data.

## Providers

Providers are used to abstract and manage dynamic components like URLs and tools, making the project more flexible and modular.

### URLProvider

Manages a collection of URLs, providing methods to retrieve and update them. Useful for scenarios where URLs need to be dynamically fetched or updated at runtime.

- **Key Features**:
  - Unique identifier (`provider`) for each provider instance.
  - Dynamic URL management with `auxUrls(_:)`.
  - Used in tools like `FileContent` and `FileSystem` to validate and access file paths securely.

- **Example Use Case**:
  Fetching or updating API endpoints dynamically.

```swift
public protocol URLProvider {
    var provider: UUID { get }
    var urls: Array<URL> { get }

    func auxUrls(_ urls: Array<URL>)
}
```

### ToolProvider

Manages and caches tools (`MCPTool`) based on runtime contexts. Provides methods to retrieve tools dynamically and cache them for performance optimization.

- **Key Features**:
  - Dynamic tool retrieval with `tools(_:)`.
  - Tool caching with `cacheTools(_:_:)`.

- **Example Use Case**:
  Loading tools based on user-specific configurations or caching frequently used tools.

```swift
public protocol ToolProvider {
    func tools(_ context: [String: String]) -> Array<MCPTool>?
    func cacheTools(_ uuid: UUID, _ tools: Array<MCPTool>?)
}
```

### How They Work Together

- **URLProvider** ensures that file operations are performed on valid and accessible paths, providing a layer of security and consistency.
- **ToolProvider** allows the Swagentic project to dynamically manage and use tools, enabling modularity and extensibility.
- Both providers are integrated into the core logic, ensuring that tools can access the correct resources and perform their operations reliably.

## Usage

To use this MCP server in your project, add it as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/Partwood/Swift-MCPServer.git", from: "1.0.0")
]
```

Then import the package in your code:

```swift
import MCPServer
```

## Testing

The project includes a comprehensive test suite to ensure reliability and correctness:
- **MCPServerTests**: Tests for core server functionality.
- **FileIOTests**: Tests for file operations.
- **TeamCityTests**: Tests for basic TeamCity operation (assuming token access is configured).
- **AnyCodableTests**: Tests for type-erased codable types.

Run tests using Swift Package Manager:

```bash
swift test
```

## License

This project is licensed under the MIT License. See `LICENSE` for more details. Additional MIT License coverage for Vapor and SwiftGitX.
