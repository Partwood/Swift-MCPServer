//
//  XCode.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor

struct TeamCityTool: Content {
   let name: String
   static let description = "Perform teamcity rest operations"
   
   struct Input: Content, Codable {
      enum Operation: String, Codable, CaseIterable {
         case status = "status"
      }
      
      let operation: Operation
      let userName: String
      let userPassword: String
      let accessToken: String
   }
   
   init(serverName: String) {
      name = "mcp_"+serverName+"_teamcity"
   }
}

final
class Tool_TeamCity {
   let internalDescriptor: Tool
   let tool:TeamCityTool
   let urlProvider: URLProvider?
   
   init(serverName: String,urlProvider: URLProvider?) {
      self.tool = TeamCityTool(serverName: serverName)
      self.urlProvider = urlProvider
      
      internalDescriptor =
      Tool(
         name: tool.name,
         description: TeamCityTool.description,
         inputSchema: AnyCodable([
            "type": "object",
            "properties": [
               "url": [
                  "type": "string",
                  "description": "A url that identifies the root url for teamcity, for example http://192.168.1.7:8111",
               ],
               "operation": [
                  "type": "string",
                  "description": "Use one of the following values:"+TeamCityTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
               ],
//               "userName": [
//                  "type": "string",
//                  "description": "User name for access.",
//               ],
//               "userPassword": [
//                  "type": "string",
//                  "description": "User password for access.",
//               ],
//               "accessToken": [
//                  "type": "string",
//                  "description": "An access token for access.",
//               ],
            ],
            "required": ["url","operation"]
         ])
      )
   }

   let accessToken = "eyJ0eXAiOiAiVENWMiJ9.R25lMnFyVXJKNkJoeUdiaGIzNjBFWF9WbXZY.YzhiZjVhZWQtMjA1OC00ZDY1LTk1NmUtZGJiMDRjODlmZmFk"
}

extension Tool_TeamCity: MCPTool {
   var descriptor: Tool { get { return self.internalDescriptor } }
   var name: String { get { return self.tool.name } }

   func handleOperation(_ serverInfo: ServerInfo, _ req: MCPRequest, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      debug("req:\(req)")
      //debug("req:\n\(req)\narguments:\n\(arguments)")
      
      let inUrl: String = (arguments["url"] as? String ?? "").lowercased()
      if ( inUrl.isEmpty ) {
         let message = "A url for teamcity is required, for example http://192.168.1.7:8111"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }

//      let inUserName: String = (arguments["userName"] as? String ?? "").lowercased()
//      let inUserPassword: String = (arguments["userPassword"] as? String ?? "").lowercased()
//      let inAccessToken: String = (arguments["accessToken"] as? String ?? "").lowercased()
//      if ( inUrl.isEmpty ) {
//      }
      
      let whichOperation: String = (arguments["operation"] as? String ?? "").lowercased()
      guard let inOperation = TeamCityTool.Input.Operation(rawValue: whichOperation) else {
         let operations = TeamCityTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator: ",")
         let message = "Unknown operation '\(whichOperation)' valid operations are \(operations)"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }

      switch inOperation {
      case .status:
         return status(serverInfo, responseId, url: inUrl)
         break
      }
   }
}

extension Tool_TeamCity {
   func status(_ serverInfo: ServerInfo, _ responseId: String,url inURL: String, timeout: TimeInterval = 30.0) -> MCPResponse {
      guard let rootUrl: URL = URL(string: inURL) else {
         return MCPResponse.toolError(id: responseId, message: "Unable to construct URL from '\(inURL)'", serverInfo: serverInfo)
      }
      let buildURL = rootUrl.appendingPathComponent("app/rest/builds")
      
      let semaphore = DispatchSemaphore(value: 0)
      var httpResponse: HTTP.Response?
      
      let headers = ["Authorization":"Bearer "+self.accessToken]
      HTTP().get(buildURL, headers: headers,callback: { response in
         httpResponse = response
         semaphore.signal()
      })
      
      let timeoutResult = semaphore.wait(timeout: .now() + timeout)
      if timeoutResult == .timedOut {
         let message = "Status request timed out after \(timeout) seconds"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
      }
      
      if let httpResponse {
         if httpResponse.isError {
            if let message = httpResponse.error {
               logError(message.description)
               return MCPResponse.toolError(id: responseId, message: message.description, serverInfo: serverInfo)
            } else {
               let message = "Unknown error"
               logError(message)
               return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
            }
         } else {
            if let content = httpResponse.content {
               return MCPResponse.toolSuccess(id: responseId, text: content, serverInfo: serverInfo)
            } else {
               let message = "Unknown error, http content not present"
               logError(message)
               return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
            }
         }
      } else {
         let message = "No response during http get processing on url:'\(buildURL)'"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message, serverInfo: serverInfo)
      }
   }
}
