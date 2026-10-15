//
//  WebGetUtils.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/27/26.
//

import Foundation

class WebGetUtils {
   // Create a simple, Sendable mutable box to safely share data across threads.
   // Because we synchronize access manually with a lock/semaphore, we can mark it unchecked.
   final class SendableBox: @unchecked Sendable {
      var data: Data? = nil
      var error: Error? = nil
   }
   
   static func getAsString(url: String) throws -> String {
      guard let getURL = URL(string: url) else {
         throw URLError.invalid(url)
      }
      
      let data = try WebGetUtils.get(url: url)
      
      if let string = String(data: data, encoding: .utf8) {
         return string
      } else {
         throw URLError.data(getURL, message: "Unable to get string from data")
      }
   }
   
   static func get(url: String, mimeType: String? = nil) throws -> Data {
      guard let getURL = URL(string: url) else {
         let invalidURLError = URLError.invalid(url)
         logError(invalidURLError)
         throw invalidURLError
      }
      
      if getURL.isFileURL {
         let fileTypeError = URLError.file_type(getURL)
         logError(fileTypeError)
         throw fileTypeError
      }
      
      let semaphore = DispatchSemaphore(value: 0)
      
      // Instantiate our Sendable container.
      // Swift 6 allows capturing this object because it's explicitly marked 'Sendable'
      let container = SendableBox()
      
      var request = URLRequest(url: getURL)
      request.httpMethod = "GET"
      request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
      if let requestType = mimeType {
         if isMimeType(type: requestType) {
            request.setValue(requestType, forHTTPHeaderField: "Accept")
         } else {
            logError("Invalid mime type requested \(requestType)")
         }
      }
      
      URLSession.shared.dataTask(with: request) { data, response, error in
         // Defer guarantees the caller thread unblocks even if parsing throws an error
         defer { semaphore.signal() }
         
         if let error {
            let containerError = URLError.response_invalid(getURL, message: "", error)
            logError(containerError)
            container.error = containerError
            return
         }
         
         if let httpResponse = response as? HTTPURLResponse {
            if (200...299).contains(httpResponse.statusCode) {
               if ( httpResponse.statusCode == 204 ) {
                  // No content
                  let dataError = URLError.no_content(getURL,statusCode: httpResponse.statusCode)
                  logError(dataError)
                  container.error = dataError
                  return
               } else {
                  // If caller declared an expected mimetype, and we get an actual that doesn't match, treat as error
                  if let expected = mimeType,
                     let actual = httpResponse.mimeType {
                     if ( expected != actual ) {
                        let mimeTypeError = URLError.invalid_content(getURL,expected: expected,actual: actual)
                        logError(mimeTypeError)
                        container.error = mimeTypeError
                        return
                     }
                  }

                  guard let data = data else {
                     let dataError = URLError.no_content(getURL)
                     logError(dataError)
                     container.error = dataError
                     return
                  }
                  
                  container.data = data
               }
            } else {
               // Error
               let dataError = URLError.status_code(getURL,statusCode: httpResponse.statusCode)
               logError(dataError)
               container.error = dataError
               return
            }
         } else {
            // Not HTTP
            let dataError = URLError.response_invalid(getURL,message: "Respones is not an HTTPURLResponse")
            logError(dataError)
            container.error = dataError
            return
         }
      }.resume()
      
      // HARD BLOCK: Execution freezes here, waiting for the background network task
      semaphore.wait()
      
      if let containerError = container.error {
         throw containerError
      }

      guard let data = container.data else {
         let dataError = URLError.no_content(getURL)
         logError(dataError)
         throw dataError
      }
      
      if let expected = mimeType {
         let dataMimeType = data.mimeType
         if dataMimeType != DEFAULT_MIME_TYPE {
            // We got a known type, check it
            if ( expected != dataMimeType ) {
               let dataError = URLError.invalid_content(getURL,expected: expected, actual: dataMimeType)
               logError(dataError)
               throw dataError
            }
         }
      }

      return data
   }
}
