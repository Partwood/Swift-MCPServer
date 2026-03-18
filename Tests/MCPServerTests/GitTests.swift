//
//  GitTests.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 3/17/26.
//

import XCTest
@testable import Swift_MCPServer

final class GitTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

   /*
    Using the tool mcp_SwagenticMCP_git can you tell me the status in /Users/jvsherwood/Desktop/projects/Packages/Swift-MCPServer/
    Do not use mcp_SwagenticMCP_filesystem
    */
    func testStatus() throws {
       let t = Tool_Git(serverName: "name", urlProvider: nil)
       let configuration = Configuration(response_id: "", serverInfo: ServerInfo(name: "", title: "", version: "", description: ""))
       let url = URL(fileURLWithPath: "/Users/jvsherwood/Desktop/projects/Packages/Swift-MCPServer/")
       let result = t.status(configuration: configuration,pathURL: url)
       XCTAssertFalse(result.prettyPrintedJSONString.isEmpty)
       debug(result.prettyPrintedJSONString)
    }
}
