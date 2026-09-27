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
                  "description": "The regex pattern to find in the file content"
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
   
   func searchWithRegex(regex: NSRegularExpression, in content: String, caseInsensitive: Bool = false) -> [Range<String.Index>] {
      // Perform the search.
      let matches = regex.matches(
         in: content,
         range: NSRange(content.startIndex..., in: content)
      )
      
      // Extract the matched substrings.
      let matchedRanges: [Range<String.Index>] = matches.compactMap({ match in
         let range = match.range(at: 0)
         
         if let stringRange = Range(range, in: content) {
            return stringRange
         }
         
         return nil
      })
      
      return matchedRanges
   }
   
   private func find(string pattern: String,content: String,caseInsensitive: Bool = true) -> [SearchResult] {
      // Convert the input pattern to a regular expression.
      // This allows the caller to use wildcards like `*.` or regex variants like `a{2,}?`.
      let regex = try! NSRegularExpression (
         pattern: pattern,
         options: caseInsensitive ? [.caseInsensitive, .anchorsMatchLines] : [.anchorsMatchLines]
      )
      
      var results: [SearchResult] = []
      let lines = content.components(separatedBy: "\n")
      var currentByteOffset = 0
      var currentCharacterOffset = 0
      
      for (lineIdx, line) in lines.enumerated() {
         // Line indices in editor usually start at 1
         let lineNumber = lineIdx + 1
         
         // Find all occurrences within the current line
         let ranges = searchWithRegex(regex: regex, in: line)
         ranges.forEach({ range in
            // Character distance from start of file
            let charDistance = content.distance(from: content.startIndex, to: range.lowerBound)
            
            // Byte offset (UTF-8)
            let substring = content[..<range.lowerBound]
            let byteOffset = substring.utf8.count
            
            results.append(SearchResult(
               lineNumber: lineNumber,
               characterOffset: charDistance,
               byteOffset: byteOffset
            ))
         })
         
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
}

extension Tool_FileFindContent {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ toolArguments: ToolArguments,_ operation: FileFindContentTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName: String
      let find: String
      do {
         fileName = try toolArguments.asString("name", allowEmpty: false)
         find = try toolArguments.asString("find", allowEmpty: false)
      } catch {
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
      
      switch operation {
      case .findContent:
         return findContent(serverInfo,responseId,at: whichPath,name: fileName,find: find)
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
      let toolArguments = ToolArguments(arguments: arguments)
      
      let operation = try toolArguments.enumFromString("operation", as: FileFindContentTool.Input.Operation.self)
      let accessibleURL = try toolArguments.asAccessibleURL(urlProvider, "path")
      
      debug("operation:\(operation) path:\(accessibleURL.path)")
      
      _ = accessibleURL.rootURL.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo, responseId, toolArguments, operation, accessibleURL.path)
      accessibleURL.rootURL.stopAccessingSecurityScopedResource()
      return result
   }
}
