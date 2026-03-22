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
         // Future... rebase
         case g_clone = "clone"
         case g_init = "init"
         case g_status = "status"
         case g_add = "add"
         case g_commit = "commit"
         case g_push = "push"
         case g_branch = "branch"
         case g_switch = "switch"
      }
      
      let operation: Operation
//      let repositoryURL: String? // Clone
//      let destinationPath: String? // Clone
//      let path: String? // Status
//      let message: String? // Commit
//      let files: [String]? // Commit / Add
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
      
      self.internalDescriptor =
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
                  "description": "The root location of the git repository, using the appropriate format for mac, windows or linux"
               ],
               "source": [
                  "type": "string",
                  "description": "The source url of a git repository that is to be cloned"
               ],
               "branch": [
                  "type": "string",
                  "description": "The name of a git repository branch that is to be created or used in switch"
               ],
               "message": [
                  "type": "string",
                  "description": "The message used with the commit operation"
               ],
               "files": [
                  "type": "array",
                  "items": [
                     "type": "string"
                  ],
                  "description": "List of files used with the add and commit operation. The files are paths relative to the value in the path for the repository, for example 'source/main.cpp'"
               ],
            ],
            "required": ["operation"]
         ])
      )
   }
}

final
class GitOperations {
   func g_init(configuration: Configuration,pathURL: URL) -> MCPResponse {
      do {
         let repo = try Repository(at: pathURL, createIfNotExists: true)
         debug("path:\(repo.path.path())")
         
         return MCPResponse.toolSuccess(configuration, text: "Repository initialized in path '\(repo.path.path())'")
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error: \(error.localizedDescription)")
      }
   }

   func g_clone(configuration: Configuration,pathURL: URL,sourceURL: URL) -> MCPResponse {
      Task {
         do {
            _ = try await Repository.clone(from: sourceURL, to: pathURL)
         } catch {
            logError(error)
         }
      }
      
      return MCPResponse.toolSuccess(configuration, text: "Repository clone started")
   }

   func g_branch(configuration: Configuration,pathURL: URL,branchName: String) -> MCPResponse {
      do {
         let repo = try Repository(at: pathURL, createIfNotExists: false)
         
         do {
            _ = try repo.branch.get(named: branchName)
            
            let message = "Branch '\(branchName)' exists already"
            logError(message)
            return MCPResponse.toolError(configuration, message: message)
         } catch {
            if ( error.message.lowercased() == "invalid branch" ) {
               // Okay, doesn't exist, go ahead and create it.
            } else {
               logError(error)
               return MCPResponse.toolError(configuration, message: "Error: \(error.localizedDescription)")
            }
         }
         
         let main = try repo.branch.get(named: "main")
         let branch = try repo.branch.create(named: branchName, from: main)
         try repo.switch(to: branch)
         return MCPResponse.toolSuccess(configuration, text: "Branch '\(branchName)' created")
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error: \(error.localizedDescription)")
      }
   }
   
   func g_switch(configuration: Configuration,pathURL: URL,branchName: String) -> MCPResponse {
      do {
         let repo = try Repository(at: pathURL, createIfNotExists: false)
         let branch = try repo.branch.get(named: branchName)
         try repo.switch(to: branch)
         return MCPResponse.toolSuccess(configuration, text: "Branch '\(branchName)' active")
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error: \(error.localizedDescription)")
      }
   }
   
   func g_status(configuration: Configuration,pathURL: URL) -> MCPResponse {
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
   
   /// Performs git stage and commit operation (add and commit)
   /// - Parameters:
   ///   - configuration: Basic configuration
   ///   - pathURL: The url that is the path to the repository
   ///   - message: The commit message
   ///   - files: An array of file paths, relative to the pathURL
   /// - Returns: An MCPResponse object describing results
   func g_commit(configuration: Configuration, pathURL: URL, message: String, files: [String]) -> MCPResponse {
      do {
         let repo = try Repository(at: pathURL, createIfNotExists: false)
         
         // Stage the files
         for file in files {
            let fileURL = pathURL.appendingPathComponent(file)
            do {
               try repo.add(file: fileURL)
            } catch {
               logError(error.message)
               return MCPResponse.toolError(configuration, message: "Error with staging before commit: \(error.message)")
            }
         }
                 
         // Commit the changes
         try repo.commit(message: message)
         
         return MCPResponse.toolSuccess(configuration, text: "Commit successful")
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error with commit: \(error.localizedDescription)")
      }
   }
   
   func g_add(configuration: Configuration, pathURL: URL, files: [String]) -> MCPResponse {
      do {
         let fileURLs: [URL] = files.map({ URL(fileURLWithPath: $0) })
         let repo = try Repository(at: pathURL, createIfNotExists: false)
         
         try repo.add(files: fileURLs)

         return MCPResponse.toolSuccess(configuration, text: "Add successful")
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error with commit: \(error.localizedDescription)")
      }
   }
   
   func g_push(configuration: Configuration, pathURL: URL) -> MCPResponse {
      let repo: Repository
      do {
         repo = try Repository(at: pathURL, createIfNotExists: false)
      } catch {
         logError(error)
         return MCPResponse.toolError(configuration, message: "Error with commit: \(error.localizedDescription)")
      }

      Task {
         do {
            try await repo.push()
         } catch {
            logError(error)
         }
      }

      return MCPResponse.toolSuccess(configuration, text: "Push successfully started")
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

      let argPath: String = arguments["path"] as? String ?? ""
      let url = URL(fileURLWithPath: argPath)
      guard !argPath.isEmpty else {
         let message = "The git repository url was not provided"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         
      }

      let configuration = Configuration(response_id: responseId, serverInfo: serverInfo)
      let gitOperations = GitOperations()
      
      switch(operation) {
      case .g_init:
         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_init(configuration: configuration,pathURL: url)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_clone:
         let source: String = arguments["source"] as? String ?? ""
         if source.isEmpty {
            let message = "The \(operation.rawValue) operation requires the source property"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }
         
         guard let sourceURL = URL(string: source) else {
            let message = "The \(operation.rawValue) operation requires the source property that is a URL"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }

         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_clone(configuration: configuration,pathURL: url, sourceURL: sourceURL)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_branch:
         let branchName: String = arguments["branch"] as? String ?? ""
         if branchName.isEmpty {
            let message = "The \(operation.rawValue) operation requires the branch property"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }
         
         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_branch(configuration: configuration, pathURL: url, branchName: branchName)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_switch:
         let branchName: String = arguments["branch"] as? String ?? ""
         if branchName.isEmpty {
            let message = "The \(operation.rawValue) operation requires the branch property"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }
         
         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_switch(configuration: configuration, pathURL: url, branchName: branchName)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_status:
         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_status(configuration: configuration,pathURL: url)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_add:
         let files: [String] = arguments["files"] as? [String] ?? []
         if files.isEmpty {
            let message = "The \(operation.rawValue) operation requires one or more values in the files property"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }

         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_add(configuration: configuration,pathURL: url,files: files)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_commit:
         let message: String = arguments["message"] as? String ?? ""
         if message.isEmpty {
            let message = "The \(operation.rawValue) operation requires a message"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }

         let files: [String] = arguments["files"] as? [String] ?? []
         if files.isEmpty {
            let message = "The \(operation.rawValue) operation requires one or more values in the files property"
            logError(message)
            return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
         }
                  
         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_commit(configuration: configuration, pathURL: url, message: message, files: files)
         url.stopAccessingSecurityScopedResource()
         return response
      case .g_push:
         _ = url.startAccessingSecurityScopedResource()
         let response = gitOperations.g_push(configuration: configuration, pathURL: url)
         url.stopAccessingSecurityScopedResource()
         return response
      }
   }
   
}
