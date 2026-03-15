//
//
//  MCPServer.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//
import Vapor
import Foundation

// https://modelcontextprotocol.io/docs/develop/build-server
// https://oneuptime.com/blog/post/2026-02-02-vapor-server-side-swift/view

struct NotFoundTrackerMiddleware: AsyncMiddleware {
   func respond(to request: Vapor.Request, chainingTo next: any Vapor.AsyncResponder) async throws -> Vapor.Response {
      // Forward the request to the next responder (which is the router if no other middleware follows)
      let response = try await next.respond(to: request)
      
      // Check if the response status is 404 Not Found
      if response.status == .notFound {
         // Log or track the unrouted request here
         request.logger.warning("Unrouted request detected: \(request.method) \(request.url.path)")
         logWarn("Unrouted request detected: \(request.method) \(request.url.path)")
         // You can send this information to an external tracking service or database
      }
      
      return response
   }
}

public
class WriterWrapper: NSObject {
   let writer:BodyStreamWriter
   
   init(writer: BodyStreamWriter) {
      self.writer = writer
   }
}

final
class MCPServerConfiguration {
   static let PROTOCOL_VERSION = "2025-06-18"
   
   let name: String
   let hostname: String
   let port: Int
   
   init(name: String, hostname: String, port: Int) {
      self.name = name
      self.hostname = hostname
      self.port = port
   }
}

public
protocol MCPServer {
   var name: String { get }
   var hostname: String { get }
   var port: Int { get }
   
   var mcpTools: Array<MCPTool> { get }
   var tools: Array<Tool>{ get }

   @MainActor
   static func startMCP(serverName: String,title: String,hostname: String,port:Int,urlProvider: URLProvider?) throws -> MCPServer
   @MainActor
   func stopMCP() throws
}

public
class SwiftMCPServer {
   private var app: Application?
   private var requestId = 1
   private var mcpSessionId = 1
   private var loopCount = 0
   private var lastResponseBody: String
   
   var internalTools = [String: MCPTool]()
   
   private var configuration: MCPServerConfiguration
   private var serverInfo: ServerInfo
   
   var urlProvider: URLProvider?
      
   public
   var readableServerInfo: ServerInfo {
      get {
         return self.serverInfo
      }
   }
   
   var serverInfoAsDictionary: [String: Any] {
      get {
         return self.serverInfo.asDictionary
      }
   }
   
   @MainActor static var loggingBootstrapped: Bool = false
   
   // For testing without network connectivity (internal stuff)
   public
   init() {
      self.app = nil
      
      self.lastResponseBody = ""
      self.configuration = MCPServerConfiguration(name: "name", hostname: "hostname", port: 0)
      self.serverInfo = ServerInfo(name: "name",title: "title", version: "1.0.0",
                                   description: "An example MCP server providing tools and resources")
      
      registerTools()
   }
   
   public
   init(app: Application,name: String,title: String, hostname: String, port: Int,urlProvider: URLProvider?) {
      self.app = app
      self.lastResponseBody = ""
      self.configuration = MCPServerConfiguration(name: name, hostname: hostname, port: port)
      self.serverInfo = ServerInfo(name: name,title: title, version: "1.0.0", description: "An example MCP server providing tools and resources")
      self.urlProvider = urlProvider

      configureRoutes()
      registerTools()
      
      // Add your custom middleware before the default ErrorMiddleware if you want to handle the logging before error conversion
      app.middleware.use(NotFoundTrackerMiddleware())
   }
      
   private func handleRequest(_ request: MCPRequest, on eventLoop: EventLoop) -> EventLoopFuture<MCPResponse> {
      return eventLoop.makeSucceededFuture(
         handleRequest(request)
      )
   }
   
   private func handleRequest(_ request: MCPRequest) -> MCPResponse {
      if let request_id = request.id {
         if ( request_id == 0 ) {
            self.requestId += 1
         } else {
            self.requestId = request_id
         }
      }
      let responseId = self.requestId
      
      debug("request.method:\(request.method)")
      
      switch request.method {
      case "initialize":
         return initialize(request)
      case "completions":
         return completions(params: request.params)
      case "tools/list":
         return listTools(responseId)
      case "tools/call":
         return callTool(request, responseId,params: request.params)
      default:
         logError("Not found! request.method:\(request.method)")
         return MCPResponse(id: String("\(responseId)"),
                        result: nil,
                        serverInfo: self.serverInfo,
                        error: MCPError(code: -32601,
                                        message: "Method not found",
                                        data: ["method": AnyCodable(request.method)]))
      }
   }
   
   private func initialize(_ request: MCPRequest) -> MCPResponse {
      let responseId = request.id ?? self.requestId
      self.requestId = request.id ?? self.requestId
      
      let capabilities = [
//         "completions": [
//            "completionProvider": true
//         ],
         "tools": [
            "listChanged": AnyCodable(true),
            "listToolsProvider": AnyCodable(true),
            "callToolProvider": AnyCodable(true)
         ] as [String:AnyCodable],
//         "notifications": [ // Add this for SSE support
//            "serverNotifications": ["weather_update", "search_results"]
//           ]
      ]
      
      return
            MCPResponse(id: String("\(responseId)"),
                     result: [
                        "capabilities": AnyCodable(capabilities),
                        "protocolVersion": AnyCodable(MCPServerConfiguration.PROTOCOL_VERSION)
                     ],
                        serverInfo: self.serverInfo,
                        error: nil)
   }
   
   private func completions(params: [String: AnyCodable]?) -> MCPResponse {
      let responseId = requestId
      requestId += 1
      
      guard let params = params,
            let prompt = params["prompt"]?.value as? String else {
         return
            MCPResponse(id: String("\(responseId)"),
                        result: nil,
                        serverInfo: self.serverInfo,
                        error: MCPError(code: -32602,
                                        message: "Invalid params",
                                        data: ["missing": AnyCodable("prompt")]))
      }
      
      // Simple completion logic
      let suggestions = ["Hello", "World", "Swift", "MCP", "Server"]
      let filtered = suggestions.filter { $0.lowercased().contains(prompt.lowercased()) }
      
      return
         MCPResponse(id: String("\(responseId)"),
                     result: [
                        "completions": AnyCodable(filtered)
                     ],
                     serverInfo: self.serverInfo,
                     error: nil)
   }
}

extension SwiftMCPServer: MCPServer {
   public
   var name: String {
      get {
         return configuration.name
      }
   }
   
   public
   var hostname: String {
      get {
         return configuration.hostname
      }
   }
   
   public
   var port: Int {
      get {
         return configuration.port
      }
   }
   
   public
   var mcpTools: Array<any MCPTool> {
      self.internalTools.map({ $0.value })
   }
   
   public
   var tools: Array<Tool>{
      get {
         return self.internalTools.map({$0.value.descriptor})
      }
   }

   @MainActor public static
   func startMCP(serverName: String,title: String,hostname: String,port:Int,urlProvider: URLProvider? = nil) throws -> MCPServer {
      debug("Starting...")
      
      do {
         var env = try Environment.detect()
         
         if ( !loggingBootstrapped ) {
            loggingBootstrapped = true
            try LoggingSystem.bootstrap(from: &env)
         }
         
         let app = Application(env)
         
         app.http.server.configuration.hostname = hostname
         app.http.server.configuration.port = port
         app.routes.defaultMaxBodySize = 10485760 // 10 MB in bytes
         
         let mcpServer = SwiftMCPServer(app: app,name: serverName,title: title,hostname: hostname,port: port,urlProvider: urlProvider)
         
         if ( urlProvider == nil ) {
            debug("No urlProvider present (nil)")
         } else {
            debug("UrlProvider is present")
         }
         
         Task {
            do {
               try await app.execute()
            } catch {
               logError(error)
            }
         }
         
         return mcpServer
      } catch {
         logError(error)
         throw error
      }
   }
   
   @MainActor public
   func stopMCP() throws {
      app?.shutdown()
      app = nil
   }
}

enum MCPServerError: Error {
   case sse
}

extension SwiftMCPServer {
   func eventStreamMediaType() -> HTTPMediaType {
      return HTTPMediaType(type: "text", subType: "event-stream")
   }
   
   func jsonMediaType() -> HTTPMediaType {
      return HTTPMediaType(type: "application", subType: "json")
   }
   
   func isCombinedRequest(_ req:Request) -> Bool {
      let es: HTTPMediaType = eventStreamMediaType()
      let js: HTTPMediaType = jsonMediaType()
      
      var esFound: Bool = false
      var jsFound: Bool = false
      req.headers.accept.mediaTypes.forEach({ mediaType in
         if ( mediaType.type == es.type && mediaType.subType == es.subType ) {
            esFound = true
         } else if ( mediaType.type == js.type && mediaType.subType == js.subType ) {
            jsFound = true
         }
      })
      
      return (esFound && jsFound)
   }
   
   func configureRoutes() {
      // Handle MCP requests
      app?.post("mcp") { req -> EventLoopFuture<Response> in
         debug("req.content:\n\(req.content)")
         
         do {
            let result = try self.post(req)
            return result
         } catch {
            logError("req.content:\n\(req.content)")
            logError(error)
            return req.eventLoop.makeFailedFuture(error)
         }
      }
      
      app?.get("mcp") { req -> EventLoopFuture<Response> in
         info("req.content:\n\(req.content)")
         
         let isSSERequest = (req.headers.accept.mediaTypes.count == 1 &&
                             req.headers.accept.mediaTypes.contains(HTTPMediaType(type: "text", subType: "event-stream")))
         
         if isSSERequest {
            // Accept: text/event-stream
            logError("req.content:\n\(req.content)")
            return req.eventLoop.makeFailedFuture(MCPServerError.sse)
         } else {
            // Return normal response
            do {
               let result = try self.get(req)
               return result
            } catch {
               logError("req.content:\n\(req.content)")
               logError("req:\n\(req)")
               logError(error)
               return req.eventLoop.makeFailedFuture(error)
            }
         }
      }
            
      // For WebSocket support (optional for MCP)
      app?.webSocket("mcp-ws") { req, ws in
         info("req.content:\n\(req.content)")
         
         ws.onClose.whenComplete { _ in
            debug("WebSocket closed")
         }
      }
      
      app?.on(.OPTIONS, "mcp") { req -> Response in
         let headers = HTTPHeaders([
            ("Access-Control-Allow-Origin", "*"),
            ("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS"),
            ("Access-Control-Allow-Headers", "Content-Type,Authorization,mcp-protocol-version,mcp-session-id,Accept,Last-Event-ID")
         ])
         
         debug("Options were requested headers:\n\(headers)")
         
         return Response(
            status: .ok,
            headers: headers
         )
      }
   }
   
   private func write(_ req: Request,_ writer: BodyStreamWriter,_ response: MCPResponse) async throws {
      if let value = response.encodeForSSE() {
         info("value:\(value)")
         let buffer = req.application.allocator.buffer(string: value)
         
         // Write data to stream
         try writer.write(.buffer(buffer))
         try? await writer.write(.end).get()
      }
   }

   func get(_ req: Request) throws -> EventLoopFuture<Response> {
      let request = try req.content.decode(MCPRequest.self)
      if (request.method == "notifications/initialized" || request.method == "notifications/cancelled"){
         debug(request.method)
         return req.eventLoop.makeSucceededFuture(Response(status: .noContent))
      }
      
      let futureMCPResponse = self.handleRequest(request, on: req.eventLoop)
      let mcpResponse = try futureMCPResponse.wait()
      
      let mcp_session_id = self.mcpSessionId
      self.mcpSessionId += 1
      
      return req.eventLoop.makeSucceededFuture(
         Response(status: .ok,
                  headers: [
                     "Access-Control-Allow-Origin": "*",
                     "Content-Type": "application/json",
                     "mcp-session-id": "\(mcp_session_id)"
                  ],
                  body: .init(string: mcpResponse.encodeForSSE() ?? "{}"))
      )
   }
   
   func post(_ req: Request) throws -> EventLoopFuture<Response> {
      if ( self.mcpSessionId == 0 ) {
         self.mcpSessionId += 1
      }
      let mcp_session_id = self.mcpSessionId

      let request = try req.content.decode(MCPRequest.self)
      if (request.method == "notifications/initialized" || request.method == "notifications/cancelled"){
         debug(request.method)

         let headers = HTTPHeaders([
            ("Access-Control-Allow-Origin", "*"),
            ("Content-Type", "application/json"),
            ("mcp-session-id", "\(mcp_session_id)"),
         ])

         return req.eventLoop.makeSucceededFuture(Response(status: .noContent,
                                                           headers: headers))
      }
      
      let mcpResponse: MCPResponse = self.handleRequest(request)
            
      let responseBody: String = (mcpResponse.encodeForSSE() ?? "{}")
      self.lastResponseBody = responseBody
      
      debug("mcp_session_id:\(mcp_session_id)")
      //debug("mcp_session_id:\(mcp_session_id)\nresponseBody:\n\(mcpResponse.prettyPrintedJSONString)")

      let headers = HTTPHeaders([
         ("Access-Control-Allow-Origin", "*"),
         ("Content-Type", "application/json"),
         ("mcp-session-id", "\(mcp_session_id)"),
      ])
      
      debug("Post response headers:\n\(headers)")

      return req.eventLoop.makeSucceededFuture(
         Response(status: .ok,
                  headers: headers,
                  body: .init(string: responseBody))
      )
   }
}
