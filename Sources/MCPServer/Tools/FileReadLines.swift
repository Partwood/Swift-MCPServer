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
   
   static private let MAX_LINES: Int = 100
   
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
                  "description": "Identifies which of the tools operations are to be used",
                  "enum": FileReadLinesTool.Input.Operation.allCases.map({$0.rawValue})
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
                  "description": "The starting position in lines from where the reading begins. Use 0 to start from the beginning.",
                  "minimum": 0,
               ],
               "length": [
                  "type": "number",
                  "description": "The maximum number of lines to retrieve in this single operation. Restrict this to \(Tool_FileReadLines.MAX_LINES) or lower to avoid overflow.",
                  "maximum": Tool_FileReadLines.MAX_LINES,
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
      
      let fullContent: String?
      do {
         fullContent = try FileUtils.readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }

      var subString: String = "Path:'\(FileUtils.fileURL(path: inPath,name).filePath)'\n"
      
      if let content: String = fullContent {
         let components: Array<String> = content.components(separatedBy: .newlines)
         
         if components.count < (offset-1) {
            subString = "End of file.\n"
         } else {
            if components.count < (offset+length) {
               // Caller asked for more than exists, just return whats left
               components[offset...].enumerated().forEach({ eComponent in
                  let value = "Line \(eComponent.offset+offset+1):" + eComponent.element + "\n"
                  subString += value
               })
            } else {
               components[offset..<(offset+length)].enumerated().forEach({ eComponent in
                  let value = "Line \(eComponent.offset+offset+1):" + eComponent.element + "\n"
                  subString += value
               })
            }
         }
         
      } else {
         logWarn("No content in file, file:'\(FileUtils.fileURL(path: inPath,name).filePath)'")
         subString = ""
      }

      let text_content: Text_Content = Text_Content(text: subString.hasSuffix("\n") ? subString: subString+"\n")
      
      return MCPResponse.toolSuccess(id: responseId, content: [text_content],serverInfo: serverInfo)
   }
}

extension Tool_FileReadLines {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ toolArguments: ToolArguments,_ operation: FileReadLinesTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName: String
      let length: Int
      let offset: Int

      do {
         fileName = try toolArguments.asString(FileReadLinesTool.Input.Arguments.name.rawValue, allowEmpty: false)
         offset = try toolArguments.asInteger(FileReadLinesTool.Input.Arguments.offset.rawValue,min: 0)
         length = try toolArguments.asInteger(FileReadLinesTool.Input.Arguments.length.rawValue,max: Tool_FileReadLines.MAX_LINES)
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
