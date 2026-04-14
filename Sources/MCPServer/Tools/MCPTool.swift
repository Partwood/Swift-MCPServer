//
//  MCPTool.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

public
class MCPToolAttribute {
   public let name: String
   public let description: String
   var value: String?
   
   init(name: String, description: String, value: String? = nil) {
      self.name = name
      self.description = description
      self.value = value
   }
}

public
protocol MCPTool {
   var name: String {get}
   var descriptor: Tool {get}
   var attributes: [MCPToolAttribute] {get}
   
   func attributeValue(attribute: MCPToolAttribute,value: String)
   
   func handleOperation(_ serverInfo: ServerInfo,_ req: MCPRequest,_ responseId: String,_ arguments: [String: Any]) throws -> MCPResponse
}
