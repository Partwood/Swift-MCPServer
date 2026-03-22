//
//  JsonStructureTests.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 3/19/26.
//

import XCTest
@testable import Swift_MCPServer

final class JsonStructureTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
       /*
        */
       struct Obj: Codable {
          var val: Any
          
          enum CodingKeys: String, CodingKey {
             case val
          }
          
          init(_ val: Any) {
             self.val = val
          }
          
          init(from decoder: Decoder) throws {
             //             let container = try decoder.singleValueContainer()
             //             if let intVal = try? container.decode(Int.self) {
             //                self.value = intVal
             //             }
             throw DecodingError.dataCorrupted(
               .init(codingPath: decoder.codingPath, debugDescription: "Value cannot be decoded")
             )
          }
          
          func encode(to encoder: Encoder) throws {
             var container = encoder.singleValueContainer()
             try container.encode(AnyCodable(val))
          }
       }

       struct Pair: Codable {
          var key: String
          var val: Any
          
          enum CodingKeys: String, CodingKey {
             case key
             case val
          }
          
          init(_ key: String,_ val: Any) {
             self.key = key
             self.val = val
          }
          
          init(from decoder: Decoder) throws {
//             let container = try decoder.singleValueContainer()
//             if let intVal = try? container.decode(Int.self) {
//                self.value = intVal
//             }
             throw DecodingError.dataCorrupted(
               .init(codingPath: decoder.codingPath, debugDescription: "Value cannot be decoded")
             )
          }
          
          func encode(to encoder: Encoder) throws {
             var container = encoder.singleValueContainer()
             try container.encode([key:AnyCodable(val)])
          }
       }
       
       var convertedValue: String
       let pair1: Pair = Pair("type","object")
       convertedValue = try pair1.prettyPrintedJSONString
       debug(convertedValue)

       let pair2: Pair = Pair("required",["operation"])
       convertedValue = try pair2.prettyPrintedJSONString
       debug(convertedValue)

       let object: Obj/*Array<Pair>*/ = Obj([pair1,pair2])
       convertedValue = try object.prettyPrintedJSONString
       debug(convertedValue)
       
       let obj1 = [[],[]]
       
       let example =
       AnyCodable([
         "type": "object",
         "properties": [
            "operation": [
               "type": "string",
               "enum": AnyCodable(GitTool.Input.Operation.allCases.map({$0.rawValue})),
               "description": "One of the following values:"+GitTool.Input.Operation.allCases.map({$0.rawValue}).joined(separator:","),
            ],
            "path": [
               "type": "string",
               "description": "The location on disk, using the appropriate format for mac, windows or linux"
            ],
            "message": [
               "type": "string",
               "description": "The commit message"
            ],
            "files": [
               "type": "array",
               "items": [
                  "type": "string"
               ],
               "description": "List of files to commit"
            ],
//            "if": [
//               "properties": [ "operation": [ "const": "status" ] ]
//            ],
//            "then": [
//               "required": ["path"]
//            ],
//            "if": [
//               "properties": [ "operation": [ "const": "commit" ] ]
//            ],
//            "then": [
//               "required": ["path", "message", "files"]
//            ],
         ],
         "required": ["operation"]
       ])
       
       let existing = try example.prettyPrintedJSONString
       debug(existing)
    }
}
