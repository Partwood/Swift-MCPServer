//
//  FileIO.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileReadLinesTool: Content {
   static let resourceName: String = "FileReadLines"
   let name: String
   
   // Helper method to load the description from <resourceName>.md
   static func loadDescription() -> String {
      do {
         if let filePath = Bundle.module.url(forResource: FileReadLinesTool.resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
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
         case readContentRange = "read_lines"
      }

      enum Arguments: String, Codable, CaseIterable {
         case length = "length"
         case offset = "offset"
         case name = "name"
         case path = "path"
      }

      //let operation: Operation
      //let path: String
      //let name: String
      //let content: String? // For write operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+FileReadLinesTool.resourceName.lowercased()
   }
}

public
final
class Tool_FileReadLines {
   let internalDescriptor: Tool
   let tool: FileReadLinesTool
   
   public init(serverName: String) {
      self.tool = FileReadLinesTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileReadLinesTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileReadLinesTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The path to a file or directory"
               ],
               "name": [
                  "type": "string",
                  "description": "The file or directory name"
               ],
               "offset": [
                  "type": "number",
                  "description": "The integer number of lines from the start"
               ],
               "length": [
                  "type": "number",
                  "description": "The integer number of lines to read from the provided offset value. Should not exceed 10"
               ],
            ],
            "required": ["operation", "path", "name", "offset", "length"]
         ])
      )
   }
}

// MARK: Read content
extension Tool_FileReadLines {
   func readFile(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,offset: Int,length: Int) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      var fullContent = Array<Text_Content>()
      
      let FileReadLines: Text_Content
      
      let FileReadLinesString: String?
      do {
         FileReadLinesString = try FileUtils.readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }

      let subString: String?
      
      if let content = FileReadLinesString {
         if let start = content.index(content.startIndex, offsetBy: Int(offset), limitedBy: content.endIndex) {
            let remainder = String(content[start..<content.endIndex])
            let parts = remainder.components(separatedBy: .newlines).prefix(length)
            let joined = parts.joined()
            subString = joined
         } else {
            let message = "End of file, file:'\(FileUtils.fileURL(path: inPath,name).path())'"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
         }
      } else {
         logWarn("No content in file, file:'\(FileUtils.fileURL(path: inPath,name).path())'")
         subString = ""
      }

      if let content = subString {
         FileReadLines = Text_Content(text: content)
         fullContent.append(FileReadLines)
      } else {
         let message = "File not found or has no content, file:'\(FileUtils.fileURL(path: inPath,name).path())'"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: fullContent,serverInfo: serverInfo)
   }
}

// MARK: Offset
extension Tool_FileReadLines {
   public struct OffsetSuccess {
      public var offset: Int
   }
   
   public enum OffsetError: Error {
      case mcpError(response: MCPResponse)
   }
   
   func findByteOffset(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,_ lineOffset: Int) throws -> Int {
      if ( lineOffset == 0 ) {
         return 0
      }
      
      let FileFindContentString: String
      do {
         if let content = try FileUtils.readFileToString(atPath: inPath,name: name) {
            FileFindContentString = content
         } else {
            throw FileIOError.read_error(FileUtils.fileURL(path: inPath, name))
         }
      } catch {
         logError(error)
         throw error
      }
      
      let maxByteOffset = FileFindContentString.utf8.count
      
      // File read, determine byte offset
      let lines = FileFindContentString.components(separatedBy: "\n")
      
      if ( lines.count <= lineOffset ) {
         return maxByteOffset-1
      }
      
      var currentByteOffset = 0
      
      var adjustedOffset = lineOffset+1
      for line in lines {
         adjustedOffset -= 1
         if ( adjustedOffset <= 0 ) {
            // Not a read error, we've reached the correct offset.
            return currentByteOffset
         }
         
         let lineWithNewline = line + "\n"
         currentByteOffset += lineWithNewline.utf8.count
      }
      
      if ( currentByteOffset >= maxByteOffset) {
         return maxByteOffset-1
      }
      
      return currentByteOffset
   }

   // Ensure that the offset value is > 0 and an integer, if using line_offset must have same constraints and be converted
   public func getByteOffset(_ serverInfo: ServerInfo,_ responseId: String,_ lineOffset: Int,path: String,name:String) throws -> Int {
      if ( lineOffset == 0 ) {
         return 0
      } else if ( lineOffset < 0 ) {
         let message = "offset is not a positive integer"
         throw ToolArgumentError.invalid_integer(message: message)
      } else {
         return try findByteOffset(serverInfo,responseId,at: path,name: name,lineOffset)
      }
   }
}

extension Tool_FileReadLines {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ toolArguments: ToolArguments,_ operation: FileReadLinesTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName: String
      let lineOffset: Int
      let length: Int
      let offset: Int

      do {
         fileName = try toolArguments.asString(FileReadLinesTool.Input.Arguments.name.rawValue, allowEmpty: false)
         lineOffset = try toolArguments.asInteger(FileReadLinesTool.Input.Arguments.offset.rawValue,min: 0)
         length = try toolArguments.asInteger(FileReadLinesTool.Input.Arguments.length.rawValue,max: 20)

         offset = try getByteOffset(serverInfo, responseId, lineOffset, path: whichPath, name: fileName)
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
extension Tool_FileReadLines: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   public func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   public func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let toolArguments = ToolArguments(arguments: arguments)
      
      let operation = try toolArguments.enumFromString("operation", as: FileReadLinesTool.Input.Operation.self)
      let accessibleUrl = try toolArguments.asAccessibleURL(urlProvider, FileReadLinesTool.Input.Arguments.path.rawValue)
      
      debug("operation:\(operation) path:\(accessibleUrl.path)")
      
      _ = accessibleUrl.rootURL.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo, responseId, toolArguments, operation, accessibleUrl.path)
      accessibleUrl.rootURL.stopAccessingSecurityScopedResource()

      return result
   }
}
