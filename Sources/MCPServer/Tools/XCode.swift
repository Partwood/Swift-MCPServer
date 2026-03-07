//
//  XCode.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor

struct XCodeTool: Content {
   let name: String
   static let description = "Perform xcode command line operations"
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case listProject = "list"
         //case readFile = "read"
         //case writeFile = "write"
         //case createDirectory = "createdirectory"
      }
      
      let operation: Operation
      let projectName: String
      //let path: String
      //let content: String? // For write operations
      //let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_xcode"
   }
}

final
class Tool_XCode {
   let internalDescriptor: Tool
   let tool:XCodeTool
   let urlProvider: URLProvider?
   
   init(serverName: String,urlProvider: URLProvider?) {
      self.tool = XCodeTool(serverName: serverName)
      self.urlProvider = urlProvider
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: XCodeTool.description,
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "Use one of the following values:"+XCodeTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "projectName": [
                  "type": "string",
                  "description": "The name of a project, typically in the form <name>.xcodeproj"
               ],
            ],
            "required": ["operation","projectName"]
         ])
      )
   }
   
   func date(_ serverInfo: ServerInfo,_ responseId: String) throws -> MCPResponse {
      var values = Array<Text_Content>()
      
      values.append(Text_Content(text: "\(Date())"))
      
      return MCPResponse.toolSuccess(id: responseId, content: values,serverInfo: serverInfo)
   }
}

extension Tool_XCode: MCPTool {
   var descriptor: Tool { get { return self.internalDescriptor } }
   var name: String { get { return self.tool.name } }

   func handleOperation(_ serverInfo: ServerInfo, _ req: MCPRequest, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      debug("req:\n\(req)\narguments:\n\(arguments)")
      
      let whichOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let operation = XCodeTool.Input.Operation(rawValue: whichOperation)
      
      let projectName: String = arguments["projectName"] as? String ?? ""
      if ( operation != .none && !projectName.isEmpty ) {
         return MCPResponse.toolSuccess(id: responseId, text: "Completed operation successfully", serverInfo: serverInfo)
      } else {
         if ( operation == .none ) {
            let operations = XCodeTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
            let message = "Unknown operation '\(whichOperation)' valid operations are \(operations)"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         } else if projectName.isEmpty {
            let message = "Project name was not provided"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         } else {
            logError("Unexpected!")
            return MCPResponse.toolError(id: responseId, message: "Unexpected failure",serverInfo: serverInfo)
         }
      }
   }
}
