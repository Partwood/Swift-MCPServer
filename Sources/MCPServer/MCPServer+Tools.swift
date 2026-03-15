//
//  MCPServer+Tools.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor

extension SwiftMCPServer {
   func registerTools() {
      // Define your available tools
      var tools = [:] as [String: MCPTool]
      
      var mcpTool: MCPTool

      mcpTool = Tool_SystemDate(serverName: self.name)
      tools[mcpTool.name] = mcpTool
      
      mcpTool = Tool_FileSystem(serverName: self.name,urlProvider: self.urlProvider)
      tools[mcpTool.name] = mcpTool
      
      mcpTool = Tool_TeamCity(serverName: self.name)
      tools[mcpTool.name] = mcpTool

      self.internalTools = tools
   }
   
   func listTools(_ responseId: Int) -> MCPResponse {
      debug("Listing:\n\(self.tools)")
      
      let descriptorArray: Array<Tool> = self.internalTools.map({$0.value.descriptor})
      let response = MCPResponse(id: String("\(responseId)"),
                  result: [
                     "tools": AnyCodable(descriptorArray)
                  ],
                  serverInfo: self.readableServerInfo,
                  error: nil)
      return response
   }
   
   func callTool(_ req: MCPRequest,_ responseId: Int,params: [String: AnyCodable]?) -> MCPResponse {
      guard let params = params,
            let name = params["name"]?.value as? String,
            let arguments = params["arguments"]?.value as? [String: Any] else {
         logError("Invalid params (needs name and arguments) \(params ?? [:])")
         return MCPResponse.toolError(
            id: String("\(responseId)"),
            message: "Invalid params (needs name and arguments)",
            serverInfo: self.readableServerInfo,
         )
      }
      
      if let first = self.internalTools[name] {
         do {
            let response = try first.handleOperation(self.readableServerInfo,req,"\(responseId)",arguments)
            return response
         } catch {
            logError(error)
            return MCPResponse.toolError(
               id: String("\(responseId)"),
               message: "Error handling operation error:\(error.localizedDescription)",
               serverInfo: self.readableServerInfo,
            )
         }
      } else {
         let message = "Unknown tool '\(name)'"
         logError(message)
         return MCPResponse.toolError(
            id: String("\(responseId)"),
            message: message,
            serverInfo: self.readableServerInfo,
         )
      }
   }
}
