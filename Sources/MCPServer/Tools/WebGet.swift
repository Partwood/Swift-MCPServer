//
//  WebGet.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

import Vapor

struct WebGetTool: Content {
   static let resourceName: String = "WebGet"
   let name: String
   
   // Helper method to load the description from FileSystem.md
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
         case get = "get"
      }
      
      //let operation: Operation
      //let path: String
      //let content: String? // For write operations
      //let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+WebGetTool.resourceName.lowercased()
   }
}

final
class Tool_WebGet {
   let internalDescriptor: Tool
   let tool: WebGetTool
   
   init(serverName: String) {
      self.tool = WebGetTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: WebGetTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+WebGetTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
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
extension Tool_WebGet {
   
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
   
   func get(url: String) -> String {
      guard let getURL = URL(string: url) else {
         return ""
      }
      
      let semaphore = DispatchSemaphore(value: 0)
      
      // 2. Instantiate our Sendable container.
      // Swift 6 allows capturing this object because it's explicitly marked 'Sendable'
      let container = SendableBox()
      
      URLSession.shared.dataTask(with: getURL) { data, _, error in
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
      
      // 4. Safely pull out and return the results directly
      return container.value
   }
}

extension Tool_WebGet {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: WebGetTool.Input.Operation,_ url: String) -> MCPResponse {
      let result: String = get(url: url)
      let value = Text_Content(text: result)
      
      return MCPResponse.toolSuccess(id: responseId, content: [value],serverInfo: serverInfo)
   }
}

// MARK: - MCPTool
extension Tool_WebGet: MCPTool {
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
      
      let possibleOperation = WebGetTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = WebGetTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) url:\(inUrl)")
      
      let result = handleOperation(serverInfo,responseId,arguments,operation,inUrl)
      return result
   }
}
