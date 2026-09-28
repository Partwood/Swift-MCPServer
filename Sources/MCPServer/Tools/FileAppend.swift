//
//  FileAppend.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

enum FileAppendToolError: Error {
   case resource_not_found
}

struct FileAppendTool: Content {
   let name: String
   
   // Helper method to load the description from FileAppend.md
   static func loadDescription() -> String {
      let resourceName: String = "FileAppend"
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
            throw FileAppendToolError.resource_not_found
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
         case appendContent = "append"
      }

      enum Arguments: String, Codable, CaseIterable {
         case content = "content"
         case name = "name"
         case path = "path"
      }

      //let operation: Operation
      //let path: String
      //let name: String
      //let content: String? // For write operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_FileAppend"
   }
}

enum Tool_FileAppend_Error: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)

   public var errorDescription: String? {
      return description
   }
}

extension Tool_FileAppend_Error: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .path_is_directory(let url):
         return NSLocalizedString("Operation error: '\(url)' is a directory", comment: "Unexpected directory")
      case .path_is_file(let url):
         return NSLocalizedString("Operation error: '\(url)' is a file", comment: "Unexpected file")
      }
   }
}

public
final
class Tool_FileAppend {
   let internalDescriptor: Tool
   let tool: FileAppendTool
   
   public init(serverName: String) {
      self.tool = FileAppendTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileAppendTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileAppendTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The path to a file or directory"
               ],
               "name": [
                  "type": "string",
                  "description": "The file or directory name"
               ],
               "content": [
                  "type": "string",
                  "description": "The content to be written"
               ],
            ],
            "required": ["operation", "path", "name", "content"]
         ])
      )
   }
   
   func accessibleURL(_ urlProvider: URLProvider?,_ path: String) -> URL? {
      guard let urlProvider else {
         debug("No urlProvider")
         return nil
      }
      let urls = urlProvider.urls
      if urls.isEmpty {
         debug("No urlProvider.urls")
         return nil
      }
      
      let first = urls.first(where: { url in
         debug("url:\(url.path)\npath:\(path)")
         
         let expandedPath = NSString(string: path).expandingTildeInPath
         let desiredURL = URL(fileURLWithPath: expandedPath)
         return desiredURL.isContained(in: url)
      })
      
      return first
   }
}

// MARK: Write content
extension Tool_FileAppend {
   func appendToFile(_ serverInfo: ServerInfo,_ responseId: String,at path: String,name: String,with content: String) -> MCPResponse {
      if ( path.contains("%20") ) {
         logWarn("Invalid string!!!")
      }

      let fileURL = FileUtils.fileURL(path: path,name)
      
      let fileString = fileURL.path(percentEncoded: false)
      
      let isDirectory: Bool
      do {
         isDirectory = try fileURL.isExistingDirectory()
      } catch {
         let message = "Error appending to file '\(fileString)', error: \(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      if ( isDirectory ) {
         let error = Tool_FileAppend_Error.path_is_directory(fileURL)
         logError(error.description)
         return MCPResponse.toolError(id: responseId,message: error.localizedDescription,serverInfo: serverInfo)
      }

      do {
         // Open the file in append mode
         if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(content.data(using: .utf8)!)
            fileHandle.closeFile()
         } else {
            // If the file doesn't exist, create it and write the content
            try content.write(toFile: fileString, atomically: true, encoding: .utf8)
         }
      } catch {
         let message = "Error appending to file '\(fileString)', error: \(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, text: "Successfully appended the content to file:'\(fileString)'",serverInfo: serverInfo)
   }
}

extension Tool_FileAppend {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileAppendTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName = arguments["name"] as? String ?? ""
      guard !fileName.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "name not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }
      
      switch operation {
      case .appendContent:
         let whichContent: String = arguments["content"] as? String ?? ""
         guard !whichContent.isEmpty else {
            logWarn("content:'\(arguments["content"] ?? "nil")'")
            return MCPResponse.toolError(id: responseId, message: "content not provided for operation:'\(operation.rawValue)'",serverInfo: serverInfo)
         }

         return appendToFile(serverInfo,responseId,at: whichPath,name: fileName,with: whichContent)
      }
   }
}

// MARK: MCPTool
extension Tool_FileAppend: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   public func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   public func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      //debug("req:\(req.method)")
      
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."
      
      let possibleOperation = FileAppendTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileAppendTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      guard let url = accessibleURL(urlProvider,inPath) else {
         let paths = urlProvider?.urls.map({ "\"\($0.path)\"" }).joined(separator: ",")
         let message = "\(inPath) is not accessible, path is not a child of the paths: \(paths ?? "nil")"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) path:\(inPath)")
      
      _ = url.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo,responseId,arguments,operation,inPath)
      url.stopAccessingSecurityScopedResource()
      return result
   }
}
