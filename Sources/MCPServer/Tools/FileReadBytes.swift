//
//  FileReadBytes.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileReadBytesTool: Content {
   static let resourceName: String = "FileReadBytes"
   let name: String
   
   // Helper method to load the description from <resourceName>.md
   static func loadDescription() -> String {
      do {
         if let filePath = Bundle.module.url(forResource: FileReadBytesTool.resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
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
         case readContentRange = "read_bytes"
      }

      enum Arguments: String, Codable, CaseIterable {
         case length = "length"
         case offset = "offset"
         case name = "name"
         case path = "path"
      }
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+FileReadBytesTool.resourceName.lowercased()
   }
}

public
final
class Tool_FileReadBytes {
   let internalDescriptor: Tool
   let tool: FileReadBytesTool
   
   public init(serverName: String) {
      self.tool = FileReadBytesTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileReadBytesTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "Identifies which of the tools operations are to be used",
                  "enum": FileReadBytesTool.Input.Operation.allCases.map({$0.rawValue})
               ],
               "path": [
                  "type": "string",
                  "description": "The absolute directory path to the target file folder (e.g. '/Users/project/src'). Exclude the file name."
               ],
               "name": [
                  "type": "string",
                  "description": "The exact file name including its extension (e.g. 'main.swift' or 'config.json')."
               ],
               "offset": [
                  "type": "number",
                  "description": "The starting position in bytes from where the reading begins. Use 0 to start from the beginning.",
                  "minimum": 0,
               ],
               "length": [
                  "type": "number",
                  "description": "The maximum number of bytes to retrieve in a single operation. Restrict this to 8192 or lower to avoid overflow.",
                  "maximum": 8192,
               ],
            ],
            "required": ["operation", "path", "name", "offset", "length"]
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

// MARK: Read content
extension Tool_FileReadBytes {
   func readFile(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,offset: Int,length: Int) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      var fullContent = Array<Text_Content>()
      
      let FileReadBytes: Text_Content
      
      let FileReadBytesString: String?
      do {
         FileReadBytesString = try FileUtils.readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }

      let subString: String?
      
      if let content = FileReadBytesString {
         if let start = content.index(content.startIndex, offsetBy: Int(offset), limitedBy: content.endIndex) {
            let end = content.index(content.startIndex, offsetBy: Int(offset+length), limitedBy: content.endIndex) ?? content.endIndex
            subString = String(content[start..<end])
         } else {
            let message = "End of file, file:'\(FileUtils.fileURL(path: inPath,name).path(percentEncoded: false))'"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
         }
      } else {
         logWarn("No content in file, file:'\(FileUtils.fileURL(path: inPath,name).path(percentEncoded: false))'")
         subString = ""
      }

      if let content = subString {
         FileReadBytes = Text_Content(text: content)
         fullContent.append(FileReadBytes)
      } else {
         let message = "File not found or has no content, file:'\(FileUtils.fileURL(path: inPath,name).path(percentEncoded: false))'"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: fullContent,serverInfo: serverInfo)
   }
}

// MARK: Offset
extension Tool_FileReadBytes {
   public struct OffsetSuccess {
      public var offset: Int
   }
   
   public enum OffsetError: Error {
      case mcpError(response: MCPResponse)
   }
}

extension Tool_FileReadBytes {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileReadBytesTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let toolArguments = ToolArguments(arguments: arguments)
      
      let fileName: String
      let offset: Int
      let length: Int
      
      do {
         fileName = try toolArguments.asString(FileReadBytesTool.Input.Arguments.name.rawValue, allowEmpty: false)
         offset = try toolArguments.asInteger(FileReadBytesTool.Input.Arguments.offset.rawValue,min: 0)
         length = try toolArguments.asInteger(FileReadBytesTool.Input.Arguments.length.rawValue,max: 8192)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: "For operation:'\(operation.rawValue)' \(error.localizedDescription)", serverInfo: serverInfo)
      }
      
      switch operation {
      case .readContentRange:
         return readFile(serverInfo,responseId,at: whichPath,name: fileName,offset: offset,length: length)
      }
   }
}

// MARK: MCPTool
extension Tool_FileReadBytes: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   public func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   public func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?/*,_ req: MCPRequest*/, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let toolArguments = ToolArguments(arguments: arguments)
      
      let operation = try toolArguments.enumFromString("operation", as: FileReadBytesTool.Input.Operation.self)
      let accessibleUrl = try toolArguments.asAccessibleURL(urlProvider, FileReadBytesTool.Input.Arguments.path.rawValue)
      
      debug("operation:\(operation) path:\(accessibleUrl.path)")
      
      _ = accessibleUrl.rootURL.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo,responseId,arguments,operation,accessibleUrl.path)
      accessibleUrl.rootURL.stopAccessingSecurityScopedResource()
      
      return result
   }
}
