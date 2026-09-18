//
//  WebDownload.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

import Vapor

enum WebDownloadToolError: Error {
   case resource_not_found
}

struct WebDownloadTool: Content {
   let name: String
   
   // Helper method to load the description from FileSystem.md
   static func loadDescription() -> String {
      let resourceName: String = "WebDownload"
      
      do {
         if let filePath = Bundle.module.url(forResource: resourceName, withExtension: "md") {
            // Read your file data here
            let textContent = try String(contentsOf: filePath, encoding: .utf8)
            return textContent
         } else {
            throw WebDownloadToolError.resource_not_found
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

enum Tool_WebDownload_Error: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)
   case invalid_pattern(_ pattern: String)
}

extension Tool_WebDownload_Error: CustomStringConvertible {
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
class Tool_WebDownload {
   let internalDescriptor: Tool
   let tool: WebDownloadTool
   
   init(serverName: String) {
      self.tool = WebDownloadTool(serverName: serverName)
      
      self.internalDescriptor =
      Tool(
         name: tool.name,
         description: WebDownloadTool.loadDescription(),
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "description": "One of the following values:"+WebDownloadTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
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

// MARK: - Operations
extension Tool_WebDownload {

    /// Download an image from a given URL and save it to a specified path.
    /// - Parameters:
    ///   - url: The URL of the image.
    ///   - path: The path where the image should be saved.
    /// - Returns: The path where the image was saved.
    func downloadImage(from url: URL, to path: String) -> String {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let fileURL = documentsDirectory.appendingPathComponent(path)

        // Extract file extension from the URL or use a default
        let fileExtension = url.pathExtension.isEmpty ? "jpg" : url.pathExtension
        let fileName = "image_\(UUID().uuidString).\(fileExtension)"
        let finalFileURL = documentsDirectory.appendingPathComponent(fileName)

        URLSession.shared.downloadTask(with: url) { tempURL, response, error in
            if let error = error {
                print("Error downloading image: \(error.localizedDescription)")
                return
            }

            do {
                if let data = try? Data(contentsOf: tempURL!) {
                    try data.write(to: finalFileURL)
                    print("Image saved at: \(finalFileURL.path)")
                }
            } catch {
                print("Error saving image: \(error.localizedDescription)")
            }
        }.resume()

        return finalFileURL.path
    }
}

// MARK: - MCPTool
//extension Tool_WebDownload: MCPTool {
//   public var name: String { get { return self.tool.name } }
//   public var descriptor: Tool { get { return self.internalDescriptor } }
//
//   public var attributes: [MCPToolAttribute] {
//      return []
//   }
//
//   func attributeValue(attribute: MCPToolAttribute, value: String) {
//      <#code#>
//   }
//   
//   func handleOperation(_ serverInfo: ServerInfo, _ urlProvider: (any URLProvider)?, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
//      <#code#>
//   }
//}
