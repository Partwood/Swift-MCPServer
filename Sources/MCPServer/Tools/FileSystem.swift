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
   
   // Helper method to load the description from FileSystem.md
   static func loadDescription() -> String {
      let resourceName: String = "FileSystem"
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
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
//         case deleteFile
//         case moveFile
//         case copyFile
         var requiresName: Bool {
            get {
               switch(self){
               case .findFile,.findDir:
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
   case invalid_pattern(_ pattern: String)

   public var errorDescription: String? {
      return description
   }
}

extension Tool_FileSystem_Error: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .path_is_directory(let url):
         return NSLocalizedString("Operation error: '\(url)' is a directory", comment: "Unexpected directory")
      case .path_is_file(let url):
         return NSLocalizedString("Operation error: '\(url)' is a file", comment: "Unexpected file")
      case .invalid_pattern(let pattern):
         return NSLocalizedString("Operation error: Invalid wildcard pattern '\(pattern)'", comment: "Invalid pattern")
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
         description: FileSystemTool.loadDescription(),
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
               "name": [
                  "type": "string",
                  "description": "The file or directory name to find within the path provided"
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
   private func getAttributes(fileManager: FileManager,decodedRoot: String,file: URL) throws -> Text_Content {
      let decodedPath: String = (file.path() as NSString).removingPercentEncoding ?? file.path()
      
      let attributes = try fileManager.attributesOfItem(atPath: decodedPath)
      
      let fileAttributes: Text_Content
      
      let isDirectory = (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
      if ( isDirectory ) {
         if let fileType = attributes[FileAttributeKey.type] as? String,
            let _ = attributes[FileAttributeKey.creationDate] as? Date,
            let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
            let _ = attributes[FileAttributeKey.posixPermissions] as? Int {
            
            fileAttributes = Text_Content(text: "Directory '\(file.lastPathComponent)' is modified \(modifiedDate.timeIntervalSince1970) with type \(fileType) in directory '\(decodedRoot)'")
         } else {
            let attributeError = FileIOError.attributes_not_found(file)
            logError(attributeError)
            throw attributeError
         }
      } else {
         if let fileSize = attributes[FileAttributeKey.size] as? Int64,
            let fileType = attributes[FileAttributeKey.type] as? String,
            let _ = attributes[FileAttributeKey.creationDate] as? Date,
            let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
            let _ = attributes[FileAttributeKey.posixPermissions] as? Int {
            
            fileAttributes = Text_Content(text: "File '\(file.lastPathComponent)' has size \(fileSize) is modified \(modifiedDate.timeIntervalSince1970) with type \(fileType) in directory '\(decodedRoot)'")
         } else {
            let attributeError = FileIOError.attributes_not_found(file)
            logError(attributeError)
            throw attributeError
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
               let fileAttributes = try getAttributes(fileManager: fileManager, decodedRoot: decodedRoot, file: pathURL)
               
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
         
         let _ = directoryContents.map { file in
            if ( file.lastPathComponent.hasPrefix(".") ) {
               // Ignore any file that starts with .
               return
            }
            
            do {
               let fileAttributes = try getAttributes(fileManager: fileManager, decodedRoot: decodedRoot, file: file)
               
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
         
         let invalidPatternError = Tool_FileSystem_Error.invalid_pattern(pattern)
         
         logError(invalidPatternError)
         throw invalidPatternError
      }
   }
   
   func find(_ serverInfo: ServerInfo,_ responseId: String,in rootPath: String,named pattern: String,directory: Bool) -> MCPResponse {
      let expandedRootPath = NSString(string: rootPath).expandingTildeInPath
      let fileManager = FileManager.default
      var foundFiles = [Text_Content]()
      
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
                  foundFiles.append(Text_Content(text: "Found match to '" + pattern + "' at path: " + item.path))
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
         return MCPResponse.toolSuccess(id: responseId, content: foundFiles, serverInfo: serverInfo)
      }
   }

   private func find(in directoryPath: String, named pattern: String,directory: Bool) throws -> [Text_Content] {
      let fileManager = FileManager.default
      var foundItems = [Text_Content]()
      
      do {
         let directoryURL = URL(fileURLWithPath: directoryPath)
         let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if ( directory == isDirectory ) {
               let matches: Bool = try matchesWildcard(item.lastPathComponent,pattern: pattern)
               if ( matches ) {
                  foundItems.append(Text_Content(text: "Found match to '" + pattern + "' at path: " + item.path))
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
