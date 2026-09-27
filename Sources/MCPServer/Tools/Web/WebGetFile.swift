//
//  WebGetFile.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

import Vapor

struct WebGetFileTool: Content {
   static let resourceName: String = "WebGetFile"
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
         case get_file = "get_file"
      }
      
      //let operation: Operation
      //let path: String
      //let content: String? // For write operations
      //let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+WebGetFileTool.resourceName.lowercased()
   }
}

final
class Tool_WebGetFile {
   let internalDescriptor: Tool
   let tool: WebGetFileTool
   
   init(serverName: String) {
      self.tool = WebGetFileTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: WebGetFileTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+WebGetFileTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "url": [
                  "type": "string",
                  "description": "The url to fetch"
               ],
               "path": [
                  "type": "string",
                  "description": "The destination for the file specified by the fetched url"
               ],
               "name": [
                  "type": "string",
                  "description": "The file name"
               ],
            ],
            "required": ["operation", "url", "path", "name"]
         ])
      )
   }
}

// MARK: - Operations
extension Tool_WebGetFile {
   /// Download a file from a given URL and save it to disk.
   /// - Parameters:
   ///   - url: The URL of the file to download.
   ///   - path: The path where the file should be saved.
   ///   - name: The name of the file
   /// - Returns: The path where the file was saved.
   func downloadFile(url: String, path: String, name fileName: String) throws -> String {
      let data = try WebGetUtils.get(url: url)
      
      let fileURL = FileUtils.fileURL(path: path,fileName)
      
      do {
         try data.write(to: fileURL)
         
         let message = "The file was downloaded and saved to the local file system. It can be found here: \(fileURL.path())"
         return message
      } catch {
         logError(error)
         throw error
      }
   }
}

extension Tool_WebGetFile {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: WebGetFileTool.Input.Operation,
                                path: String,
                                url: String) -> MCPResponse {
      guard let fileName = arguments["name"] as? String,
            !fileName.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "name not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }
      
      do {
         let result: String
         
         switch operation {
         case .get_file:
            result = try downloadFile(url: url, path: path, name: fileName)
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
extension Tool_WebGetFile: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      
   }
   
   func handleOperation(_ serverInfo: ServerInfo, _ urlProvider: (any URLProvider)?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      
      let possibleOperation = WebGetFileTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = WebGetFileTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }

      guard let inUrl: String = arguments["url"] as? String,
            !inUrl.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "url not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }

      guard let inPath: String = arguments["path"] as? String,
            !inPath.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "path not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }

      guard let accessiblePath = FileUtils.accessibleURL(urlProvider,inPath) else {
         let paths = urlProvider?.urls.map({ "\"\($0.path)\"" }).joined(separator: ",")
         let message = "\(inPath) is not accessible, path is not a child of the paths: \(paths ?? "nil")"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) url:\(inUrl) accessiblePath:\(accessiblePath)")

      _ = accessiblePath.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo,responseId,arguments,operation,path: inPath,url: inUrl)
      accessiblePath.stopAccessingSecurityScopedResource()

      return result
   }
}
