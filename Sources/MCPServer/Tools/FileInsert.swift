//
//  FileInsert.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

enum FileInsertToolError: Error {
   case resource_not_found
}

struct FileInsertTool: Content {
   let name: String
   
   // Helper method to load the description from FileInsertDescription.md
   static func loadDescription() -> String {
      let resourceName: String = "FileInsert"
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
            throw FileInsertToolError.resource_not_found
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
         case insertContent = "insert"
      }

      enum Arguments: String, Codable, CaseIterable {
         case offset_in_bytes = "offset_in_bytes"
         case line_offset = "line_offset"
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
      name = "mcp_"+serverName+"_FileInsert"
   }
}

enum Tool_FileInsert_Error: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)
}

extension Tool_FileInsert_Error: CustomStringConvertible {
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
class Tool_FileInsert {
   let internalDescriptor: Tool
   let tool: FileInsertTool
   
   public init(serverName: String) {
      self.tool = FileInsertTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileInsertTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileInsertTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
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
               "line_offset": [
                  "type": "number",
                  "description": "The offset in lines as an integer"
               ],
               "offset_in_bytes": [
                  "type": "number",
                  "description": "The offset in bytes as an integer"
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
extension Tool_FileInsert {
   func insertDataIntoFile(_ serverInfo: ServerInfo,_ responseId: String,inPath: String,name:String, atOffset offset: Int, newData: Data) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
      let fileURL = FileUtils.fileURL(path: inPath,name)

      if ( fileURL.isDirectory ) {
         let error = Tool_FileInsert_Error.path_is_directory(fileURL)
         logError(error.description)
         return MCPResponse.toolError(id: responseId,message: error.localizedDescription,serverInfo: serverInfo)
      }

      do {
         if !FileManager.default.fileExists(atPath: tempFileURL.path()) {
            FileManager.default.createFile(atPath: tempFileURL.path(), contents: nil)
         }
         
         let originalHandle = try FileHandle(forReadingFrom: fileURL)
         let tempHandle = try FileHandle(forWritingTo: tempFileURL)
         defer {
            try? originalHandle.close()
            try? tempHandle.close()
         }
         
         // 1. Read up to the offset
         try originalHandle.seek(toOffset: 0)
         if let dataBeforeOffset = try originalHandle.read(upToCount: Int(offset)) {
            // 2. Write to temp file
            try tempHandle.write(contentsOf: dataBeforeOffset)
         }
         
         // 3. Write new data
         try tempHandle.write(contentsOf: newData)
         
         // 4. Read the rest of original and append
         // Seek to the insertion point in the original file again to ensure we get the rest
         try originalHandle.seek(toOffset: UInt64(offset))
         let dataAfterOffset = try originalHandle.readToEnd()
         
         if let dataAfterOffset = dataAfterOffset {
            try tempHandle.write(contentsOf: dataAfterOffset)
         }
         
         // 5. Replace original file
         try FileManager.default.removeItem(at: fileURL)
         try FileManager.default.moveItem(at: tempFileURL, to: fileURL)
         debug("Data inserted successfully at offset \(offset) into file:\(fileURL)")
      } catch {
         let message = "Error inserting data into file:'\(fileURL.path())', error: \(error.localizedDescription)"
         logError(message)
         // Clean up temp file on error
         try? FileManager.default.removeItem(at: tempFileURL)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId,text: "Completed insertion of content into file '\(fileURL.path())'" ,serverInfo: serverInfo)
   }
}

// MARK: Offset
extension Tool_FileInsert {
   public struct OffsetSuccess {
      public var offset: Int
   }
   
   public enum OffsetError: Error {
      case mcpError(response: MCPResponse)
   }

   enum FindError: LocalizedError {
      case read_error
      
      var errorDescription: String? {
         switch self {
         case .read_error:
            return NSLocalizedString("Failed to read file.", comment: "Read error")
         }
      }
   }

   func findByteOffset(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,_ lineOffset: Int) -> Result<Int,FindError> {
      if ( lineOffset == 0 ) {
         return Result<Int,FindError>.success(0)
      }
      
      let fileContentString: String
      do {
         if let content = try FileUtils.readFileToString(atPath: inPath,name: name) {
            fileContentString = content
            
         } else {
            return Result<Int,FindError>.failure(.read_error)
         }
      } catch {
         logError(error)
         return Result<Int,FindError>.failure(.read_error)
      }
      
      // File read, determine byte offset
      let lines = fileContentString.components(separatedBy: "\n")
      
      if ( lines.count <= lineOffset ) {
         let byteOffset = fileContentString.utf8.count
         return Result<Int,FindError>.success(byteOffset)
      }
      
      var currentByteOffset = 0
      
      var adjustedOffset = lineOffset+1
      for line in lines {
         adjustedOffset -= 1
         if ( adjustedOffset <= 0 ) {
            return Result<Int,FindError>.success(currentByteOffset)
         }
         
         let lineWithNewline = line + "\n"
         currentByteOffset += lineWithNewline.utf8.count
      }
      
      return Result<Int,FindError>.success(currentByteOffset)
   }
   
   // Ensure that the offset value is > 0 and an integer, if using line_offset must have same constraints and be converted
   public func getOffset(_ serverInfo: ServerInfo,_ responseId: String,_ arguments: [String : Any],path: String,name:String) -> Result<OffsetSuccess, OffsetError> {
      if let _ = arguments["offset"] {
         // byte offset provided
         if let integerValue = asInteger(arguments, "offset") {
            if ( integerValue < 0 ) {
               let response = MCPResponse.toolError(id: responseId, message: "offset is not a positive integer",serverInfo: serverInfo)
               return Result.failure(OffsetError.mcpError(response: response))
            } else {
               return Result.success(OffsetSuccess(offset: integerValue))
            }
         } else {
            let response = MCPResponse.toolError(id: responseId, message: "offset is not an integer",serverInfo: serverInfo)
            return Result.failure(OffsetError.mcpError(response: response))
         }
      } else if let _ = arguments["line_offset"] {
         if let integerValue = asInteger(arguments, "line_offset") {
            // line offset provided, convert to bytes
            if ( integerValue == 0 ) {
               return Result.success(OffsetSuccess(offset: 0))
            } else if ( integerValue < 0 ) {
               let response = MCPResponse.toolError(id: responseId, message: "line_offset is not a positive integer",serverInfo: serverInfo)
               return Result.failure(OffsetError.mcpError(response: response))
            } else {
               let result = findByteOffset(serverInfo,responseId,at: path,name: name,integerValue)
               switch(result) {
               case .success(let value):
                  return Result.success(OffsetSuccess(offset: value))
               case .failure(let someError):
                  let message = "line_offset error:\(someError.localizedDescription)"
                  logError(message)
                  let response = MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
                  return Result.failure(OffsetError.mcpError(response: response))
               }
            }
         } else {
            let response = MCPResponse.toolError(id: responseId, message: "line_offset is not an integer",serverInfo: serverInfo)
            return Result.failure(OffsetError.mcpError(response: response))
         }
      } else {
         let response = MCPResponse.toolError(id: responseId, message: "offset or line_offset argument not provided",serverInfo: serverInfo)
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

extension Tool_FileInsert {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileInsertTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName = arguments["name"] as? String ?? ""
      guard !fileName.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "name not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }
      
      switch operation {
      case .insertContent:
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
         
         guard let contentString: String = arguments["content"] as? String,
               let data = contentString.data(using: .utf8) else {
            logWarn("content:'\(arguments["content"] ?? "nil")'")
            return MCPResponse.toolError(id: responseId, message: "content not provided or unable to convert the provided content into UTF8 Data",serverInfo: serverInfo)
         }
         
         return insertDataIntoFile(serverInfo,responseId,inPath: whichPath,name: fileName,atOffset: offset,newData: data)
      }
   }
}

// MARK: MCPTool
extension Tool_FileInsert: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   public func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   public func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?/*,_ req: MCPRequest*/, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      //debug("req:\(req.method)")
      
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."
      
      let possibleOperation = FileInsertTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileInsertTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
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
