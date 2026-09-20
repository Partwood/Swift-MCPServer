//
//  FileFindContent.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileFindContentTool: Content {
   static let resourceName: String = "FileFindContent"
   let name: String
   
   // Helper method to load the description from <resourceName>.md
   static func loadDescription() -> String {
      do {
         if let filePath = Bundle.module.url(forResource: FileFindContentTool.resourceName, withExtension: "md") {
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
         case findContent = "find_in_file"
      }

      enum Arguments: String, Codable, CaseIterable {
         case find = "find"
         case name = "name"
         case path = "path"
      }

      //let operation: Operation
      //let path: String
      //let name: String
      //let content: String? // For write operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+FileFindContentTool.resourceName.lowercased()
   }
}

public
final
class Tool_FileFindContent {
   let internalDescriptor: Tool
   let tool: FileFindContentTool
   
   public init(serverName: String) {
      self.tool = FileFindContentTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileFindContentTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileFindContentTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The path to a file or directory"
               ],
               "name": [
                  "type": "string",
                  "description": "The file or directory name"
               ],
               "find": [
                  "type": "string",
                  "description": "The string to find in a file"
               ]
            ],
            "required": ["operation", "path", "name", "find"]
         ])
      )
   }
}

// MARK: Find
extension Tool_FileFindContent {
   private struct SearchResult {
      let lineNumber: Int
      let characterOffset: Int
      let byteOffset: Int
   }
   
   private func find(string target: String,content: String) -> [SearchResult] {
      var results: [SearchResult] = []
      let lines = content.components(separatedBy: "\n")
      var currentByteOffset = 0
      var currentCharacterOffset = 0
      
      for (lineIdx, line) in lines.enumerated() {
         // Line indices in editor usually start at 1
         let lineNumber = lineIdx + 1
         
         // Find all occurrences within the current line
         var searchRange = line.startIndex..<line.endIndex
         while let range = line.range(of: target, options: [], range: searchRange) {
            
            // 1. Character distance from start of file
            let charDistance = content.distance(from: content.startIndex, to: range.lowerBound)
            
            // 2. Byte offset (UTF-8)
            let substring = content[..<range.lowerBound]
            let byteOffset = substring.utf8.count
            
            results.append(SearchResult(
               lineNumber: lineNumber,
               characterOffset: charDistance,
               byteOffset: byteOffset
            ))
            
            // Advance search range to find subsequent occurrences on the same line
            searchRange = range.upperBound..<line.endIndex
         }
         
         // Add lengths of line + "\n" to offsets for the next iteration
         let lineWithNewline = line + "\n"
         currentCharacterOffset += lineWithNewline.count
         currentByteOffset += lineWithNewline.utf8.count
      }
      
      return results
   }
   
   func findContent(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,find string:String) -> MCPResponse {
      do {
         if let FileFindContentString = try FileUtils.readFileToString(atPath: inPath,name: name) {
            let searchResults = find(string: string,content: FileFindContentString)
            
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
   
//   func findByteOffset(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,_ lineOffset: Int) -> Result<Int,FileIOError> {
//      if ( lineOffset == 0 ) {
//         return Result<Int,FileIOError>.success(0)
//      }
//      
//      let FileFindContentString: String
//      do {
//         if let content = try FileUtils.readFileToString(atPath: inPath,name: name) {
//            FileFindContentString = content
//         } else {
//            logError("Read error path:\(inPath) name:\(name)")
//            return Result<Int,FileIOError>.failure(FileIOError.read_error(FileUtils.fileURL(path: inPath, name)))
//         }
//      } catch {
//         logError(error)
//         return Result<Int,FileIOError>.failure(FileIOError.read_error(FileUtils.fileURL(path: inPath, name)))
//      }
//      
//      // File read, determine byte offset
//      let lines = FileFindContentString.components(separatedBy: "\n")
//      
//      if ( lines.count <= lineOffset ) {
//         let byteOffset = FileFindContentString.utf8.count
//         return Result<Int,FileIOError>.success(byteOffset)
//      }
//      
//      var currentByteOffset = 0
//      
//      var adjustedOffset = lineOffset+1
//      for line in lines {
//         adjustedOffset -= 1
//         if ( adjustedOffset <= 0 ) {
//            logError("Read error at offset:\(adjustedOffset) path:\(inPath) name:\(name)")
//            return Result<Int,FileIOError>.success(currentByteOffset)
//         }
//         
//         let lineWithNewline = line + "\n"
//         currentByteOffset += lineWithNewline.utf8.count
//      }
//      
//      return Result<Int,FileIOError>.success(currentByteOffset)
//   }
}

extension Tool_FileFindContent {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileFindContentTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName = arguments["name"] as? String ?? ""
      guard !fileName.isEmpty else {
         return MCPResponse.toolError(id: responseId, message: "name not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
      }
      
      switch operation {
      case .findContent:
         guard let content = arguments["find"] as? String,
               !content.isEmpty else {
            let message = "find not provided for operation:'\(operation.rawValue)'"
            logWarn(message)
            return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
         }
         
         return findContent(serverInfo,responseId,at: whichPath,name: fileName,find: content)
      }
   }
}

// MARK: MCPTool
extension Tool_FileFindContent: MCPTool {
   public var name: String { get { return self.tool.name } }
   public var descriptor: Tool { get { return self.internalDescriptor } }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   public func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   public func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."
      
      let possibleOperation = FileFindContentTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileFindContentTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
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
