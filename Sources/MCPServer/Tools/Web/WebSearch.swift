//
//  WebDownload.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation
import Vapor
import HTMLToMarkdown

struct WebSearchTool: Content {
   static let resourceName: String = "WebSearch"
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
         case query = "query"
      }
      
      //let operation: Operation
      //let path: String
      //let content: String? // For write operations
      //let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+WebSearchTool.resourceName.lowercased()
   }
}

final
class Tool_WebSearch {
   let internalDescriptor: Tool
   let tool: WebSearchTool
   
   init(serverName: String) {
      self.tool = WebSearchTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: WebSearchTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "Identifies which of the tools operations are to be used",
                  "enum": WebSearchTool.Input.Operation.allCases.map({$0.rawValue})
               ],
               "query": [
                  "type": "string",
                  "description": "The query to perform, limited to 2000 characters or less.",
                  "maxLength": 2000,
               ],
            ],
            "required": ["operation", "query"]
         ])
      )
   }
}

// MARK: - Operations
extension Tool_WebSearch {
   func search(path: String,query: String) throws -> String {
      // Use the duckduckgo html based url to query
      let base = "https://html.duckduckgo.com/html/"
      let searchURLString = "\(base)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
      
      debug(searchURLString)
      
      let string = try WebGetUtils.getAsString(url: searchURLString)
      let markdown = try HTMLToMarkdown.convert(string)
      
      // Now write the content to a file, and return that
      let tempFile = try FileUtils().writeToTempFile(path: path,ext: ".md",data: markdown)
      let response = "The results of the search were converted to markdown and saved to the local file system. The results can be found in the file:"+tempFile
      
      debug(response)
      
      return response
   }
}

extension Tool_WebSearch {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: WebSearchTool.Input.Operation,
                                path: String,
                                query: String) -> MCPResponse {
      do {
         let result: String = try search(path: path,query: query)
         
         let value = Text_Content(text: result)
         
         return MCPResponse.toolSuccess(id: responseId, content: [value],serverInfo: serverInfo)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription,serverInfo: serverInfo)
      }
   }
}

// MARK: - MCPTool
extension Tool_WebSearch: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      
   }
   
   func handleOperation(_ serverInfo: ServerInfo, _ urlProvider: (any URLProvider)?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let toolArguments = ToolArguments(arguments: arguments)
      
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inQuery: String = try toolArguments.asString("query", allowEmpty: false,max: 2000)
      let inPath: String = FileManager.default.temporaryDirectory.path()
      
      let possibleOperation = WebSearchTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = WebSearchTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
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
      
      debug("operation:\(operation) query:\(inQuery) accessiblePath:\(accessiblePath)")
      
      let result = handleOperation(serverInfo,responseId,arguments,operation,path: accessiblePath.path(),query: inQuery)
      return result
   }
}
