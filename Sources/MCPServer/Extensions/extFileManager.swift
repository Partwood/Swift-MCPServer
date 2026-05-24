//
//  extFileManager.swift
//  Swift-MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

extension FileManager {
   func isDirectory(atPath path: String) -> Bool {
      var isDir: ObjCBool = false
      let exists = fileExists(atPath: path, isDirectory: &isDir)
      return exists && isDir.boolValue
   }
}
