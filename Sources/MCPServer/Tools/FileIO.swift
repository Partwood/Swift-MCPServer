//
//  FileIO.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileSystemTool: Content {
   let name: String
   static let description = "Perform file system operations like reading and writing files, creating directories, listing directory contents, inserting and appending to files and recursively finding a file or directory under a path."
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case listDirectory = "list"
         case createDirectory = "create_directory"
         case findFile = "recursive_find_file"
         case findDir = "recursive_find_dir"
         case readContent = "readAll"
         case readContentRange = "readRange"
         case writeContent = "writeAll"
         case insertContent = "insert"
         case appendContent = "append"
//         case deleteFile
//         case moveFile
//         case copyFile
         var requiresFileName: Bool {
            get {
               switch(self){
               case .readContent,.writeContent,.insertContent,.appendContent:
                  return true
               default:
                  return false
               }
            }
         }
      }
      
      //let operation: Operation
      //let path: String
      //let content: String? // For write operations
      //let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_filesystem"
   }
}

enum Tool_FileSystem_Error: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)
}

extension Tool_FileSystem_Error: CustomStringConvertible {
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
class Tool_FileSystem {
   let internalDescriptor: Tool
   let tool: FileSystemTool
   
   init(serverName: String) {
      self.tool = FileSystemTool(serverName: serverName)
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: FileSystemTool.description,
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileSystemTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The location on disk, using the appropriate format for mac, windows or linux"
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
               "fileName": [
                  "type": "string",
                  "description": "The file or directory name to read, write or find within the path provided"
               ],
               //               "destination": [
               //                  "type": "string",
               //                  "description": "The destination location on disk if the operation is move or copy"
               //               ],
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
   
   func createDir(_ serverInfo: ServerInfo,_ responseId: String,at path: String) -> MCPResponse {
      // Convert the tilde path (~/) to an absolute path
      let expandedPath = NSString(string: path).expandingTildeInPath
      
      do {
         // Create the directory if it doesn't exist
         let directoryURL = URL(fileURLWithPath: expandedPath)
         try FileManager.default.createDirectory(at: directoryURL,
                                                 withIntermediateDirectories: true)
         
         debug("Successfully created '\(directoryURL.path)'")
      } catch {
         let message = "Error creating directory, error:\(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, text: "Successfully created directory '\(path)'",serverInfo: serverInfo)
   }
   
   private func readFileToString(atPath path: String,name: String) throws -> String? {
      let fileURL = fileURL(path: path,name)
      
      if ( fileURL.isDirectory ) {
         let error = Tool_FileSystem_Error.path_is_directory(fileURL)
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

   func readFile(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,offset: UInt64,length: UInt64) -> MCPResponse {
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
         logWarn("No content in file.")
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

   func listDirectory(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String) -> MCPResponse {
      let fileManager = FileManager.default
      
      let path = NSString(string: inPath).expandingTildeInPath
      let directoryURL = URL(fileURLWithPath: path)
      
      var files = Array<Text_Content>()
      
      let decodedRoot: String = path.removingPercentEncoding ?? path
      
      do {
         // Get contents (files and subfolders)
         let directoryContents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
         let _ = directoryContents.map { file in
            if ( file.lastPathComponent.hasPrefix(".") ) {
               // Ignore any fie that starts with .
               return
            }
            
            do {
               let decodedPath: String = (file.path() as NSString).removingPercentEncoding ?? file.path()
               
               let attributes = try fileManager.attributesOfItem(atPath: decodedPath)
               //debug("File attributes: \(attributes)")
               
               let fileAttributes: Text_Content
               
               let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
               if ( isDirectory ) {
                  if let fileType = attributes[FileAttributeKey.type] as? String,
                     let _ = attributes[FileAttributeKey.creationDate] as? Date,
                     let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
                     let _ = attributes[FileAttributeKey.posixPermissions] as? Int {
                     
                     fileAttributes = Text_Content(text: "Directory '\(file.lastPathComponent)' is modified \(modifiedDate.timeIntervalSince1970) with type \(fileType) in directory '\(decodedRoot)'")
                  } else {
                     logError("Can't get attributes for directory: '\(file.lastPathComponent)'")
                     fileAttributes = Text_Content(text: "Couldn't get attributes for directory '\(file.lastPathComponent)' in directory '\(decodedRoot)'")
                  }
               } else {
                  if let fileSize = attributes[FileAttributeKey.size] as? Int64,
                     let fileType = attributes[FileAttributeKey.type] as? String,
                     let _ = attributes[FileAttributeKey.creationDate] as? Date,
                     let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
                     let _ = attributes[FileAttributeKey.posixPermissions] as? Int {
                     
                     fileAttributes = Text_Content(text: "File '\(file.lastPathComponent)' has size \(fileSize) is modified \(modifiedDate.timeIntervalSince1970) with type \(fileType) in directory '\(decodedRoot)'")
                  } else {
                     logError("Can't get attributes for file: '\(file.lastPathComponent)'")
                     fileAttributes = Text_Content(text: "Couldn't get attributes for file '\(file.lastPathComponent)' in directory '\(decodedRoot)'")
                  }
               }
               
               files.append(fileAttributes)
            } catch {
               logError(error)
               debug("Ignoring the prior error as it is on an individual file in a list of files.")
            }
         }
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: "\(error.localizedDescription)",serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: files,serverInfo: serverInfo)
   }
}

// File content changes
extension Tool_FileSystem {
   func writeFile(_ serverInfo: ServerInfo,_ responseId: String,at path: String,name: String,with content: String) -> MCPResponse {
      if ( path.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let fileURL = fileURL(path: path,name)
      
      if ( fileURL.isDirectory ) {
         let error = Tool_FileSystem_Error.path_is_directory(fileURL)
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

   func insertDataIntoFile(_ serverInfo: ServerInfo,_ responseId: String,inPath: String,name:String, atOffset offset: UInt64, newData: Data) -> MCPResponse {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let tempFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
      let fileURL = fileURL(path: inPath,name)

      if ( fileURL.isDirectory ) {
         let error = Tool_FileSystem_Error.path_is_directory(fileURL)
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
         try originalHandle.seek(toOffset: offset)
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
      return root.appendingPathComponent(name)
   }
   
   func appendToFile(_ serverInfo: ServerInfo,_ responseId: String,at path: String,name: String,with content: String) -> MCPResponse {
      if ( path.contains("%20") ) {
         logWarn("Invalid string!!!")
      }

      let fileURL = fileURL(path: path,name)
      
      if ( fileURL.isDirectory ) {
         let error = Tool_FileSystem_Error.path_is_directory(fileURL)
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

// Find
extension Tool_FileSystem {
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
}

extension Tool_FileSystem: MCPTool {
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

      let possibleOperation = FileSystemTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileSystemTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations) and are all lower case."
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }

      guard let url = accessibleURL(urlProvider,inPath) else {
         let paths = urlProvider?.urls.map({ "\"\($0.path)\"" }).joined(separator: ",")
         let message = "\(inPath) is not accessible, path is not a child of the paths: \(paths)"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      debug("operation:\(operation) path:\(inPath)")
      
      _ = url.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo,responseId,arguments,operation,inPath)
      url.stopAccessingSecurityScopedResource()
      return result
   }
   
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileSystemTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let fileName = arguments["fileName"] as? String ?? ""
      if operation.requiresFileName {
         guard !fileName.isEmpty else {
            return MCPResponse.toolError(id: responseId, message: "Filename not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
         }
      }
      
      switch operation {
      case .listDirectory:
         return listDirectory(serverInfo,responseId,at: whichPath)
      case .createDirectory:
         return createDir(serverInfo,responseId,at: whichPath)
      case .findFile:
         return find(serverInfo, responseId, in: whichPath, named: fileName,directory: false)
      case .findDir:
         return find(serverInfo, responseId, in: whichPath, named: fileName,directory: true)
      case .readContent:
         return readFile(serverInfo,responseId,at: whichPath,name: fileName)
      case .readContentRange:
         guard let offsetString: String = arguments["offset"] as? String,
               let whichOffset: UInt64 = UInt64(offsetString) else {
            logWarn("offset:'\(arguments["offset"])'")
            return MCPResponse.toolError(id: responseId, message: "offset argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }
         guard let lengthString: String = arguments["length"] as? String,
               let whichLength: UInt64 = UInt64(lengthString) else {
            logWarn("length:'\(arguments["length"])'")
            return MCPResponse.toolError(id: responseId, message: "length argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }

         return readFile(serverInfo,responseId,at: whichPath,name: fileName,offset: whichOffset,length: whichLength)
      case .writeContent:
         let whichContent: String = arguments["content"] as? String ?? ""
         guard !whichContent.isEmpty else {
            logWarn("content:'\(arguments["content"])'")
            return MCPResponse.toolError(id: responseId, message: "content not provided for operation:'\(operation.rawValue)'",serverInfo: serverInfo)
         }

         return writeFile(serverInfo,responseId,at: whichPath,name: fileName,with: whichContent)
      case .insertContent:
         guard let offsetString: String = arguments["offset"] as? String,
               let whichOffset: UInt64 = UInt64(offsetString) else {
            logWarn("offset:'\(arguments["offset"])'")
            return MCPResponse.toolError(id: responseId, message: "offset argument not provided or unable to convert to an integer value",serverInfo: serverInfo)
         }

         guard let contentString: String = arguments["content"] as? String,
               let data = contentString.data(using: .utf8) else {
            logWarn("content:'\(arguments["content"])'")
            return MCPResponse.toolError(id: responseId, message: "content not provided or unable to convert the provided content into UTF8 Data",serverInfo: serverInfo)
         }
         
         return insertDataIntoFile(serverInfo,responseId,inPath: whichPath,name: fileName,atOffset: whichOffset,newData: data)
      case .appendContent:
         let whichContent: String = arguments["content"] as? String ?? ""
         guard !whichContent.isEmpty else {
            logWarn("content:'\(arguments["content"])'")
            return MCPResponse.toolError(id: responseId, message: "content not provided for operation:'\(operation.rawValue)'",serverInfo: serverInfo)
         }

         return appendToFile(serverInfo,responseId,at: whichPath,name: fileName,with: whichContent)
      }
   }
}
