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
   case read_error(_ url: URL,_ root: Error? = nil)
   case write_error(_ url: URL,_ root: Error? = nil)
   case data_error(_ url: URL,_ root: Error? = nil)
   case file_not_found(_ url: URL,_ root: Error? = nil)
   case directory_not_found(_ url: URL,_ root: Error? = nil)
   case attributes_not_found(_ url: URL,_ root: Error? = nil)

   public var errorDescription: String? {
      return description
   }
}

extension FileIOError: CustomStringConvertible {
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
      case .path_is_directory(let url):
         let suffix: String = ""
         localizedMessage = NSLocalizedString("'\(url.path(percentEncoded: false))' is a directory"+suffix, comment: "Unexpected type")
      case .path_is_file(let url):
         let suffix: String = ""
         localizedMessage = NSLocalizedString("'\(url.path(percentEncoded: false))' is a file"+suffix, comment: "Unexpected type")
      case .read_error(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Failed to read file '\(url.path(percentEncoded: false))'"+suffix, comment: "Read error")
      case .write_error(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Failed to write file '\(url.path(percentEncoded: false))'"+suffix, comment: "Write error")
      case .data_error(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Invalid data for file '\(url.path(percentEncoded: false))'"+suffix, comment: "Data error")
      case .file_not_found(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("File not found for url: '\(url.path(percentEncoded: false))'"+suffix, comment: "Not found")
      case .directory_not_found(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Directory not found for url: '\(url.path(percentEncoded: false))'"+suffix, comment: "Not found")
      case .attributes_not_found(let url,let root):
         let suffix: String = getSuffix(root)
         localizedMessage = NSLocalizedString("Attributes not found for url: '\(url.path(percentEncoded: false))'"+suffix, comment: "Attribute error")
      }
      
      return localizedMessage
   }
}
