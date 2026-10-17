//
//  URLError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

public
enum URLError: LocalizedError {
   case invalid(_ urlString: String,_ root: Error? = nil)
   case response_invalid(_ url: URL,message: String,_ root: Error? = nil)
   case no_content(_ url: URL,statusCode: Int? = nil,_ root: Error? = nil)
   case invalid_content(_ url: URL,expected: String,actual: String,_ root: Error? = nil)
   case status_code(_ url: URL,statusCode: Int,_ root: Error? = nil)
   case does_not_exist(_ url: URL,_ root: Error? = nil)
   case data(_ url: URL,message: String,_ root: Error? = nil)
   case file_type(_ url: URL,_ root: Error? = nil)

   public var errorDescription: String? {
      return description
   }
}

extension URLError: CustomStringConvertible {
   private func getSuffix(_ inError: Error?) -> String {
      if let inError {
         return ", error:\(inError.localizedDescription)"
      } else {
         return ""
      }
   }

   public
   var description: String {
      let localizedMessage: String
      
      switch(self) {
      case .invalid(let urlString,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Invalid URL:'\(urlString)'"+suffix, comment: "Invalid url")
      case .response_invalid(let url, let message,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Response invalid for URL:'\(url.absoluteString)' \(message)"+suffix, comment: "Invalid response")
      case .status_code(let url,let statusCode,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("HTTP request returned status code \(statusCode) for URL:'\(url.absoluteString)'"+suffix, comment: "Status code")
      case .no_content(let url,let statusCode,let root):
         let suffix: String = getSuffix(root)
         if let status = statusCode {
            localizedMessage = NSLocalizedString("HTTP request returned status code \(status), no content for URL:'\(url.absoluteString)'"+suffix, comment: "<code>, no content")
         } else {
            localizedMessage = NSLocalizedString("No content found for URL:'\(url.absoluteString)'"+suffix, comment: "204, no content")
         }
      case .invalid_content(let url,let expected,let actual,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Invalid content found for URL:'\(url.absoluteString)' expected '\(expected)' but got '\(actual)'"+suffix, comment: "204, invalid content")
      case .does_not_exist(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("The file does not exist for URL:'\(url.absoluteString)'"+suffix, comment: "Does not exist")
      case .data(let url, let message,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("\(message) for URL:'\(url.absoluteString)'"+suffix, comment: "Data error")
      case .file_type(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("URL:'\(url.absoluteString)' is a file type, do not use HTTP for files"+suffix, comment: "Type error")
      }
      
      return localizedMessage
   }
}
