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
   static let description = "Provides file system operations for creating directories, listing directory contents, and recursively finding a file or directory under a path."
   
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

// MARK: Find file or directory
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

// MARK: Operation processing
extension Tool_FileSystem {
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileSystemTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      let name = arguments["name"] as? String ?? ""
      if operation.requiresName {
         guard !name.isEmpty else {
            return MCPResponse.toolError(id: responseId, message: "name not provided for operation:'\(operation.rawValue)'", serverInfo: serverInfo)
         }
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
   
   func handleOperation(_ serverInfo: ServerInfo,_ urlProvider: URLProvider?/*,_ req: MCPRequest*/, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      //debug("req:\(req.method)")
      
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
