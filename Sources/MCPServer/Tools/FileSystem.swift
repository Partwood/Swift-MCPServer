//
//  FileIO.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

// https://portkey.ai/blog/mcp-message-types-complete-json-rpc-reference-guide/

import Vapor

struct FileSystemTool: Content {
   static let resourceName: String = "FileSystem"
   let name: String
   
   // Helper method to load the description from <resourceName>.md
   static func loadDescription() -> String {
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
            assertionFailure(FileAppendToolError.resource_not_found.localizedDescription)
            throw FileAppendToolError.resource_not_found
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
         case listDirectory = "list"
         case createDirectory = "create_directory"
         case findFile = "recursive_find_file"
         case findDir = "recursive_find_dir"
         case info = "info"
//         case deleteFile
//         case moveFile
//         case copyFile
         var requiresName: Bool {
            get {
               switch(self){
               case .findFile,.findDir,.info:
                  return true
               default:
                  return false
               }
            }
         }
      }
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_"+FileSystemTool.resourceName.lowercased()
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
         description: FileSystemTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+FileSystemTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
                  "enum": FileSystemTool.Input.Operation.allCases.map({$0.rawValue})
               ],
               "path": [
                  "type": "string",
                  "description": "The absolute directory path to the target file folder (e.g. '/Users/project/src'). Exclude the file name."
               ],
               "name": [
                  "type": "string",
                  "description": "The exact file name including its extension (e.g. 'main.swift' or 'config.json')."
               ],
            ],
            "required": ["operation", "path"]
         ])
      )
   }
}

// MARK: Create directory
extension Tool_FileSystem {
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
}

// MARK: List directory contents
extension Tool_FileSystem {
   enum FileContentType: String {
      case binary
      case text
      case jpeg
      case png
      case mp3
      case mp4
      case avi
      case wav
      case markdown
      case html
      case unknown
   }
   
   func identifyFileType(at url: URL) -> FileContentType {
      do {
         // Read the first 1024 bytes of the file to check for binary patterns or magic numbers
         let fileHandle = try FileHandle(forReadingFrom: url)
         defer { fileHandle.closeFile() }
         
         let data = fileHandle.readData(ofLength: min(1024, Int(fileHandle.seekToEndOfFile())))
         let byteArray = [UInt8](data)
         
         // Check for null bytes (indicative of binary files)
         if byteArray.contains(0x00) {
            return .binary
         }
         
         // Check for JPEG magic number: 0xFFD8FF
         if byteArray.count >= 3 && byteArray[0] == 0xFF && byteArray[1] == 0xD8 && byteArray[2] == 0xFF {
            return .jpeg
         }
         
         // Check for PNG magic number: 0x89504E47
         if byteArray.count >= 8 && byteArray[0] == 0x89 && byteArray[1] == 0x50 && byteArray[2] == 0x4E && byteArray[3] == 0x47 {
            return .png
         }
         
         // Check for MP3 ID3 tag
         if byteArray.count >= 3 && byteArray[0] == 0x49 && byteArray[1] == 0x44 && byteArray[2] == 0x33 {
            return .mp3
         }
         
         // Check for WAV file: RIFF header followed by "WAVE"
         if byteArray.count >= 12 && byteArray[0] == 0x52 && byteArray[1] == 0x49 && byteArray[2] == 0x46 && byteArray[3] == 0x46
               && byteArray[8] == 0x57 && byteArray[9] == 0x41 && byteArray[10] == 0x56 && byteArray[11] == 0x45 {
            return .wav
         }
         
         // Check for MP4 file: ftyp followed by mp41 or similar
         if byteArray.count >= 8 && byteArray[4] == 0x66 && byteArray[5] == 0x74 && byteArray[6] == 0x79 && byteArray[7] == 0x70 {
            return .mp4
         }
         
         // Check for AVI file: RIFF header followed by "AVI "
         if byteArray.count >= 8 && byteArray[0] == 0x52 && byteArray[1] == 0x49 && byteArray[2] == 0x46 && byteArray[3] == 0x46
               && byteArray[8] == 0x41 && byteArray[9] == 0x56 && byteArray[10] == 0x49 && byteArray[11] == 0x20 {
            return .avi
         }
         
         // Attempt to decode as UTF-8 text
         if let string = String(data: data, encoding: .utf8) {
            // Check for Markdown patterns (e.g., starts with # or ---)
            if string.hasPrefix("#") || string.hasPrefix("---") {
               return .markdown
            }
            // Check for HTML content
            if string.lowercased().hasPrefix("<html") || string.lowercased().hasPrefix("<!doctype html") {
               return .html
            }
            return .text
         }
      } catch {
         logError("Error reading file: \(error)")
      }
      
      return .unknown
   }
   
   private func getFileType(_ type: FileAttributeType) -> String {
      switch type {
      case .typeRegular:
         return "file"
      case .typeDirectory:
         return "directory"
      case .typeSymbolicLink:
         return "symbolic_link"
      default:
         return "\(type.rawValue)"
      }
   }

   private func getAttributes(fileManager: FileManager,decodedRoot: String,file: URL,simple: Bool) throws -> Text_Content {
      let decodedPath: String = (file.path() as NSString).removingPercentEncoding ?? file.path()
      
      let attributes = try fileManager.attributesOfItem(atPath: decodedPath)
      
      let fileAttributes: Text_Content
      
      guard let fileType = attributes[FileAttributeKey.type] as? FileAttributeType else {
         let attributeError = FileIOError.attributes_not_found(file,nil)
         logError(attributeError)
         throw attributeError
      }
      
      let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
      if ( isDirectory ) {
         var typeInfo: String = ""
         if ( fileType != .typeDirectory ) {
            typeInfo = " with type \(getFileType(fileType)) "
         }
         
         if simple {
            fileAttributes = Text_Content(text: "Directory '\(file.lastPathComponent)'\(typeInfo).")
         } else {
            if let _ = attributes[FileAttributeKey.creationDate] as? Date,
               let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
               let _ = attributes[FileAttributeKey.posixPermissions] as? Int {
               
               fileAttributes = Text_Content(text: "Directory '\(file.lastPathComponent)'\(typeInfo) is modified \(modifiedDate.timeIntervalSince1970).")
            } else {
               let attributeError = FileIOError.attributes_not_found(file)
               logError(attributeError)
               throw attributeError
            }
         }
      } else {
         var typeInfo: String = ""
         if ( fileType != .typeRegular ) {
            typeInfo = " with type \(getFileType(fileType)) "
         }
         
         if simple {
            fileAttributes = Text_Content(text: "File '\(file.lastPathComponent)'\(typeInfo).")
         } else {
            if let fileSize = attributes[FileAttributeKey.size] as? Int64,
               let _ = attributes[FileAttributeKey.creationDate] as? Date,
               let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
               let _ = attributes[FileAttributeKey.posixPermissions] as? Int {
               
               let contentType = identifyFileType(at: file)
               
               fileAttributes = Text_Content(text: "File '\(file.lastPathComponent)'\(typeInfo) has size \(fileSize) is modified \(modifiedDate.timeIntervalSince1970) withd content type \(contentType).")
            } else {
               let attributeError = FileIOError.attributes_not_found(file)
               logError(attributeError)
               throw attributeError
            }
         }
      }
      
      return fileAttributes
   }
   
   func listDirectory(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String) -> MCPResponse {
      let fileManager = FileManager.default
      
      let path = NSString(string: inPath).expandingTildeInPath
      let decodedRoot: String = path.removingPercentEncoding ?? path
      let pathURL = URL(fileURLWithPath: decodedRoot)

      var files = Array<Text_Content>()
      
      let directoryURL: URL
      
      if ( pathURL.isExisting() ) {
         do {
            if ( try pathURL.isExistingFile() ) {
               let fileAttributes = try getAttributes(fileManager: fileManager, decodedRoot: decodedRoot, file: pathURL,simple: true)
               
               files.append(fileAttributes)
               
               return MCPResponse.toolSuccess(id: responseId, content: files,serverInfo: serverInfo)
            }
         } catch {
            logError(error)
            return MCPResponse.toolError(id: responseId, message: "\(error.localizedDescription)",serverInfo: serverInfo)
         }
         
         // If we get here then it exists, but it is not a file (implies it is a directory)
         directoryURL = pathURL
      } else {
         let missing = FileIOError.directory_not_found(pathURL)
         logError(missing)
         return MCPResponse.toolError(id: responseId, message: "\(missing.localizedDescription)",serverInfo: serverInfo)
      }

      do {
         // Get contents (files and subfolders)
         let directoryContents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
         let contents: [String] = directoryContents.compactMap { file in
            if ( file.lastPathComponent.hasPrefix(".") ) {
               // Ignore any file that starts with .
               return nil
            }
            
            do {
               let fileAttributes = try getAttributes(fileManager: fileManager, decodedRoot: decodedRoot, file: file, simple: true)
               
               return "- \(fileAttributes.text.value)"
            } catch {
               logError(error)
               debug("Ignoring the prior error as it is on an individual file in a list of files.")
               return nil
            }
         }
         
         files.append(Text_Content(text: contents.joined(separator: "\n")))
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: "\(error.localizedDescription)",serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: files,serverInfo: serverInfo)
   }
   
   func info(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String) -> MCPResponse {
      let fileManager = FileManager.default
      
      let path = NSString(string: inPath).expandingTildeInPath
      let decodedRoot: String = path.removingPercentEncoding ?? path
      let pathURL = URL(fileURLWithPath: decodedRoot).appendingPathComponent(name)
      
      var files = Array<Text_Content>()
      
      if ( !pathURL.isExisting() ) {
         let missing = FileIOError.directory_not_found(pathURL)
         logError(missing)
         return MCPResponse.toolError(id: responseId, message: "\(missing.localizedDescription)",serverInfo: serverInfo)
      }
      
      do {
         let fileAttributes = try getAttributes(fileManager: fileManager, decodedRoot: decodedRoot, file: pathURL,simple: false)
         
         files.append(fileAttributes)
      } catch {
         logError(error)
         return MCPResponse.toolError(id: responseId, message: "\(error.localizedDescription)",serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: files,serverInfo: serverInfo)
   }
}

// MARK: Find file or directory
extension Tool_FileSystem {
   private func matchesWildcard(_ filename: String, pattern: String) throws -> Bool {
      // Convert wildcard pattern to a regular expression
      let regexPattern = pattern
         .replacingOccurrences(of: ".", with: "\\.")
         .replacingOccurrences(of: "*", with: ".*")
      
      do {
         let regex = try NSRegularExpression(pattern: regexPattern)
         let range = NSRange(location: 0, length: filename.utf16.count)
         return regex.firstMatch(in: filename, options: [], range: range) != nil
      } catch {
         logError(error)
         
         let invalidPatternError = RegExError.invalid_pattern(pattern)
         
         logError(invalidPatternError)
         throw invalidPatternError
      }
   }
   
   func find(_ serverInfo: ServerInfo,_ responseId: String,in rootPath: String,named pattern: String,directory: Bool) -> MCPResponse {
      let expandedRootPath = NSString(string: rootPath).expandingTildeInPath
      let fileManager = FileManager.default
      var foundFiles = Array<String>()
      
      do {
         // Get the contents of the root directory
         let rootURL = URL(fileURLWithPath: expandedRootPath)
         let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if ( directory == isDirectory ) {
               let matches: Bool = try matchesWildcard(item.lastPathComponent,pattern: pattern)
               if ( matches ) {
                  // Found the file/directory directly in the root
                  foundFiles.append("Found match to '" + pattern + "' at path: " + item.path)
               }
            }
            
            if isDirectory {
               // Recursively search in subdirectories
               let foundInSubdirs = try find(in: item.path, named: pattern,directory: directory)
               for foundItem in foundInSubdirs {
                  foundFiles.append(foundItem)
               }
            }
         }
      } catch {
         let message = "Error searching for pattern:'\(pattern)', error:'\(error.localizedDescription)'"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
      }
      
      if foundFiles.isEmpty {
         return MCPResponse.toolSuccess(id: responseId, text: "No file or directory matching '" + pattern + "' found in '" + rootPath + "'", serverInfo: serverInfo)
      } else {
         return MCPResponse.toolSuccess(id: responseId, content: [Text_Content(text: foundFiles.joined(separator: "\n"))], serverInfo: serverInfo)
      }
   }

   private func find(in directoryPath: String, named pattern: String,directory: Bool) throws -> Array<String> {
      let fileManager = FileManager.default
      var foundItems = Array<String>()
      
      do {
         let directoryURL = URL(fileURLWithPath: directoryPath)
         let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if ( directory == isDirectory ) {
               let matches: Bool = try matchesWildcard(item.lastPathComponent,pattern: pattern)
               if ( matches ) {
                  foundItems.append("Found match to '" + pattern + "' at path: " + item.path)
               }
            }

            if isDirectory {
               // Recursively search in subdirectories
               let foundInSubdirs = try find(in: item.path, named: pattern,directory: directory)
               for foundItem in foundInSubdirs {
                  foundItems.append(foundItem)
               }
            }
         }
      } catch {
         logError(error)
         throw error
      }
      
      return foundItems
   }
}

// MARK: Operation processing
extension Tool_FileSystem {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ toolArguments: ToolArguments,_ operation: FileSystemTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let name: String

      if ( operation.requiresName ) {
         do {
            name = try toolArguments.asString("name", allowEmpty: false)
         } catch {
            return MCPResponse.toolError(id: responseId, message: error.localizedDescription, serverInfo: serverInfo)
         }
      } else {
         name = ""
      }
      
      switch operation {
      case .listDirectory:
         return listDirectory(serverInfo,responseId,at: whichPath)
      case .info:
         return info(serverInfo,responseId,at: whichPath, name: name)
      case .createDirectory:
         return createDir(serverInfo,responseId,at: whichPath)
      case .findFile:
         return find(serverInfo, responseId, in: whichPath, named: name,directory: false)
      case .findDir:
         return find(serverInfo, responseId, in: whichPath, named: name,directory: true)
      }
   }
}

// MARK: MCPTool
extension Tool_FileSystem: MCPTool {
   var name: String { get { return self.tool.name } }
   var descriptor: Tool { get { return self.internalDescriptor } }
   
   var attributes: [MCPToolAttribute] {
      return []
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Does nothing
   }
   
   func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let toolArguments = ToolArguments(arguments: arguments)
      let operation = try toolArguments.enumFromString("operation", as: FileSystemTool.Input.Operation.self)
      let accessibleURL = try toolArguments.asAccessibleURL(urlProvider, "path")
      
      debug("operation:\(operation) path:\(accessibleURL.path)")
      
      _ = accessibleURL.rootURL.startAccessingSecurityScopedResource()
      let result = handleOperation(serverInfo, responseId, toolArguments, operation, accessibleURL.path)
      accessibleURL.rootURL.stopAccessingSecurityScopedResource()
      return result
   }
}
