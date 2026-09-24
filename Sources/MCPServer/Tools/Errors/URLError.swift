//
//  URLError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

enum URLError: LocalizedError {
   case invalid(_ urlString: String)
   case no_content(_ url: URL)
   case does_not_exist(_ url: URL)
}

extension URLError: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .invalid(let urlString):
         return NSLocalizedString("Invalid URL: \(urlString)", comment: "Invalid url")
      case .no_content(let url):
         return NSLocalizedString("No content found for URL: \(url.path())", comment: "204, no content")
      case .does_not_exist(let url):
         return NSLocalizedString("The file does not exist for URL: \(url.path())", comment: "Does not exist")
      }
   }
}
