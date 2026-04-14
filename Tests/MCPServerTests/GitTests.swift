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
   func testGitOperations() throws {
      let td = FileManager.default.temporaryDirectory.path()
      debug("td:\n\(td)")
      
      let url = URL(filePath: "/private"+td).appending(path: "gittest")
      
      var isDirectory: ObjCBool = false
      if FileManager.default.fileExists(atPath: url.path(),isDirectory: &isDirectory) {
         if ( isDirectory.boolValue ) {
            try FileManager.default.removeItem(at: url)
         }
      }
      
      let t = GitOperations()
      let configuration = Configuration(response_id: "", serverInfo: ServerInfo(name: "", title: "", version: "", description: ""))
      
      var result: MCPResponse
      var jsonString: String
      
      result = t.g_init(configuration: configuration, pathURL: url)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)
      
      if let content = result.toolContent {
         if content.starts(with: "Repository initialized in path '/private") {
            //url.absoluteURL
         }
      }
      
      result = t.g_status(configuration: configuration,pathURL: url)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)
      
      let fileURL = url.appending(path: "testfile.txt")
      createFile(fileURL,content: "This is a test file")
      
      result = t.g_status(configuration: configuration,pathURL: url)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      XCTAssertEqual("path:testfile.txt status:workingTreeNew", result.toolContent)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)

      result = t.g_add(configuration: configuration,pathURL: url,files: [fileURL.path()])
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)

      result = t.g_status(configuration: configuration,pathURL: url)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      XCTAssertEqual("path:testfile.txt status:indexNew", result.toolContent)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)

      result = t.g_commit(configuration: configuration,pathURL: url,message: "First add",files: ["testfile.txt"])
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)

      result = t.g_status(configuration: configuration,pathURL: url)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      jsonString = try result.prettyPrintedJSONString
      XCTAssertFalse(jsonString.isEmpty)
      debug(jsonString)

//      result = t.g_push(configuration: configuration,pathURL: url)
//      jsonString = try result.prettyPrintedJSONString
//      XCTAssertFalse(jsonString.isEmpty)
//      debug(jsonString)
//
//      result = t.g_status(configuration: configuration,pathURL: url)
//      jsonString = try result.prettyPrintedJSONString
//      XCTAssertFalse(jsonString.isEmpty)
//      debug(jsonString)
   }

   private
   func createFile(_ fileURL: URL, content: String) {
      do {
         // 1. Define the URL for the new file.
         // This example uses the Desktop directory for simplicity,
         // but a production app should use a sandboxed directory
         // like Application Support or rely on user interaction.
         //let desktopURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
         //let fileURL = desktopURL.appendingPathComponent(fileName)
         
         // 2. Convert the content string to Data.
         let data = content.data(using: .utf8)
         
         // 3. Write the data to the URL.
         try data?.write(to: fileURL, options: .atomic)
         debug("File created successfully at: \(fileURL.path)")
      } catch {
         debug("Error creating file: \(error.localizedDescription)")
      }
   }
}
