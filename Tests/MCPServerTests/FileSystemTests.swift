//
//  FileIOTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 2/28/26.
//

import XCTest
@testable import Swift_MCPServer

final class FileSystemTests: XCTestCase {
   let responseId = "-1"
   let serverInfo = ServerInfo(name: "FileSystemTest", title: "", version: "", description: "")
   
   func validateOperations() throws {
      for enumValue in FileSystemTool.Input.Operation.allCases {
         XCTAssertTrue(enumValue.rawValue.lowercased() == enumValue.rawValue)
      }
   }
   
   func testListDirectory() throws {
      let t = Tool_FileSystem(serverName: "name")
      let result = t.listDirectory(serverInfo,responseId,at: "/Users/jvsherwood/Downloads")
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      debug("Ok!")
   }   
}
