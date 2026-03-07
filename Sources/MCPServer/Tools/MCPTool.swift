//
//  MCPTool.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

protocol MCPTool {
   var name: String {get}
   var descriptor: Tool {get}
   func handleOperation(_ serverInfo: ServerInfo,_ req: MCPRequest,_ responseId: String,_ arguments: [String: Any]) throws -> MCPResponse
}
