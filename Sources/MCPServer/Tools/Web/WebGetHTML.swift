//
//  WebGetHTML.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

import Vapor

struct WebGetHTMLTool: Content {
   static let resourceName: String = "WebGetHTML"
   let name: String
   
   // Helper method to load the description from <resourceName>.md
   static func loadDescription() -> String {
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
            logError(ResourceError.resource_not_found)
            assertionFailure(ResourceError.resource_not_found.localizedDescription)
            throw ResourceError.resource_not_found
         }
      } catch {
         logError(error)
         assertionFailure(error.localizedDescription)
         // Fallback to a default description in case of an error
         return "Default tool description"
      }
   }
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case get_html = "get_html"
      }
      
      //let operation: Operation
      //let path: String
      //let content: String? // For write operations
      //let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+WebGetHTMLTool.resourceName.lowercased()
   }
}

final
class Tool_WebGetHTML {
   let internalDescriptor: Tool
   let tool: WebGetHTMLTool
   
   init(serverName: String) {
      self.tool = WebGetHTMLTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: WebGetHTMLTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+WebGetHTMLTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "url": [
                  "type": "string",
                  "description": "The url to fetch"
               ],
            ],
            "required": ["operation", "url"]
         ])
      )
   }
}

// MARK: - Operations
extension Tool_WebGetHTML {
   func get(path: String,url: String) throws -> String {
      let string = try WebGetUtils.getAsString(url: url)

      // Now write the content to a file, and return that
      let tempFile = try FileUtils().writeToTempFile(path: path,ext: ".html",data: string)
      let message = "The content of the url were saved to the local file system. The content can be found in the file:"+tempFile
      
      return message
   }
}

extension Tool_WebGetHTML {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: WebGetHTMLTool.Input.Operation,
                                path: String,
                                url: String) -> MCPResponse {
      do {
         let result: String
         
         switch operation {
         case .get_html:
            result = try get(path: path, url: url)
         }
         let value = Text_Content(text: result)
         return MCPResponse.toolSuccess(id: responseId, content: [value], serverInfo: serverInfo)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
   }
}

// MARK: - MCPTool
extension Tool_WebGetHTML: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      
   }
   
   func handleOperation(_ serverInfo: ServerInfo, _ urlProvider: (any URLProvider)?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inUrl: String = arguments["url"] as? String ?? "."
      let inPath: String = FileManager.default.temporaryDirectory.path()
      
      let possibleOperation = WebGetHTMLTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = WebGetHTMLTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      guard let accessiblePath = FileUtils.accessibleURL(urlProvider,inPath) else {
         let paths = urlProvider?.urls.map({ "\"\($0.path)\"" }).joined(separator: ",")
         let message = "\(inPath) is not accessible, path is not a child of the paths: \(paths ?? "nil")"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) url:\(inUrl) accessiblePath:\(accessiblePath)")
      
      let result = handleOperation(serverInfo,responseId,arguments,operation,path: accessiblePath.path(),url: inUrl)
      return result
   }
}
