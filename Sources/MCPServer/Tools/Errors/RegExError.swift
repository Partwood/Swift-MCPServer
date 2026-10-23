//
//  RegExError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

enum RegExError: LocalizedError {
   case invalid_pattern(_ pattern: String,_ root: Error? = nil)

   public var errorDescription: String? {
      return description
   }
}

extension RegExError: CustomStringConvertible {
   private func getSuffix(_ inError: Error?) -> String {
      if let inError {
         return ", error:\(inError.localizedDescription)"
      } else {
         return ""
      }
   }

   var description: String {
      switch(self) {
      case .invalid_pattern(let pattern,let root):
         let suffix: String = getSuffix(root)
         return NSLocalizedString("Operation error: Invalid wildcard pattern '\(pattern)'"+suffix, comment: "Invalid pattern")
      }
   }
}
