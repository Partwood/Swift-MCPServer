//
//  AnyCodableTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 3/6/26.
//

import XCTest
@testable import Swift_MCPServer

final class AnyCodableTests: XCTestCase {

   override func setUpWithError() throws {
      // Put setup code here. This method is called before the invocation of each test method in the class.
   }

   override func tearDownWithError() throws {
     // Put teardown code here. This method is called after the invocation of each test method in the class.
   }

   func testCodable() throws {
      let object0: [String:String] = ["path": "/Users/jvsherwood/Desktop/projects/SWAMCPServer/MCPServer/Sources/MCPServer/Tools/FileIO.swift", "operation": "read"]
      let codable0 = AnyCodable(object0)
      
      var r1:String = ""
      var r2:String = ""
      var r3:String = ""
      
      if let result = codable0.encodeForSSE() {
         debug("\(result)")
         r1 = result
      } else { XCTFail() }

      let object2: [String:AnyCodable] = ["path": AnyCodable("/Users/jvsherwood/Desktop/projects/SWAMCPServer/MCPServer/Sources/MCPServer/Tools/FileIO.swift"), "operation": AnyCodable("read")]
      let codable2 = AnyCodable(object2)
      
      if let result = codable2.encodeForSSE() {
         debug("\(result)")
         r2 = result
      } else { XCTFail() }

      let object1: [String:Any] = ["path": "/Users/jvsherwood/Desktop/projects/SWAMCPServer/MCPServer/Sources/MCPServer/Tools/FileIO.swift", "operation": "read"]
      let codable1 = AnyCodable(object1)
      
      if let result = codable1.encodeForSSE() {
         debug("\(result)")
         r3 = result
      } else { XCTFail() }

      XCTAssertFalse(r1.isEmpty)
      // Note the output below can fail if the sort order changes
      XCTAssertEqual(r1, r2)
      XCTAssertEqual(r2, r3)
   }
}
