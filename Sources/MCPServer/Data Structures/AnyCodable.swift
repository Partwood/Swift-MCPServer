//
//  AnyCodable.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//
import Vapor

// Helper to handle any Codable type
struct AnyCodable: Codable, @unchecked Sendable {
   let value: Any
   
   init(_ value: Any) {
      self.value = value
   }
   
   init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      if let intVal = try? container.decode(Int.self) {
         self.value = intVal
      } else if let stringVal = try? container.decode(String.self) {
         self.value = stringVal
      } else if let boolVal = try? container.decode(Bool.self) {
         self.value = boolVal
      } else if let arrayVal = try? container.decode([AnyCodable].self) {
         self.value = arrayVal.map { $0.value }
      } else if let dictVal = try? container.decode([String: AnyCodable].self) {
         self.value = dictVal.mapValues { $0.value }
      } else {
         throw DecodingError.dataCorrupted(
            .init(codingPath: decoder.codingPath, debugDescription: "Value cannot be decoded")
         )
      }
   }

   enum CodingKeys: String, CodingKey {
      case value
   }

   func encode(to encoder: Encoder) throws {
      var container = encoder.singleValueContainer()
      switch value {
      case let intVal as Int:
         try container.encode(intVal)
      case let stringVal as String:
         try container.encode(stringVal)
      case let boolVal as Bool:
         try container.encode(boolVal)
      case let arrayVal as [AnyCodable]:
         let anyCodableArray = arrayVal.map { $0 }
         try container.encode(anyCodableArray)
      case let arrayVal as [Any]:
         let anyCodableArray = arrayVal.map { AnyCodable($0) }
         try container.encode(anyCodableArray)
      case let dictVal as [String: AnyCodable]:
         let anyCodableDict = dictVal.mapValues { $0 }
         try container.encode(anyCodableDict)
      case let dictVal as [String: Any]:
         let anyCodableDict = dictVal.mapValues { AnyCodable($0) }
         try container.encode(anyCodableDict)
      default:
         do {
            if let encodable = value as? Encodable {
               try container.encode(encodable)
               return
            } else {
               logError("object in value is not Encodable value:\(value)")
            }
         } catch {
            logError(error)
         }
         
         throw EncodingError.invalidValue(
            value,
            .init(codingPath: encoder.codingPath, debugDescription: "Value cannot be encoded")
         )
      }
   }
   
   func encodeForSSE() -> String? {
      do {
         if let encodable = self.value as? Encodable {
            let data = try JSONEncoder().encode(encodable)
            return String(data: data, encoding: .utf8)
         } else if let arrayVal = self.value as? [Any] {
            let anyCodableArray = arrayVal.map { AnyCodable($0) }
            let data = try JSONEncoder().encode(anyCodableArray)
            return String(data: data, encoding: .utf8)
         } else if let dictVal = self.value as? [String: Any] {
            let anyCodableDict = dictVal.mapValues { AnyCodable($0) }
            let data = try JSONEncoder().encode(anyCodableDict)
            return String(data: data, encoding: .utf8)
         } else {
            logError("Failed to encode AnyCodable: \(self.value)")
            return nil
         }
      } catch {
         logError("Failed to encode AnyCodable: \(error)")
         return nil
      }
   }
}

extension AnyCodable: CustomStringConvertible {
   var description: String {
      return self.encodeForSSE() ?? "Conversion Failed"
   }
}
