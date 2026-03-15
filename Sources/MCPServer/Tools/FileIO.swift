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
   static let description = "Perform file system operations"
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case listDirectory = "list"
         case readFile = "read"
         case writeFile = "write"
         case createDirectory = "createdirectory"
//         case deleteFile
//         case moveFile
//         case copyFile
      }
      
      let operation: Operation
      let path: String
      let content: String? // For write operations
      let newPath: String? // For move/copy operations
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_filesystem"
   }
}

final
class Tool_FileSystem {
   let internalDescriptor: Tool
   let tool: FileSystemTool
   let urlProvider: URLProvider?
   
   init(serverName: String,urlProvider: URLProvider?) {
      self.tool = FileSystemTool(serverName: serverName)
      self.urlProvider = urlProvider
      
      if let provider = self.urlProvider {
         debug("Has urlProvider. url:\(provider.url)")
      } else {
         debug("No urlProvider")
      }
      
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
                  "description": "The content of a file"
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
   
   func createDir(_ serverInfo: ServerInfo,_ responseId: String,at path: String) -> MCPResponse {
      // Convert the tilde path (~/) to an absolute path
      let expandedPath = NSString(string: path).expandingTildeInPath
      
      do {
         // Create the directory if it doesn't exist
         let directoryURL = URL(fileURLWithPath: expandedPath)
         try FileManager.default.createDirectory(at: directoryURL,
                                                 withIntermediateDirectories: true)
         
         debug("Successfully created \(directoryURL.path)")
      } catch {
         let message = "Error creating directory, \(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, text: "Successfully created directory \(path)",serverInfo: serverInfo)
   }
   
   func writeFile(_ serverInfo: ServerInfo,_ responseId: String,at path: String,with content: String) -> MCPResponse {
      // Convert the tilde path (~/) to an absolute path
      let expandedPath = NSString(string: path).expandingTildeInPath
      
      do {
         // Create the directory if it doesn't exist
         let directoryURL = URL(fileURLWithPath: (expandedPath as NSString).deletingLastPathComponent)
         try FileManager.default.createDirectory(at: directoryURL,
                                                 withIntermediateDirectories: true)
         
         // Write the content to file
         try content.write(toFile: expandedPath, atomically: true, encoding: .utf8)
      } catch {
         let message = "Error writing to file, \(error.localizedDescription)"
         logError(message)
         return MCPResponse.toolError(id: responseId,message: message,serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, text: "Successfully wrote the content to \(path)",serverInfo: serverInfo)
   }
   
   private func readFileToString(atPath path: String) -> String? {
      do {
         // Read file contents as Data
         let fileData = try Data(contentsOf: URL(fileURLWithPath: path))
         
         // Convert to String using UTF-8 encoding
         return String(data: fileData, encoding: .utf8)
      } catch {
         logError("Error reading file: \(error.localizedDescription)")
         return nil
      }
   }
   
   func readFile(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String) -> MCPResponse {
      var files = Array<Text_Content>()
      
      let fileContent: Text_Content
      
      if let content = readFileToString(atPath: inPath) {
         fileContent = Text_Content(text: content)
         files.append(fileContent)
      } else {
         //fileContent = Text_Content(text: "")
         return MCPResponse.toolError(id: responseId, message: "File not found or has no content, file \(inPath)", serverInfo: serverInfo)
      }
      
      return MCPResponse.toolSuccess(id: responseId, content: files,serverInfo: serverInfo)
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
         
         let _ = try directoryContents.map { file in
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
                     let creationDate = attributes[FileAttributeKey.creationDate] as? Date,
                     let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
                     let permissions = attributes[FileAttributeKey.posixPermissions] as? Int {
                     
                     fileAttributes = Text_Content(text: "Directory '\(file.lastPathComponent)' is modified \(modifiedDate.timeIntervalSince1970) with type \(fileType) in directory '\(decodedRoot)'")
                  } else {
                     logError("Can't get attributes for directory: '\(file.lastPathComponent)'")
                     fileAttributes = Text_Content(text: "Couldn't get attributes for directory '\(file.lastPathComponent)' in directory '\(decodedRoot)'")
                  }
               } else {
                  if let fileSize = attributes[FileAttributeKey.size] as? Int64,
                     let fileType = attributes[FileAttributeKey.type] as? String,
                     let creationDate = attributes[FileAttributeKey.creationDate] as? Date,
                     let modifiedDate = attributes[FileAttributeKey.modificationDate] as? Date,
                     let permissions = attributes[FileAttributeKey.posixPermissions] as? Int {
                     
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

   func accessibleURL(_ path: String) -> Bool {
      guard let urlProvider = self.urlProvider else {
         debug("No urlProvider")
         return false
      }
      guard let url = urlProvider.url else {
         debug("No urlProvider.url")
         return false
      }

      debug("url:\(url.path())\npath:\(path)")
      
      let expandedPath = NSString(string: path).expandingTildeInPath
      let desiredURL = URL(fileURLWithPath: expandedPath)
      return desiredURL.isContained(in: url)
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

   func handleOperation(_ serverInfo: ServerInfo,_ req: MCPRequest, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      debug("req:\(req)")
      //debug("req:\n\(req)\narguments:\n\(arguments)")
      
      let inOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      let inPath: String = arguments["path"] as? String ?? "."

      let possibleOperation = FileSystemTool.Input.Operation(rawValue: inOperation)
      
      guard let operation = possibleOperation else {
         let operations = FileSystemTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(inOperation)' valid operations are \(operations)"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }

      guard let url = urlProvider?.url else {
         let message = "Cannot get url"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      guard accessibleURL(inPath)  else {
         let message = "\(inPath) is not accessible, path is not a child of \(urlProvider?.url?.path() ?? "")"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      do {
         debug("operation:\(operation) path:\(inPath)")
         
         _ = url.startAccessingSecurityScopedResource()
         let result = try handleOperation(serverInfo,responseId,arguments,operation,inPath)
         url.stopAccessingSecurityScopedResource()
         return result
      } catch {
         url.stopAccessingSecurityScopedResource()
         logError(error)
         throw error
      }
   }
   
   private func handleOperation(_ serverInfo: ServerInfo, _ responseId: String, _ arguments: [String : Any],_ operation: FileSystemTool.Input.Operation,_ whichPath: String) -> MCPResponse {
      switch operation {
      case .listDirectory:
         return listDirectory(serverInfo,responseId,at: whichPath)
         break
      case .writeFile:
         let whichContent: String = arguments["content"] as? String ?? ""
         return writeFile(serverInfo,responseId,at: whichPath,with: whichContent)
         break
      case .createDirectory:
         let whichContent: String = arguments["content"] as? String ?? ""
         return createDir(serverInfo,responseId,at: whichPath)
         break
//      default:
//         let operations = FileSystemTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
//         let message = "Unknown operation '\(whichOperation)' valid operations are \(operations)"
//         logError(message)
//         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
//         break
      case .readFile:
         return readFile(serverInfo,responseId,at: whichPath)
         break
      }
   }
}
