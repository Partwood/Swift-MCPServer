//
//  XCode.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor

struct TeamCityTool: Content {
   let name: String
   static let description = "Perform TeamCity rest operations"
   
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
   private let internalDescriptor: Tool
   private let tool:TeamCityTool
   private var toolAttributes: [String:MCPToolAttribute]
   
   init(serverName: String) {
      self.tool = TeamCityTool(serverName: serverName)
      self.toolAttributes = [String:MCPToolAttribute]()
      
      let accessTokenAttribute = MCPToolAttribute(name: "AccessToken", description: "The authorization bearer token that allows access to TeamCity")
      self.toolAttributes[accessTokenAttribute.name] = accessTokenAttribute
      
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
            ],
            "required": ["url","operation"]
         ])
      )
   }
}

extension Tool_TeamCity: MCPTool {
   var name: String { get { return self.tool.name } }
   var descriptor: Tool { get { return self.internalDescriptor } }

   var attributes: [MCPToolAttribute] {
      return toolAttributes.map({ $0.value })
   }
   
   func attributeValue(attribute: MCPToolAttribute, value: String) {
      debug("attribute:\(attribute.name) value:\(value)")
      self.toolAttributes[attribute.name]?.value = value
   }
   
   func handleOperation(_ serverInfo: ServerInfo, _ req: MCPRequest, _ responseId: String, _ arguments: [String : Any]) throws -> MCPResponse {
      debug("req:\(req)")
      //debug("req:\n\(req)\narguments:\n\(arguments)")
      
      let inUrl: String = (arguments["url"] as? String ?? "").lowercased()
      if ( inUrl.isEmpty ) {
         let message = "A url for teamcity is required, for example http://192.168.1.7:8111"
         logError(message)
         return MCPResponse.toolError(id: responseId, message: message,serverInfo: serverInfo)
      }
      
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
      
      let token: String = (self.toolAttributes["AccessToken"]?.value ?? "")
      let headers = ["Authorization":"Bearer "+token]
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
