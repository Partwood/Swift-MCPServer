//
//  FileIOError.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/17/26.
//

import Foundation

public
enum FileIOError: LocalizedError {
   case path_is_directory(_ url: URL)
   case path_is_file(_ url: URL)
   case read_error(_ url: URL)
   case file_not_found(_ url: URL)
   case directory_not_found(_ url: URL)
   case attributes_not_found(_ url: URL)

   public var errorDescription: String? {
      return description
   }
}

extension FileIOError: CustomStringConvertible {
   public
   var description: String {
      let localizedMessage: String
      
      switch(self) {
      case .path_is_directory(let url):
         localizedMessage = NSLocalizedString("'\(url.path())' is a directory", comment: "Unexpected type")
      case .path_is_file(let url):
         localizedMessage = NSLocalizedString("'\(url.path())' is a file", comment: "Unexpected type")
      case .read_error(let url):
         localizedMessage = NSLocalizedString("Failed to read file '\(url.path())'", comment: "Read error")
      case .file_not_found(let url):
         localizedMessage = NSLocalizedString("File not found for url: '\(url.path())'", comment: "Not found")
      case .directory_not_found(let url):
         localizedMessage = NSLocalizedString("Directory not found for url: '\(url.path())'", comment: "Not found")
      case .attributes_not_found(let url):
         localizedMessage = NSLocalizedString("Attributes not found for url: '\(url.path())'", comment: "Attribute error")
      }
      
      return localizedMessage
   }
}
