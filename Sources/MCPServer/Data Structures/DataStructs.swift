//
//
//  DataStructs.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Vapor

public
struct ServerInfo {
   var name: String
   var title: String
   var version: String
   var description: String
   
   var asDictionary: [String: Any] {
      get {
         var dictionary = [String: Any]()
         dictionary["name"] = name
         dictionary["title"] = title
         dictionary["version"] = version
         dictionary["description"] = description
         return dictionary
      }
   }
}

struct Text_Content: Content {
   let type: String
   let text: String
   
   init(type: String = "text", text: String) {
      self.type = type
      self.text = text
   }
   
   func toAnyCodable() -> AnyCodable {
      return AnyCodable(self)
   }
}

public
struct Tool: Content {
   public let name: String
   public let description: String
   let inputSchema: AnyCodable
   
   enum CodingKeys: String, CodingKey {
      case name
      case description
      case inputSchema = "inputSchema"
   }
}

// Define our MCP protocol structures
public
struct MCPRequest: Content {
   let id: Int?
   let method: String
   let params: [String: AnyCodable]?

   enum CodingKeys: String, CodingKey {
      case id
      case method
      case params
   }
}

struct Configuration {
   let response_id: String
   let serverInfo: ServerInfo
}

public
struct MCPResponse: Content {
   var jsonrpc: String = "2.0"
   let id: String?
   let result: AnyCodable?
   let error: MCPError?

   let method: String?
   let params: [String: AnyCodable]?
   
   static func success(id: String,result inResult: [String: AnyCodable]?,serverInfo: ServerInfo) -> MCPResponse {
      return MCPResponse(id: id, result: inResult,serverInfo: serverInfo, error: nil)
   }
   
   static func fail(id: String,code: Int,message: String,data: [String: AnyCodable]?,serverInfo: ServerInfo) -> MCPResponse {
      let mcpError = MCPError(code: code,
               message: message,
               data: data)
      
      return MCPResponse(id: id,
                  result: nil,
                  serverInfo: serverInfo,
                  error: mcpError)
   }
   
   static func toolError(_ configuration: Configuration,message: String) -> MCPResponse {
      return MCPResponse.toolError(id: configuration.response_id,message: message,serverInfo: configuration.serverInfo)
   }
   
   static func toolError(id: String,message: String,serverInfo: ServerInfo) -> MCPResponse {
      let body = Text_Content(type: "text", text: message)
      
      var content = [String:AnyCodable]()
      content["content"] = AnyCodable([body])
      content["isError"] = AnyCodable(true)
      
      return MCPResponse.success(id: id, result: content,serverInfo: serverInfo)
   }

   static func toolSuccess(_ configuration: Configuration,text value: String) -> MCPResponse {
      return MCPResponse.toolSuccess(id: configuration.response_id, content: [Text_Content(text: value)],serverInfo: configuration.serverInfo)
   }

   static func toolSuccess(id: String,text value: String,serverInfo: ServerInfo) -> MCPResponse {
      return MCPResponse.toolSuccess(id: id, content: [Text_Content(text: value)],serverInfo: serverInfo)
   }

   static func toolSuccess(_ configuration: Configuration,content values:Array<Text_Content>) -> MCPResponse {
      return MCPResponse.toolSuccess(id: configuration.response_id, content: values, serverInfo: configuration.serverInfo)
   }
   
   static func toolSuccess(id: String,content values:Array<Text_Content>,serverInfo: ServerInfo) -> MCPResponse {
      var content = [String:AnyCodable]()
      content["content"] = AnyCodable(values)
      return MCPResponse.success(id: id, result: content,serverInfo: serverInfo)
   }
   
   // Response with server info
   init(id: String,result inResult: [String: AnyCodable]?, serverInfo: ServerInfo, error: MCPError?) {
      var outResult: [String: AnyCodable]? = inResult
      outResult?["serverInfo"] = AnyCodable(serverInfo.asDictionary)

      self.id = id
      
      if let outResult {
         self.result = AnyCodable(outResult)
      } else {
         self.result = nil
      }
      
      self.error = error
      
      self.method = nil
      self.params = nil
   }
   
   // Notification or Message
   init(method: String?, params: [String: AnyCodable]?,error: MCPError?) {
      self.id = nil
      self.result = nil
      self.error = error
      
      self.method = method
      self.params = params
   }

   static func Message(method: String?, params: [String: AnyCodable]?,error: MCPError? = nil) -> MCPResponse {
      return MCPResponse(method: method, params: params, error: error)
   }
   
   func encodeForSSE() -> String? {
      do {
         let data = try JSONEncoder().encode(self)
         return String(data: data, encoding: .utf8)
      } catch {
         logError("Failed to encode MCPResponse: \(error)")
         return nil
      }
   }
}

struct MCPError: Content {
   let code: Int
   let message: String
   let data: [String: AnyCodable]?
}
