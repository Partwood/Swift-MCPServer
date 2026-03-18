//
//  Git.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor
import Foundation
import SwiftGitX

/*
 Example prompt:
 
 Using the tool mcp_SwagenticMCP_git can you tell me the status in /Users/jvsherwood/Desktop/projects/Packages/Swift-MCPServer/
 Do not use mcp_SwagenticMCP_filesystem
 */
struct GitTool: Content {
   let name: String
   static let description = "A tool for interacting with Git repositories."
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         // Future... clone, rebase, commit, push
         case status
      }
      
      let operation: Operation
      let repositoryURL: String? // Clone
      let destinationPath: String? // Clone
      
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_git"
   }
}

public
class Tool_Git {
   let internalDescriptor: Tool
   let tool: GitTool
   let urlProvider: URLProvider?

   init(serverName: String,urlProvider: URLProvider?) {
      self.tool = GitTool(serverName: serverName)
      self.urlProvider = urlProvider
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: GitTool.description,
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "operation": [
                  "type": "string",
                  "enum": AnyCodable(GitTool.Input.Operation.allCases.map({$0.rawValue})),
                  "description": "One of the following values:"+GitTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
               "path": [
                  "type": "string",
                  "description": "The location on disk, using the appropriate format for mac, windows or linux"
               ],
               "if": [
                  "properties": [ "operation": [ "const": "status" ] ]
               ],
               "then": [
                  "required": ["path"]
               ],
            ],
            "required": ["operation"]
         ])
      )
   }

   func status(configuration: Configuration,pathURL: URL) -> MCPResponse {
      do {
         var statuses = Array<Text_Content>()
         
         let repo = try Repository(at: pathURL, createIfNotExists: false)
         let statusEntries = try repo.status()
         
         if ( statusEntries.isEmpty ) {
            debug("No status entries url:\(pathURL.path())")
            return MCPResponse.toolSuccess(configuration, text: "Status successful, no output")
         }
         
         statusEntries.forEach({ entry in
            let path: String
            
            if let index = entry.index {
               path = index.newFile.path
            } else if let workingTree = entry.workingTree {
               path = workingTree.newFile.path
            } else {
               path = "unknown"
            }
            
            var statusString: String = ""
            var prefix: String = ""
            
            let status: Array<StatusEntry.Status> = entry.status
            status.forEach({ s in
               statusString += prefix+"\(s)"
               prefix = ","
            })
            
            statuses.append(Text_Content(text: "path:\(path) status:\(statusString)"))
         })
         
         debug("url:\(pathURL.path()) statuses:\n\(statuses)")
         
         return MCPResponse.toolSuccess(configuration, content: statuses)
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error with status: \(error.localizedDescription)")
      }
   }
}

extension Tool_Git: MCPTool {
   public var name: String {
      get { return tool.name }
   }
   
   public var descriptor: Tool {
      get { return self.internalDescriptor }
   }
   
   public var attributes: [MCPToolAttribute] {
      return []
   }
   
   public func attributeValue(attribute: MCPToolAttribute, value: String) {
      // Do nothing
   }
   
   public func handleOperation(_ serverInfo: ServerInfo, _ req: MCPRequest, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      let argOperation: String = arguments["operation"] as? String ?? ""
      let possibleOperation = GitTool.Input.Operation(rawValue: argOperation)

      guard let operation = possibleOperation else {
         let operations = GitTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(argOperation)' valid operations are \(operations)"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
      let configuration = Configuration(response_id: responseId, serverInfo: serverInfo)
      
      switch(operation) {
      case .status:
         let argPath: String = arguments["path"] as? String ?? ""
         let url = URL(fileURLWithPath: argPath)
         _ = url.startAccessingSecurityScopedResource()
         let statuses = self.status(configuration: configuration,pathURL: url)
         url.stopAccessingSecurityScopedResource()
         return statuses
      }
   }
   
}
