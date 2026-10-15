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

      enum Arguments: String, Codable, CaseIterable {
         case url = "url"
         case path = "path"
         case name = "name"
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
                  "description": "Identifies which of the tools operations are to be used",
                  "enum": WebGetFileTool.Input.Operation.allCases.map({$0.rawValue})
               ],
               "url": [
                  "type": "string",
                  "description": "The url to fetch"
               ],
               "path": [
                  "type": "string",
                  "description": "The absolute directory path to the target file folder (e.g. '/Users/project/src'). Exclude the file name."
               ],
               "name": [
                  "type": "string",
                  "description": "The exact file name including its extension (e.g. 'image.png' or 'config.json')."
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
      let data = try WebGetUtils.get(url: url,mimeType: fileName.mimeType())
      
      let fileURL = FileUtils.fileURL(path: path,fileName)
      
      do {
         try data.write(to: fileURL)
         
         let message = "The file was downloaded and saved to the local file system, it can be found here: '\(fileURL.path())'."
         return message
      } catch {
         logError(error)
         throw error
      }
   }
}

extension Tool_WebGetFile {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ toolArguments: ToolArguments,_ operation: WebGetFileTool.Input.Operation,
                                path: String,
                                url: String) -> MCPResponse {
      let fileName:String
      do {
       fileName = try toolArguments.asString("name", allowEmpty: false)
      } catch {
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) name:\(fileName)")
      
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
      let toolArguments = ToolArguments(arguments: arguments)
      
      let operation = try toolArguments.enumFromString("operation", as: WebGetFileTool.Input.Operation.self)
      let urlString = try toolArguments.asString("url", allowEmpty: false)
      let accessibleUrl = try toolArguments.asAccessibleURL(urlProvider, WebGetFileTool.Input.Arguments.path.rawValue)
      
      debug("operation:\(operation) url:\(urlString) accessiblePath:\(accessibleUrl.rootURL.path()) destination:\(accessibleUrl.path)")

      _ = accessibleUrl.rootURL.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo, responseId, toolArguments, operation,path: accessibleUrl.path,url: urlString)
      accessibleUrl.rootURL.stopAccessingSecurityScopedResource()

      return result
   }
}
