//
//  FileFindContentTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 2/28/26.
//
// ^}\s*$
import XCTest
@testable import Swift_MCPServer

final class FileFindContentTests: XCTestCase {
   let responseId = "-1"
   let serverInfo = ServerInfo(name: "FileFindContentTest", title: "", version: "", description: "")
   
   func testSampleCode() throws {
      guard let fileURL: URL = Bundle.module.url(
         forResource: "SampleCode",
         withExtension: "txt",
         subdirectory: "Resources"
      ) else {
         XCTFail("Missing test resource file")
         return
      }
      
      let directory: URL = fileURL.deletingLastPathComponent()
      let fileName: String = fileURL.lastPathComponent
      
      var readResult: MCPResponse
      var response: String
      var found: Optional<Substring>
      var first: String
      var last: String

      readResult = try find(directory: directory, fileName: fileName, find: "^}\\s*$")
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)

      response = try readResult.stringResponse()

      found = (response.split(separator: "\n").first ?? "")
      first = String(response.split(separator: "\n")[1])
      last = String((response.split(separator: "\n").last ?? ""))
      
      XCTAssertTrue(found?.starts(with: "Found") ?? false, "Read content does not match the expected value.")
      XCTAssertTrue(first.starts(with: "- line:52, char offset:0, byte offset:0"), "'\(first)'")
      XCTAssertTrue(last.starts(with: "- line:483, char offset:0, byte offset:0"), "'\(last)'")

      readResult = try find(directory: directory, fileName: fileName, find: "var statusTextField")
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      found = (response.split(separator: "\n").first ?? "")+"\n"
      first = String(response.split(separator: "\n")[1])+"\n"
      last = (response.split(separator: "\n").last ?? "")+"\n"

      XCTAssertTrue(found?.starts(with: "Found") ?? false, "Read content does not match the expected value.")
      XCTAssertTrue(first.starts(with: "- line:56, char offset:3, byte offset:3"), "'\(first)'")
      XCTAssertTrue(last.starts(with: "- line:56, char offset:3, byte offset:3"), "'\(last)'")
   }

   private func find(directory: URL,fileName: String,find: String) throws -> MCPResponse {
      var args: [String:Any] = [String:Any]()
      
      args["operation"] = FileFindContentInFileTool.Input.Operation.findContent.rawValue
      args["path"] = directory.filePath
      args["name"] = fileName
      args[FileFindContentInFileTool.Input.Arguments.find.rawValue] = find
      
      class TestProvider: URLProvider {
         let auxs: Array<URL>
         
         func auxUrls(_ urls: Array<URL>) {
            return
         }
         
         let id = UUID()
         private var testUrls = Array<URL>()
         
         init(_ url: URL) {
            testUrls.append(url)
            auxs = []
         }
         
         var provider: UUID { get {return self.id }}
         var urls: Array<URL> { get {return self.testUrls }}
      }
      
      let provider = TestProvider(directory)
      
      let si = ServerInfo(name: "test", title: "read", version: "1.0", description: "test")
      let tool = Tool_FileFindContentInFile(serverName: "name")
      return try tool.handleOperation(si, provider, "responseId", args)
   }

   private func readLines(directory: URL,fileName: String,offset: Int,length: Int) throws -> MCPResponse {
      var args: [String:Any] = [String:Any]()
      
      args["operation"] = FileReadLinesTool.Input.Operation.readContentRange.rawValue
      args["path"] = directory.filePath
      args["name"] = fileName
      args[FileReadLinesTool.Input.Arguments.offset.rawValue] = offset
      args[FileReadLinesTool.Input.Arguments.length.rawValue] = length
      
      class TestProvider: URLProvider {
         let auxs: Array<URL>
         
         func auxUrls(_ urls: Array<URL>) {
            return
         }
         
         let id = UUID()
         private var testUrls = Array<URL>()
         
         init(_ url: URL) {
            testUrls.append(url)
            auxs = []
         }
         
         var provider: UUID { get {return self.id }}
         var urls: Array<URL> { get {return self.testUrls }}
      }
      
      let provider = TestProvider(directory)
      
      let si = ServerInfo(name: "test", title: "read", version: "1.0", description: "test")
      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
      return try fileReadLinesTool.handleOperation(si, provider, "responseId", args)
   }
   
   private func readBytes(directory: URL,fileName: String,offset: Int,length: Int) throws -> MCPResponse {
      var args: [String:Any] = [String:Any]()
      
      args["operation"] = FileReadBytesTool.Input.Operation.readContentRange.rawValue
      args["path"] = directory.filePath
      args["name"] = fileName
      args[FileReadBytesTool.Input.Arguments.offset.rawValue] = offset
      args[FileReadBytesTool.Input.Arguments.length.rawValue] = length
      
      class TestProvider: URLProvider {
         let auxs: Array<URL>
         
         func auxUrls(_ urls: Array<URL>) {
            return
         }
         
         let id = UUID()
         private var testUrls = Array<URL>()
         
         init(_ url: URL) {
            testUrls.append(url)
            auxs = []
         }
         
         var provider: UUID { get {return self.id }}
         var urls: Array<URL> { get {return self.testUrls }}
      }
      
      let provider = TestProvider(directory)
      
      let si = ServerInfo(name: "test", title: "read", version: "1.0", description: "test")
      let fileReadBytesTool = Tool_FileReadBytes(serverName: "name")
      return try fileReadBytesTool.handleOperation(si, provider, "responseId", args)
   }
}
