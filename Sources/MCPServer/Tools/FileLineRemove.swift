//
//  FileLineRemove.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileLineRemoveTool: Content {
   let name: String
   
   // Helper method to load the description from <resourceName>.md
   static func loadDescription() -> String {
      let resourceName: String = "FileLineRemove"
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
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
         case removeContent = "line_remove"
      }

      enum Arguments: String, Codable, CaseIterable {
         case offset = "offset"
         case count = "count"
         case name = "name"
         case path = "path"
      }
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_FileLineRemove"
   }
}

public
final
class Tool_FileLineRemove {
   let internalDescriptor: Tool
   let tool: FileLineRemoveTool
   
   public init(serverName: String) {
      self.tool = FileLineRemoveTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileLineRemoveTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "Identifies which of the tools operations are to be used",
                  "enum": FileLineRemoveTool.Input.Operation.allCases.map({$0.rawValue})
               ],
               "path": [
                  "type": "string",
                  "description": "The absolute directory path to the target file folder (e.g. '/Users/project/src'). Exclude the file name."
               ],
               "name": [
                  "type": "string",
                  "description": "The exact file name including its extension (e.g. 'image.png' or 'config.json')."
               ],
               "count": [
                  "type": "string",
                  "description": "The amount of lines to be removed."
               ],
               "offset": [
                  "type": "number",
                  "description": "The offset in lines as an integer"
               ],
            ],
            "required": ["operation", "path", "name", "offset", "count"]
         ])
      )
   }
}

// MARK: Write content
extension Tool_FileLineRemove {   
   /**
    Basic logic...
    Given a desination file, read original file up to deletion point, write to temp, skip, write remainder
    */
   func removeLines(_ serverInfo: ServerInfo,_ responseId: String,inPath: String,name:String,at offset: Int, count: Int) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let fileURL = FileUtils.fileURL(path: inPath,name)

      let isDirectory: Bool
      do {
         isDirectory = try fileURL.isExistingDirectory()
      } catch {
         let message = "Error inserting data into file:'\(fileURL.filePath)', error: \(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      if ( isDirectory ) {
         let error = FileIOError.path_is_directory(fileURL)
         logError(error.description)
         return MCPResponse.toolError(id: responseId,message: error.localizedDescription,serverInfo: serverInfo)
      }

      if !FileManager.default.fileExists(atPath: fileURL.filePath) {
         // The source file does not exist.
         let error = FileIOError.file_not_found(fileURL)
         logError(error)
         return MCPResponse.toolError(id: responseId,message: error.localizedDescription,serverInfo: serverInfo)
      }
      
      let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)

      do {
         if !FileManager.default.fileExists(atPath: tempFileURL.filePath) {
            FileManager.default.createFile(atPath: tempFileURL.filePath, contents: nil)
         }
         
         let originalHandle = try FileHandle(forReadingFrom: fileURL)
         let tempHandle = try FileHandle(forWritingTo: tempFileURL)
         defer {
            try? originalHandle.close()
            try? tempHandle.close()
         }
         
         // Read up to the offset
         try originalHandle.seek(toOffset: 0)
         if let dataBeforeOffset = try originalHandle.read(upToCount: Int(offset)) {
            // Write to temp file
            try tempHandle.write(contentsOf: dataBeforeOffset)
         }
         
         // Read the rest of original (after offset+count) and append
         // Seek to the insertion point in the original file again to ensure we get the rest
         try originalHandle.seek(toOffset: UInt64(offset+count))
         let dataAfterOffset = try originalHandle.readToEnd()
         
         if let dataAfterOffset = dataAfterOffset {
            try tempHandle.write(contentsOf: dataAfterOffset)
         }
         
         // Replace original file
         try FileManager.default.removeItem(at: fileURL)
         try FileManager.default.moveItem(at: tempFileURL, to: fileURL)
         debug("Data removed successfully at offset \(offset) into file:\(fileURL)")
      } catch {
         let message = "Error inserting data into file:'\(fileURL.filePath)', error: \(error.localizedDescription)"
         logError(message)
         // Clean up temp file on error
         try? FileManager.default.removeItem(at: tempFileURL)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId,text: "Completed removal of lines in file '\(fileURL.filePath)'" ,serverInfo: serverInfo)
   }
}

extension Tool_FileLineRemove {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String,_ toolArguments: ToolArguments,_ operation: FileLineRemoveTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName: String
      let offset: Int
      let count: Int
      
      do {
         fileName = try toolArguments.asString(FileLineRemoveTool.Input.Arguments.name.rawValue, allowEmpty: false)
         offset = try toolArguments.asInteger(FileLineRemoveTool.Input.Arguments.offset.rawValue,min: 0)
         count = try toolArguments.asInteger(FileLineRemoveTool.Input.Arguments.count.rawValue,min: 1)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: "For operation:'\(operation.rawValue)' \(error.localizedDescription)", serverInfo: serverInfo)
      }
      
      switch operation {
      case .removeContent:
         return removeLines(serverInfo,responseId,inPath: whichPath,name: fileName,at: offset,count: count)
      }
   }
}

// MARK: MCPTool
extension Tool_FileLineRemove: MCPTool {
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
      
      let operation = try toolArguments.enumFromString("operation", as: FileLineRemoveTool.Input.Operation.self)
      let accessibleUrl = try toolArguments.asAccessibleURL(urlProvider, FileLineRemoveTool.Input.Arguments.path.rawValue)
      
      debug("operation:\(operation) path:\(accessibleUrl.path)")
      
      _ = accessibleUrl.rootURL.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo, responseId, toolArguments, operation, accessibleUrl.path)
      accessibleUrl.rootURL.stopAccessingSecurityScopedResource()
      
      return result
   }
}
