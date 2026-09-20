//
//  FileIOError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

enum FileIOError: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)
   case read_error(_ url: URL)
}

extension FileIOError: CustomStringConvertible {
   var description: String {
      switch(self) {
      case .path_is_directory(let url):
         return NSLocalizedString("Operation error: '\(url)' is a directory", comment: "Unexpected directory")
      case .path_is_file(let url):
         return NSLocalizedString("Operation error: '\(url)' is a file", comment: "Unexpected file")
      case .read_error(let url):
         return NSLocalizedString("Failed to read file '\(url)", comment: "Read error")
      }
   }
}
