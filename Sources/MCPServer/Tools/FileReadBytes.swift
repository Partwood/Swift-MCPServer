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

      //let operation: Operation
      //let path: String
      //let name: String
      //let content: String? // For write operations
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
                  "description": "One of the following values:"+FileReadBytesTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
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
                  "description": "The offset in bytes as an integer"
               ],
               "length": [
                  "type": "number",
                  "description": "The length in bytes as an integer"
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
            let message = "End of file, file:'\(FileUtils.fileURL(path: inPath,name).path())'"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
         }
      } else {
         logWarn("No content in file, file:'\(FileUtils.fileURL(path: inPath,name).path())'")
         subString = ""
      }

      if let content = subString {
         FileReadBytes = Text_Content(text: content)
         fullContent.append(FileReadBytes)
      } else {
         let message = "File not found or has no content, file:'\(FileUtils.fileURL(path: inPath,name).path())'"
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

extension Tool_FileReadBytes {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileReadBytesTool.Input.Operation,_ whichPath: String) -> MCPResponse {
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
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."
      
      let possibleOperation = FileReadBytesTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileReadBytesTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
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
