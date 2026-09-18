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
   
   func search(query: String) -> String {
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
      
      // 4. Safely pull out and return the results directly
      return container.value
   }

//   func search(query: String, limit: Int = 10) -> [URL] {
//      guard limit > 0 else { return [] }
//      
//      // Use DuckDuckGo API for web search
//      let searchURLString = "https://api.duckduckgo.com/?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&format=json"
//      guard let searchURL = URL(string: searchURLString) else {
//         return []
//      }
//      
//      let semaphore = DispatchSemaphore(value: 0)
//      
//      //var urls: [URL] = []
//      
//      DispatchQueue.global(qos: .userInitiated).async {
//         var urls: [URL] = []
//         
//         do {
//            let (data, _) = try await URLSession.shared.data(from: searchURL)
//            
//            do {
//               if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//                  let results = json["results"] as? [[String: Any]] {
//                  for result in results.prefix(limit) {
//                     if let firstURL = result["firsturl"] as? String, let url = URL(string: firstURL) {
//                        urls.append(url)
//                     } else {
//                        logError("No firsturl")
//                     }
//                  }
//               } else {
//                  logError("No results and no error")
//               }
//            } catch {
//               logError("Error parsing JSON: \(error.localizedDescription)")
//            }
//         } catch {
//            logError(error)
//         }
//         
//         semaphore.signal()
//      }
//      
//      semaphore.wait()
//      
//      return urls
//   }
}

extension Tool_WebSearch {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: WebSearchTool.Input.Operation,_ query: String) -> MCPResponse {
      let result: String = search(query: query)
      let value = Text_Content(text: result)
      
      return MCPResponse.toolSuccess(id: responseId, content: [value],serverInfo: serverInfo)
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
      
      let possibleOperation = WebSearchTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = WebSearchTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) path:\(inQuery)")
      
      let result = handleOperation(serverInfo,responseId,arguments,operation,inQuery)
      return result
   }
}


//class SerialQueryPipeline: @unchecked Sendable {
//   private var continuation: AsyncStream<String>.Continuation?
//   private var finalResults: [URL] = []
//   
//   // Semaphores are the standard low-level tool for synchronous blocking
//   private let semaphore = DispatchSemaphore(value: 0)
//   
//   init() {
//      let (stream, continuation) = AsyncStream<String>.makeStream()
//      self.continuation = continuation
//      
//      Task { [weak self] in
//         for await query in stream {
//            guard let self = self else { break }
//            let urls = await self.fetchSearchWithTimeout(query: query)
//            self.consumeResultsSerially(urls)
//         }
//         // Signal the semaphore when the background queue is completely empty
//         self?.semaphore.signal()
//      }
//   }
//   
//   func enqueueQuery(_ query: String) {
//      continuation?.yield(query)
//   }
//   
//   /// Synchronously blocks the calling thread and returns results directly
//   func finishPipeline() -> [URL] {
//      continuation?.finish()
//      
//      // HARD BLOCK: Stop execution right here until .signal() is hit
//      semaphore.wait()
//      
//      return finalResults
//   }
//   
//   private func fetchSearchWithTimeout(query: String) async -> [URL] {
//      do { return try await performNetworkSearch(query: query) } catch { return [] }
//   }
//   
//   private func consumeResultsSerially(_ urls: [URL]) {
//      self.finalResults.append(contentsOf: urls)
//   }
//
//   private func performNetworkSearch(query: String) async throws -> [URL] {
//      // 1. Prepare your API endpoint
//      guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
//            let searchURL = URL(string: "https://duckduckgo.com\(encodedQuery)&format=json") else {
//         throw URLError(.badURL)
//      }
//      
//      // 2. THE NON-BLOCKING SUSPENSION POINT:
//      // This line uses Apple's native async/await URLSession engine.
//      // When Swift hits 'await', it completely pauses this specific function's memory state,
//      // unloads it from the thread, and hands the physical CPU thread back to the OS.
//      let (data, _) = try await URLSession.shared.data(from: searchURL)
//      
//      // While the network hardware is waiting for bytes from the web server,
//      // ZERO CPU threads are being frozen or wasted by this function.
//      
//      // 3. Resumes naturally on an available background thread once data arrives
//      guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
//            let results = json["RelatedTopics"] as? [[String: Any]] else {
//         return []
//      }
//      
//      var urls: [URL] = []
//      for result in results {
//         if let firstURL = result["FirstURL"] as? String, let url = URL(string: firstURL) {
//            urls.append(url)
//         }
//      }
//      
//      return urls
//   }
//}
