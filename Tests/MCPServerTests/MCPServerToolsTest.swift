//
//  MCPServerToolsTest.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 3/4/26.
//

import XCTest
@testable import Swift_MCPServer

final class MCPServerToolsTest: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testToolList() throws {
       let server = SwiftMCPServer()
       let response: MCPResponse = server.listTools(1)
       debug("response:\(response.prettyPrintedJSONString)")
       let stringValue = response.prettyPrintedJSONString
       if let dataValue: Data = stringValue.data(using: .utf8) {
          let decoder = JSONDecoder()
          let converted:MCPResponse = try decoder.decode(MCPResponse.self,from: dataValue)
          debug("converted:\(converted.prettyPrintedJSONString)")

          if let resultMap = response.result?.value as? [String:Any] {
             if let convertedMap = converted.result?.value as? [String:Any] {
                if let anyCodable = resultMap["tools"] as? AnyCodable,
                   let arrayOfTools = anyCodable.value as? Array<Tool> {
                   if let convertedAnyCodable = convertedMap["tools"] as? [Any] {//},
                      //let convertedArrayOfTools = convertedAnyCodable.value as? Array<Tool> {
                      XCTAssertTrue(arrayOfTools.count > 0 && arrayOfTools.count == convertedAnyCodable.count)
                   } else { XCTFail() }
                } else { XCTFail() }
             } else { XCTFail() }
          } else { XCTFail() }
       } else {
          XCTFail()
       }
    }
}
