//
//  WebDownload.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

import Vapor

struct WebSearchTool: Content {
   static let resourceName: String = "WebSearch"
   let name: String
   
   // Helper method to load the description from FileSystem.md
   static func loadDescription() -> String {
      //let resourceName: String = "WebSearch"
      
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
                  "description": "One of the following values:"+WebSearchTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "query": [
                  "type": "string",
                  "description": "The query to perform"
               ],
            ],
            "required": ["operation", "query"]
         ])
      )
   }
}

// MARK: - Operations
extension Tool_WebSearch {
   
   /// Perform a web search and return the resulting URLs.
   /// - Parameters:
   ///   - query: The search query.
   ///   - limit: The maximum number of results to return.
   /// - Returns: An array of URLs.
   // 1. Create a simple, Sendable mutable box to safely share data across threads.
   // Because we synchronize access manually with a lock/semaphore, we can mark it unchecked.
   final class SendableBox: @unchecked Sendable {
      var value: String = ""
   }
   
   func search(path: String,query: String) throws -> String {
      let base = "https://html.duckduckgo.com/html/"//"https://duckduckgo.com/"
      let searchURLString = "\(base)?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
      guard let searchURL = URL(string: searchURLString) else {
         return ""
      }
      
      let semaphore = DispatchSemaphore(value: 0)
      
      // 2. Instantiate our Sendable container.
      // Swift 6 allows capturing this object because it's explicitly marked 'Sendable'
      let container = SendableBox()
      
      URLSession.shared.dataTask(with: searchURL) { data, _, error in
         // Defer guarantees the caller thread unblocks even if parsing throws an error
         defer { semaphore.signal() }
         
         guard let data = data, error == nil else { return }
         
         if let string = String(data: data, encoding: .utf8) {
            container.value = string
         } else {
            logError("Unable to get string from data")
         }
      }.resume()
      
      // 3. HARD BLOCK: Execution freezes here, waiting for the background network task
      semaphore.wait()

      // Now write the content to a file, and return that
      let tempFile = try FileUtils().writeToTempFile(path: path,ext: ".html",data: container.value)
      container.value = "The results of the search can be found in this file:"+tempFile

      // 4. Safely pull out and return the results directly
      return container.value
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
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inQuery: String = arguments["query"] as? String ?? "."
      let inPath: String = FileManager.default.temporaryDirectory.path()//arguments["path"] as? String ?? "."
      
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
