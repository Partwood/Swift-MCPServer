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
         case length_in_bytes = "length"
         case offset_in_bytes = "offset"
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
                  "description": "The integer number of lines to read from the provided offset value"
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
   
   func findByteOffset(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,_ lineOffset: Int) -> Result<Int,FileIOError> {
      if ( lineOffset == 0 ) {
         return Result<Int,FileIOError>.success(0)
      }
      
      let FileFindContentString: String
      do {
         if let content = try FileUtils.readFileToString(atPath: inPath,name: name) {
            FileFindContentString = content
         } else {
            logError("Read error path:\(inPath) name:\(name)")
            return Result<Int,FileIOError>.failure(FileIOError.read_error(FileUtils.fileURL(path: inPath, name)))
         }
      } catch {
         logError(error)
         return Result<Int,FileIOError>.failure(FileIOError.read_error(FileUtils.fileURL(path: inPath, name)))
      }
      
      // File read, determine byte offset
      let lines = FileFindContentString.components(separatedBy: "\n")
      
      if ( lines.count <= lineOffset ) {
         let byteOffset = FileFindContentString.utf8.count
         return Result<Int,FileIOError>.success(byteOffset)
      }
      
      var currentByteOffset = 0
      
      var adjustedOffset = lineOffset+1
      for line in lines {
         adjustedOffset -= 1
         if ( adjustedOffset <= 0 ) {
            logError("Read error at offset:\(adjustedOffset) path:\(inPath) name:\(name)")
            return Result<Int,FileIOError>.success(currentByteOffset)
         }
         
         let lineWithNewline = line + "\n"
         currentByteOffset += lineWithNewline.utf8.count
      }
      
      return Result<Int,FileIOError>.success(currentByteOffset)
   }

   // Ensure that the offset value is > 0 and an integer, if using line_offset must have same constraints and be converted
   public func getOffset(_ serverInfo: ServerInfo,_ responseId: String,_ arguments: [String : Any],path: String,name:String) -> Result<OffsetSuccess, OffsetError> {
      if let _ = arguments["offset"] {
         if let integerValue = asInteger(arguments, "offset") {
            // line offset provided, convert to bytes
            if ( integerValue == 0 ) {
               return Result.success(OffsetSuccess(offset: 0))
            } else if ( integerValue < 0 ) {
               let response = MCPResponse.toolError(id: responseId, message: "offset is not a positive integer",serverInfo: serverInfo)
               return Result.failure(OffsetError.mcpError(response: response))
            } else {
               let result = findByteOffset(serverInfo,responseId,at: path,name: name,integerValue)
               switch(result) {
               case .success(let value):
                  return Result.success(OffsetSuccess(offset: value))
               case .failure(let someError):
                  let message = "offset error:\(someError.localizedDescription)"
                  logError(message)
                  let response = MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
                  return Result.failure(OffsetError.mcpError(response: response))
               }
            }
         } else {
            let response = MCPResponse.toolError(id: responseId, message: "offset is not an integer",serverInfo: serverInfo)
            return Result.failure(OffsetError.mcpError(response: response))
         }
      } else {
         let response = MCPResponse.toolError(id: responseId, message: "offset argument not provided",serverInfo: serverInfo)
         return Result.failure(OffsetError.mcpError(response: response))
      }
   }
   
   public func asInteger(_ arguments: [String : Any],_ key: String) -> Int? {
      if let intValue: Int = arguments[key] as? Int {
         return intValue
      } else if let valueString: String = arguments[key] as? String,
                let intValue: Int = Int(valueString) {
         return intValue
      } else {
         logWarn("\(key):'\(arguments[key] ?? "nil")' type:\(arguments[key].self ?? "nil")")
         return nil
      }
   }
}

extension Tool_FileReadLines {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileReadLinesTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName = arguments["name"] as? String ?? ""
      guard !fileName.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "name not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }
      
      switch operation {
      case .readContentRange:
         let offset: Int
         
         let offsetResult = getOffset(serverInfo, responseId, arguments, path: whichPath, name: fileName)
         switch(offsetResult) {
         case .success(let value):
            offset = value.offset
         case .failure(let offsetError):
            switch(offsetError) {
            case .mcpError(let response):
               return response
            }
         }
         
         let enumValue = FileReadBytesTool.Input.Arguments.length.rawValue
         guard let length = asInteger(arguments, enumValue) else {
            return MCPResponse.toolError(id: responseId, message: "\(enumValue) argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }

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
   
   public func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?/*,_ req: MCPRequest*/, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."
      
      let possibleOperation = FileReadLinesTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileReadLinesTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      guard let url = FileUtils.accessibleURL(urlProvider,inPath) else {
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
