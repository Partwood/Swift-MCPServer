//
//  URLError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

public
enum URLError: LocalizedError {
   case invalid(_ urlString: String)
   case response_invalid(_ url: URL,message: String)
   case no_content(_ url: URL,statusCode: Int? = nil)
   case status_code(_ url: URL,statusCode: Int)
   case does_not_exist(_ url: URL)
   case data(_ url: URL,message: String)
   case file_type(_ url: URL)

   public var errorDescription: String? {
      return description
   }
}

extension URLError: CustomStringConvertible {
   public
   var description: String {
      let localizedMessage: String
      
      switch(self) {
      case .invalid(let urlString):
         localizedMessage = NSLocalizedString("Invalid URL:'\(urlString)'", comment: "Invalid url")
      case .response_invalid(let url, let message):
         localizedMessage = NSLocalizedString("Response invalid for URL:'\(url.absoluteString)' \(message)", comment: "Invalid response")
      case .status_code(let url,let statusCode):
         localizedMessage = NSLocalizedString("HTTP request returned status code \(statusCode) for URL:'\(url.absoluteString)'", comment: "Status code")
      case .no_content(let url,let statusCode):
         if let status = statusCode {
            localizedMessage = NSLocalizedString("HTTP request returned status code \(status), no content for URL:'\(url.absoluteString)'", comment: "<code>, no content")
         } else {
            localizedMessage = NSLocalizedString("No content found for URL:'\(url.absoluteString)'", comment: "204, no content")
         }
      case .does_not_exist(let url):
         localizedMessage = NSLocalizedString("The file does not exist for URL:'\(url.absoluteString)'", comment: "Does not exist")
      case .data(let url, let message):
         localizedMessage = NSLocalizedString("\(message) for URL:'\(url.absoluteString)'", comment: "Data error")
      case .file_type(let url):
         localizedMessage = NSLocalizedString("URL:'\(url.absoluteString)' is a file type, do not use HTTP for files", comment: "Type error")
      }
      
      return localizedMessage
   }
}
