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
      let encoder = JSONEncoder()
      encoder.outputFormatting = .prettyPrinted
      guard let data = try? encoder.encode(self) else { return "" }
      return String(data: data, encoding: .utf8) ?? ""
   }
   
   var withoutEscapingSlashesJSONString: String {
      let encoder = JSONEncoder()
      encoder.outputFormatting = .withoutEscapingSlashes
      guard let data = try? encoder.encode(self) else { return "" }
      return String(data: data, encoding: .utf8) ?? ""
   }
}
