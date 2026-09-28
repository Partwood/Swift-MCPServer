//
//  RegExError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

enum RegExErrorError: LocalizedError {
   case invalid_pattern(_ pattern: String)

   public var errorDescription: String? {
      return description
   }
}

extension RegExErrorError: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .invalid_pattern(let pattern):
         return NSLocalizedString("Operation error: Invalid wildcard pattern '\(pattern)'", comment: "Invalid pattern")
      }
   }
}
