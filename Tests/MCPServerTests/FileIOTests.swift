//
//  FileIOTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 2/28/26.
//

import XCTest
@testable import Swift_MCPServer

final class FileIOTests: XCTestCase {
   func testListDirectory() throws {
      let t = Tool_FileSystem(serverName: "name", urlProvider: nil)
      //let result = try t.listDirectory(-1, at: "/Users/jvsherwood/Downloads")
      debug("Ok!")
   }
}
