//
//  HTTP.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

class HTTP {
   private lazy var Get_Session: URLSession = {
      let configuration = URLSessionConfiguration.default
      configuration.timeoutIntervalForRequest = 60 // 1 Minute
      //configuration.timeoutIntervalForResource = 1200 // 20 minutes // leave at default (7 days)
      configuration.isDiscretionary = false // Set to true to wait for Wi-Fi/power
      configuration.waitsForConnectivity = true
      return URLSession(configuration: configuration)
   }()
   
   func get(_ url: URL, headers: [String: String]? = nil, callback: @escaping ((_ response: Response)->Void)) {
      debug("url:\(url)")
      
      var request = URLRequest(url: url)
      if let headers = headers {
         for (key, value) in headers {
            debug("Using header key:'\(key)' value:'\(value)'")
            request.addValue(value, forHTTPHeaderField: key)
         }
      }
      
      let task = Get_Session.dataTask(with: request) { data, response, error in
         if let error = error {
            callback(Response(error: HTTPError.unknown(root: error)))
            return
         }
         
         guard let httpResponse = response as? HTTPURLResponse else {
            callback(Response(error:.invalid_httpurlresponse))
            return
         }
         guard (200...299).contains(httpResponse.statusCode) else {
            callback(Response(error: .status_code(code: httpResponse.statusCode)))
            return
         }
         guard let data = data else {
            callback(Response(error: .data_missing))
            return
         }
         
         if let content = String(data: data, encoding: .utf8) {
            callback(Response(data: data,content: content))
         } else {
            callback(Response(error: .string_missing))
         }
      }
      
      task.resume()
   }

   enum HTTPError: Error,CustomStringConvertible {
      case unknown(root: Error)
      case invalid_httpurlresponse
      case status_code(code: Int)
      case data_missing
      case string_missing
      
      var description: String {
         get {
            switch(self) {
            case .unknown(let root):
               return "Unexpected error '\(root.localizedDescription)'"
            case .invalid_httpurlresponse:
               return "Invalid http url response"
            case .status_code(let code):
               return "Invalid status code '\(code)'"
            case .data_missing:
               return "Http data missing"
            case .string_missing:
               return "Http data could not be converted to a string"
            }
         }
      }
   }
   
   struct Response {
      var error: HTTPError?
      var data: Data?
      var content: String?
      
      var isError: Bool {
         get {
            return (error != nil)
         }
      }
      
      init(error: HTTPError? = nil, data: Data? = nil, content: String? = nil) {
         self.error = error
         self.data = data
         self.content = content
      }
   }
}
