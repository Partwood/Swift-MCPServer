//
//  Extensions.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//


extension [String:Text_Content] {
   func toAnyCodable() -> [String:AnyCodable] {
      var converted = [String:AnyCodable]()
      self.forEach({ pair in
         converted[pair.key] = pair.value.toAnyCodable()
      })
      return converted
   }
}

extension [Text_Content] {
   func toAnyCodable() -> [AnyCodable] {
      return self.map({AnyCodable($0)})
   }
}
