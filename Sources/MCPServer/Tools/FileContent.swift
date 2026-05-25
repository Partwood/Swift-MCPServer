//
//  FileIO.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileContentTool: Content {
   let name: String
   static let description = "Perform file operations like reading and writing files, inserting and appending to files, and finding string occurences in a file."
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case findContent = "find_in_file"
         case readContent = "read_all"
         case readContentRange = "read_range"
         case writeContent = "write_all"
         case insertContent = "insert"
         case appendContent = "append"
      }
      
      //let operation: Operation
      //let path: String
      //let name: String
      //let content: String? // For write operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_filecontent"
   }
}

enum Tool_FileContent_Error: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)
}

extension Tool_FileContent_Error: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .path_is_directory(let url):
         return NSLocalizedString("Operation error: '\(url)' is a directory", comment: "Unexpected directory")
      case .path_is_file(let url):
         return NSLocalizedString("Operation error: '\(url)' is a file", comment: "Unexpected file")
      }
   }
}

final
class Tool_FileContent {
   let internalDescriptor: Tool
   let tool: FileContentTool
   
   init(serverName: String) {
      self.tool = FileContentTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileContentTool.description,
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileContentTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The location on disk, using the appropriate format for mac, windows or linux"
               ],
               "name": [
                  "type": "string",
                  "description": "The file or directory name to read, write or find within the path provided"
               ],
               "content": [
                  "type": "string",
                  "description": "The content of a file to be either written entirely or inserted"
               ],
               "offset": [
                  "type": "number",
                  "description": "When inserting content into a file the location (as an integer) to start the insertion"
               ],
               "length": [
                  "type": "number",
                  "description": "When reading a range, this the amount (as an integer) to read starting at the specified offset"
               ],
               "find": [
                  "type": "string",
                  "description": "The string to search for within a file"
               ]
            ],
            "required": ["operation", "path", "name"]
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
extension Tool_FileContent {
   private func readFileToString(atPath path: String,name: String) throws -> String? {
      let fileURL = fileURL(path: path,name)
      
      if ( fileURL.isDirectory ) {
         let error = Tool_FileContent_Error.path_is_directory(fileURL)
         logError(error)
         throw error
      }
      
      do {
         // Read file contents as Data
         let fileData = try Data(contentsOf: fileURL)
         
         // Convert to String using UTF-8 encoding
         return String(data: fileData, encoding: .utf8)
      } catch {
         logError("Error reading file:'\(fileURL.path)' error:'\(error.localizedDescription)'")
         throw error
      }
   }
   
   func readFile(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }

      var fullContent = Array<Text_Content>()
      
      let fileContent: Text_Content
      
      let stringContent: String?
      do {
         stringContent = try readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }
      
      if let content = stringContent {
         fileContent = Text_Content(text: content)
         fullContent.append(fileContent)
      } else {
         return MCPResponse.toolError(id: responseId, message: "File not found or has no content, file:'\(fileURL(path: inPath,name).path())'", serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: fullContent,serverInfo: serverInfo)
   }

   func readFile(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,offset: Int,length: Int) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      var fullContent = Array<Text_Content>()
      
      let fileContent: Text_Content
      
      let fileContentString: String?
      do {
         fileContentString = try readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
      }

      let subString: String?
      
      if let content = fileContentString {
         if let start = content.index(content.startIndex, offsetBy: Int(offset), limitedBy: content.endIndex) {
            let end = content.index(content.startIndex, offsetBy: Int(offset+length), limitedBy: content.endIndex) ?? content.endIndex
            subString = String(content[start..<end])
         } else {
            let message = "End of file, file:'\(fileURL(path: inPath,name).path())'"
            debug(message)
            return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
         }
      } else {
         logWarn("No content in file, file:'\(fileURL(path: inPath,name).path())'")
         subString = ""
      }

      if let content = subString {
         fileContent = Text_Content(text: content)
         fullContent.append(fileContent)
      } else {
         return MCPResponse.toolError(id: responseId, message: "File not found or has no content, file:'\(fileURL(path: inPath,name).path())'", serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: fullContent,serverInfo: serverInfo)
   }
}

// MARK: Write content
extension Tool_FileContent {
   func writeFile(_ serverInfo: ServerInfo,_ responseId: String,at path: String,name: String,with content: String) -> MCPResponse {
      if ( path.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let fileURL = fileURL(path: path,name)
      
      if ( fileURL.isDirectory ) {
         let error = Tool_FileContent_Error.path_is_directory(fileURL)
         logError(error.description)
         return MCPResponse.toolError(id: responseId,message: error.localizedDescription,serverInfo: serverInfo)
      }
      
      let fileString = fileURL.path(percentEncoded: false)
      let pathURL = fileURL.deletingLastPathComponent()
      
      do {
         // Create the directory if it doesn't exist
         try FileManager.default.createDirectory(at: pathURL,
                                                 withIntermediateDirectories: true)
         
         // Write the content to file
         try content.write(toFile: fileString, atomically: true, encoding: .utf8)
      } catch {
         let message = "Error writing to file:'\(fileString)', error:'\(error.localizedDescription)'"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, text: "Successfully wrote the content to file:'\(fileString)'",serverInfo: serverInfo)
   }

   func insertDataIntoFile(_ serverInfo: ServerInfo,_ responseId: String,inPath: String,name:String, atOffset offset: Int, newData: Data) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
      let fileURL = fileURL(path: inPath,name)

      if ( fileURL.isDirectory ) {
         let error = Tool_FileContent_Error.path_is_directory(fileURL)
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

   private func fileURL(path inPath: String,_ name: String) -> URL {
      // Convert the tilde path (~/) to an absolute path
      let expandedPath = NSString(string: inPath).expandingTildeInPath
      let root = URL(fileURLWithPath: expandedPath)
      
      if root.lastPathComponent == name {
         // Allow for cases where the name is already part of the path
         return root
      } else {
         return root.appendingPathComponent(name)
      }
   }
   
   func appendToFile(_ serverInfo: ServerInfo,_ responseId: String,at path: String,name: String,with content: String) -> MCPResponse {
      if ( path.contains("%20") ) {
         logWarn("Invalid string!!!")
      }

      let fileURL = fileURL(path: path,name)
      
      if ( fileURL.isDirectory ) {
         let error = Tool_FileContent_Error.path_is_directory(fileURL)
         logError(error.description)
         return MCPResponse.toolError(id: responseId,message: error.localizedDescription,serverInfo: serverInfo)
      }

      let fileString = fileURL.path(percentEncoded: false)

      do {
         // Read existing content if file exists
         var existingContent = ""
         if FileManager.default.fileExists(atPath: fileString) {
            existingContent = try String(contentsOfFile: fileString, encoding: .utf8)
         }
         
         // Append new content
         let newContent = existingContent + content
         
         // Write the combined content back to file
         try newContent.write(toFile: fileString, atomically: true, encoding: .utf8)
      } catch {
         let message = "Error appending to file '\(fileString)', error: \(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, text: "Successfully appended the content to file:'\(fileString)'",serverInfo: serverInfo)
   }
}

// MARK: Find
extension Tool_FileContent {
   func find(_ serverInfo: ServerInfo,_ responseId: String,in rootPath: String,named name: String,directory: Bool) -> MCPResponse {
      let expandedRootPath = NSString(string: rootPath).expandingTildeInPath
      let fileManager = FileManager.default
      var foundFiles = [Text_Content]()
      
      do {
         // Get the contents of the root directory
         let rootURL = URL(fileURLWithPath: expandedRootPath)
         let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if item.lastPathComponent == name && ( directory == isDirectory ) {
               // Found the file/directory directly in the root
               foundFiles.append(Text_Content(text: "Found '" + name + "' at path: " + item.path))
            }
            
            if isDirectory {
               // Recursively search in subdirectories
               let foundInSubdirs = try find(in: item.path, named: name,directory: directory)
               for foundItem in foundInSubdirs {
                  foundFiles.append(foundItem)
               }
            }
         }
      } catch {
         let message = "Error searching for file:'\(name)', error:'\(error.localizedDescription)'"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
      }
      
      if foundFiles.isEmpty {
         return MCPResponse.toolSuccess(id: responseId, text: "No file or directory named '" + name + "' found in '" + rootPath + "'", serverInfo: serverInfo)
      } else {
         return MCPResponse.toolSuccess(id: responseId, content: foundFiles, serverInfo: serverInfo)
      }
   }

   private func find(in directoryPath: String, named name: String,directory: Bool) throws -> [Text_Content] {
      let fileManager = FileManager.default
      var foundItems = [Text_Content]()
      
      do {
         let directoryURL = URL(fileURLWithPath: directoryPath)
         let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if item.lastPathComponent == name && ( directory == isDirectory ) {
               foundItems.append(Text_Content(text: "Found '" + name + "' at path: " + item.path))
            }
            
            if isDirectory {
               // Recursively search in subdirectories
               let foundInSubdirs = try find(in: item.path, named: name,directory: directory)
               for foundItem in foundInSubdirs {
                  foundItems.append(foundItem)
               }
            }
         }
      } catch {
         throw error
      }
      
      return foundItems
   }
   
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
         if let fileContentString = try readFileToString(atPath: inPath,name: name) {
            let searchResults = find(string: string,content: fileContentString)
            
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

extension Tool_FileContent {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileContentTool.Input.Operation,_ whichPath: String) -> MCPResponse {
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
      case .readContent:
         return readFile(serverInfo,responseId,at: whichPath,name: fileName)
      case .readContentRange:
         guard let offset = asInteger(arguments,"offset") else {
            return MCPResponse.toolError(id: responseId, message: "offset argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }
         guard let length = asInteger(arguments, "length") else {
            return MCPResponse.toolError(id: responseId, message: "length argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }

         return readFile(serverInfo,responseId,at: whichPath,name: fileName,offset: offset,length: length)
      case .writeContent:
         let whichContent: String = arguments["content"] as? String ?? ""
         guard !whichContent.isEmpty else {
            logWarn("content:'\(arguments["content"] ?? "nil")'")
            return MCPResponse.toolError(id: responseId, message: "content not provided for operation:'\(operation.rawValue)'",serverInfo: serverInfo)
         }

         return writeFile(serverInfo,responseId,at: whichPath,name: fileName,with: whichContent)
      case .insertContent:
         guard let offset = asInteger(arguments,"offset") else {
            return MCPResponse.toolError(id: responseId, message: "offset argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }

         guard let contentString: String = arguments["content"] as? String,
               let data = contentString.data(using: .utf8) else {
            logWarn("content:'\(arguments["content"] ?? "nil")'")
            return MCPResponse.toolError(id: responseId, message: "content not provided or unable to convert the provided content into UTF8 Data",serverInfo: serverInfo)
         }
         
         return insertDataIntoFile(serverInfo,responseId,inPath: whichPath,name: fileName,atOffset: offset,newData: data)
      case .appendContent:
         let whichContent: String = arguments["content"] as? String ?? ""
         guard !whichContent.isEmpty else {
            logWarn("content:'\(arguments["content"] ?? "nil")'")
            return MCPResponse.toolError(id: responseId, message: "content not provided for operation:'\(operation.rawValue)'",serverInfo: serverInfo)
         }

         return appendToFile(serverInfo,responseId,at: whichPath,name: fileName,with: whichContent)
      }
   }
   
   private func asInteger(_ arguments: [String : Any],_ key: String) -> Int? {
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

// MARK: MCPTool
extension Tool_FileContent: MCPTool {
   var name: String { get { return self.tool.name } }
   var descriptor: Tool { get { return self.internalDescriptor } }
   
   var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?,_ req: MCPRequest, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      debug("req:\(req.method)")
      
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."
      
      let possibleOperation = FileContentTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileContentTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
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
