//
//  Encodable.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

extension Encodable {
   /// A pretty printed JSON string representation of the object.
   var prettyPrintedJSONString: String {
      get throws {
         let encoder = JSONEncoder()
         encoder.outputFormatting = .prettyPrinted
         let data = try encoder.encode(self)
         return String(data: data, encoding: .utf8) ?? ""
      }
   }
   
   var withoutEscapingSlashesJSONString: String {
      get throws {
         let encoder = JSONEncoder()
         encoder.outputFormatting = .withoutEscapingSlashes
         let data = try encoder.encode(self)
         return String(data: data, encoding: .utf8) ?? ""
      }
   }
}
