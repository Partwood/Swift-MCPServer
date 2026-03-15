//
//  TeamCityTests.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 3/14/26.
//

import XCTest
@testable import Swift_MCPServer

final class TeamCityTests: XCTestCase {

   override func setUpWithError() throws {
      // Put setup code here. This method is called before the invocation of each test method in the class.
   }
   
   override func tearDownWithError() throws {
      // Put teardown code here. This method is called after the invocation of each test method in the class.
   }

   /**
    Use the tool mcp_SwagenticMCP_teamcity and url http://192.168.1.7:8111
    Tell me the most recent status of each build type
    */
   func testStatus() throws {
      let si = ServerInfo(name: "", title: "", version: "", description: "")
      let t = Tool_TeamCity(serverName: "name")
      let result = t.status(si, "", url: "http://192.168.1.7:8111")
      XCTAssertNil(result.error)
   }
}
