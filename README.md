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
- **FileIO**: Handles file operations such as reading, writing, and directory listing.
- **Dates**: Provides utilities for date and time manipulations.
- **TeamCity**: Interfaces with TeamCity to allow build monitoring and execution.

### Data Structures
Custom data structures to support complex data types:
- **AnyCodable**: A type-erased wrapper for `Encodable` and `Decodable` types.
- **DataStructs**: Additional utility structures for common use cases.

### Extensions
Extensions provide additional functionality to existing types:
- **URL Extensions**: Enhances URL handling capabilities.
- **Encodable Extensions**: Adds convenience methods for encoding data.

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
- **TeamCityTests**: Tests for basic teamcity operation (assuming token access is configured).
- **AnyCodableTests**: Tests for type-erased codable types.

Run tests using Swift Package Manager:

```bash
swift test
```

## License

This project is licensed under the MIT License. See `LICENSE` for more details. Additional MIT License coverage for Vapor and SwiftGitX
