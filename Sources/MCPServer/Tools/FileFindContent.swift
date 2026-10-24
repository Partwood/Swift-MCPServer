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
         case findContent = "find_in_path"
      }

      enum Arguments: String, Codable, CaseIterable {
         case find = "find"
         case path = "path"
      }
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
                  "description": "Identifies which of the tools operations are to be used",
                  "enum": FileFindContentTool.Input.Operation.allCases.map({$0.rawValue})
               ],
               "path": [
                  "type": "string",
                  "description": "The absolute directory path to the target file folder (e.g. '/Users/project/src'). Exclude the file name."
               ],
               "find": [
                  "type": "string",
                  "description": "The regex pattern to find in the file content"
               ]
            ],
            "required": ["operation", "path", "find"]
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
   
   func searchWithRegex(regex: Regex<AnyRegexOutput>/*NSRegularExpression*/, in content: String, caseInsensitive: Bool = false) -> [Range<String.Index>] {
      // Perform the search.
      let matches = content.matches(of: regex)
      return matches.map { $0.range }
//      let matches = regex.matches(
//         in: content,
//         range: NSRange(content.startIndex..., in: content)
//      )
      
      // Extract the matched substrings.
//      let matchedRanges: [Range<String.Index>] = matches.compactMap({ match in
//         let range = match.range
//         //let range = match.range(at: 0)
//         
//         if let stringRange = Range(range, in: content) {
//            return stringRange
//         }
//         
//         return nil
//      })
//      
//      return matchedRanges
   }
   
   private func find(string pattern: String,content: String,caseInsensitive: Bool = true) throws -> [SearchResult] {
      // Convert the input pattern to a regular expression.
      // This allows the caller to use wildcards like `*.` or regex variants like `a{2,}?`.
      //let regex: Regex//: NSRegularExpression
      
      do {
         let regex = try Regex(pattern)//NSRegularExpression (
            //pattern: pattern,
            //options: caseInsensitive ? [.caseInsensitive, .anchorsMatchLines] : [.anchorsMatchLines]
         //)

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
      } catch {
         let regExError = RegExError.invalid_pattern(pattern, error)
         logError(regExError)
         throw regExError
      }
      
   }
   
   private func findContent(at url: URL,content: String) -> Array<String> {
      var result = Array<String>()
      
      do {
         let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)

         contents.forEach({ fileURL in
            if ( fileURL.lastPathComponent.hasPrefix(".")) {
               // Skip any '.' files
               return
            }
            
            do {
               let directory: Bool = try fileURL.isExistingDirectory()
               if directory {
                  result.append(contentsOf: findContent(at: fileURL, content: content))
               } else {
                  if findContentInFile(in: fileURL, content: content) {
                     result.append("- Path:'\(fileURL.filePath)'")
                  }
               }
            } catch {
               logError(error)
            }
         })
      } catch {
         logError(error)
      }
      
      if !result.isEmpty {
         result.insert("Found '" + content + "'", at: 0)
      } else {
         result.append("Didn't find '" + content + "'")
      }
      
      return result
   }
      
   private func findContentInFile(in url: URL,content: String) -> Bool {
      do {
         if let fileContent = try FileUtils.readFileToString(file: url) {
            let searchResults = try find(string: content,content: fileContent)
            return !searchResults.isEmpty
         }
      } catch {
         logError(error)
      }
      
      return false
   }

   func findContent(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,find string:String) -> MCPResponse {
      let path = NSString(string: inPath).expandingTildeInPath
      let decodedRoot: String = path.removingPercentEncoding ?? path
      let directoryURL: URL = URL(fileURLWithPath: decodedRoot)

      let contents = findContent(at: directoryURL, content: string)
      let textContent = Text_Content(text: contents.joined(separator: "\n"))
      
      return MCPResponse.toolSuccess(id: responseId, content: [textContent], serverInfo: serverInfo)
   }
}

extension Tool_FileFindContent {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ toolArguments: ToolArguments,_ operation: FileFindContentTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let find: String
      do {
         find = try toolArguments.asString("find", allowEmpty: false)
      } catch {
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
      
      switch operation {
      case .findContent:
         return findContent(serverInfo,responseId,at: whichPath,find: find)
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
