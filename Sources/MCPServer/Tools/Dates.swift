//
//  Dates.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor

struct SystemDateTool: Content {
   let name: String
   static let description = "Perform system date and time operations"
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case date = "date"
      }
      
      let operation: Operation
   }

   init(serverName: String) {
      name = "mcp_"+serverName+"_systemdate"
   }
}

class Tool_SystemDate {
   let internalDescriptor: Tool
   let tool:SystemDateTool
   
   init(serverName: String) {
      tool = SystemDateTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: SystemDateTool.description,
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "Use one of the following values:"+SystemDateTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
            ],
            "required": ["operation"]
         ])
      )
   }
   
   func date(_ serverInfo: ServerInfo,_ responseId: String) throws -> MCPResponse {
      var values = Array<Text_Content>()

      values.append(Text_Content(text: "\(Date())"))
      
      return MCPResponse.toolSuccess(id: responseId, content: values,serverInfo: serverInfo)
   }
}
 
extension Tool_SystemDate: MCPTool {
   var name: String { get { return self.tool.name } }
   var descriptor: Tool { get { return self.internalDescriptor } }
   
   var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }

   func handleOperation(_ serverInfo: ServerInfo,_ req: MCPRequest,_ responseId: String,_ arguments: [String: Any]) throws -> MCPResponse {
      debug("req:\n\(req)\narguments:\n\(arguments)")
      
      let whichOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let operation = SystemDateTool.Input.Operation(rawValue: whichOperation)
      switch operation {
      case .date:
         return try date(serverInfo,responseId)
      default:
         let operations = SystemDateTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(whichOperation)' valid operations are \(operations)"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
   }
}
