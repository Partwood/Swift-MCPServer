# MCPServer

A Swift-based Model Context Protocol (MCP) server implementation using Vapor framework.

## Overview

This project implements an MCP server that can communicate with language models and other clients through the Model Context Protocol. The server provides tools, resources, and capabilities for integration with AI systems.

## Features

- **MCP Protocol Implementation**: Supports the Model Context Protocol specification (version 2025-06-18)
- **Tool Integration**: Provides various tools that can be called by clients
- **Completions Support**: Offers completion suggestions for prompts
- **REST API**: Exposes endpoints for MCP communication
- **WebSocket Support**: Optional WebSocket connectivity
- **Cross-platform**: Works on macOS and iOS (version 13+)

## Architecture

The server is structured into several key components:

### Core Components

1. **MCPServer**: Main class that handles MCP protocol implementation
2. **MCPRequest/MCPResponse**: Data structures for request/response handling
3. **ServerInfo**: Contains metadata about the server
4. **MCPError**: Error handling structure

### Tools Directory

The `Tools` directory contains implementations of various tools:
- **FileIO.swift**: File system operations and I/O capabilities
- **XCode.swift**: Xcode project utilities
- **Dates.swift**: Date and time related functions
- **MCPTool**: Base class for tool implementations

### Data Structures Directory

Contains utility types:
- **AnyCodable**: Type erasure for Codable values
- **DataStructs.swift**: Core data structures
- **Extensions.swift**: Utility extensions

### Extensions Directory

Provides extensions to standard libraries:
- **extEncodable.swift**: Encoding utilities
- **extURL.swift**: URL handling extensions

## Configuration

The server can be configured with:
- Server name
- Hostname and port
- Optional URL provider for dynamic URL resolution

Example configuration:
```swift
let mcpServer = try MCPServer.startMCP(
    serverName: "MyMCPServer",
    title: "My MCP Server",
    hostname: "localhost",
    port: 8000,
    urlProvider: myURLProvider
)
```

## API Endpoints

- `POST /mcp`: Handle MCP requests
- `GET /mcp`: Retrieve server information and capabilities
- `OPTIONS /mcp`: CORS preflight handling
- `WebSocket /mcp-ws`: Optional WebSocket connection

## Supported Methods

1. **initialize**: Initialize the MCP session
2. **completions**: Get completion suggestions for prompts
3. **tools/list**: List available tools
4. **tools/call**: Call a specific tool
5. **notifications/initialized**: Notification when client is initialized
6. **notifications/cancelled**: Notification when operation is cancelled

## Dependencies

- Vapor 4.x (Swift server framework)
- Swift 6.2+

## Building and Running

```bash
swift build
swift run
```

## Testing

The project includes a test suite in the `Tests` directory that can be run with:

```bash
swift test
```

## License

This project is licensed under the terms specified in the LICENSE file.

## Contributing

Contributions are welcome! Please open issues or pull requests for any improvements or bug fixes.

## Contact

For questions or support, please contact the maintainers.
