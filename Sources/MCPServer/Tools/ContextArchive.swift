//
//  ContextArchive.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

enum ContextArchiveToolError: Error {
   case resource_not_found
   
}
struct ContextArchiveTool: Content {
   let name: String
   
   // Helper method to load the description from ContextArchiveDescription.md
   static func loadDescription() -> String {
      let resourceName: String = "ContextArchiveDescription"
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
            throw ContextArchiveToolError.resource_not_found
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
         case find = "find"
         case read = "read"
         case read_range = "read_range"
      }
      
      enum Arguments: String, Codable, CaseIterable {
         case path = "path"
         case string = "string"
         case offset_in_bytes = "offset_in_bytes"
         case line_offset = "line_offset"
         case length_in_bytes = "length_in_bytes"

      }
      
      //let operation: Operation
      //let path: String
      //let name: String
      //let content: String? // For write operations
   }

   init(serverName: String) {
      name = "mcp_"+serverName+"_ContextArchive"
   }
}

enum Tool_ContextArchive_Error: LocalizedError {
   case not_found
   case path_is_directory(_ url: URL)
}

extension Tool_ContextArchive_Error: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .not_found:
         return NSLocalizedString("There is no current context archive.", comment: "Unexpected directory")
      case .path_is_directory(let url):
         return NSLocalizedString("Operation error: '\(url)' is a directory", comment: "Unexpected directory")
      }
   }
}

final
class Tool_ContextArchive {
   let internalDescriptor: Tool
   let tool: ContextArchiveTool
   
   init(serverName: String) {
      self.tool = ContextArchiveTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: ContextArchiveTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+ContextArchiveTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The directory path for the context archive"
               ],
               "string": [
                  "type": "string",
                  "description": "A string used when searching"
               ],
               "line_offset": [
                  "type": "number",
                  "description": "The offset in lines as an integer"
               ],
               "offset_in_bytes": [
                  "type": "number",
                  "description": "The offset in bytes as an integer"
               ],
               "length_in_bytes": [
                  "type": "number",
                  "description": "The length in bytes as an integer"
               ],
            ],
            "required": ["operation", "path"]
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
extension Tool_ContextArchive {
   func readContent(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }

      var fullContent = Array<Text_Content>()
      
      let ContextArchive: Text_Content
      
      let stringContent: String?
      do {
         stringContent = try FileUtils.readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
      
      if let content = stringContent {
         ContextArchive = Text_Content(text: content)
         fullContent.append(ContextArchive)
      } else {
         let filePath = FileUtils.fileURL(path: inPath,name).path()
         return MCPResponse.toolError(id: responseId, message: "File not found or has no content, file:'\(filePath)'", serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: fullContent,serverInfo: serverInfo)
   }
}

// MARK: Find content
extension Tool_ContextArchive {
   func findContent(_ serverInfo: ServerInfo,responseId: String,at inPath: String,name: String,string: String) -> MCPResponse {
      do {
         if let fileContentString: String = try FileUtils.readFileToString(atPath: inPath,name: name) {
            let searchResults: [FileUtils.SearchResult] = FileUtils.find(string: string,content: fileContentString)
            
            var results = [Text_Content]()
            
            for result in searchResults {
               let textContent = Text_Content(text: "Found '" + string + "' on line:\(result.lineNumber) at char offset:\(result.characterOffset), byte offset:\(result.byteOffset)")
               results.append(textContent)
            }
            
            return MCPResponse.toolSuccess(id: responseId, content: results, serverInfo: serverInfo)
         } else {
            let message = "No UTF8 string content present in file:\(name)"
            logWarn(message)
            return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
         }
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
   }
}

extension Tool_ContextArchive {
   private func handleOperation(_ serverInfo: ServerInfo,
                                _ responseId: String,
                                _ arguments: [String : Any],
                                _ operation: ContextArchiveTool.Input.Operation,
                                _ whichPath: String,
                                _ providerId: UUID) -> MCPResponse {
      let context_archive = "context_archive_\(providerId.uuidString).md"
      
      switch operation {
      case .find:
         guard let inString: String = arguments["string"] as? String else {
            let message = "String argument not provided."
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }
         
         return self.findContent(serverInfo, responseId: responseId, at: whichPath, name: context_archive, string: inString)
      case .read:
         return readContent(serverInfo,responseId,at: whichPath,name: context_archive)
      case .read_range:
         let fileContentTool = Tool_FileContent(serverName: self.name)
         
         let offset: Int
         
         let offsetResult = fileContentTool.getOffset(serverInfo, responseId, arguments, path: whichPath, name: context_archive)
         switch(offsetResult) {
         case .success(let value):
            offset = value.offset
         case .failure(let offsetError):
            switch(offsetError) {
            case .mcpError(let response):
               return response
            }
         }
         
         guard let length = fileContentTool.asInteger(arguments, "length_in_bytes") else {
            return MCPResponse.toolError(id: responseId, message: "length_in_bytes argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }
         
         let result = FileUtils.readFileOffset(serverInfo,responseId,at: whichPath,name: context_archive,offset: offset,length: length)
         switch(result) {
         case .success(let fileRead):
            return MCPResponse.toolSuccess(id: responseId, content: fileRead.content, serverInfo: serverInfo)
         case .failure(let fileReadError):
            switch(fileReadError) {
            case .error(message: let message, root: let root):
               return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
            case .eof(message: let message):
               return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
            }
         }
      }
   }
}

// MARK: MCPTool
extension Tool_ContextArchive: MCPTool {
   var name: String { get { return self.tool.name } }
   var descriptor: Tool { get { return self.internalDescriptor } }
   
   var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      guard let argOperation = arguments["operation"] as? String else {
         let operations = ContextArchiveTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Operation argument not provided, valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      let inOperation: String = (argOperation).lowercased()
      
      guard let inPath: String = arguments["path"] as? String else {
         let message = "Path argument not provided."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      let possibleOperation = ContextArchiveTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = ContextArchiveTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
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
      
      guard let providerId: UUID = urlProvider?.provider else {
         let message = "providerId id is not present"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      _ = url.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo, responseId, arguments, operation, inPath, providerId)
      url.stopAccessingSecurityScopedResource()
      return result
   }
}
