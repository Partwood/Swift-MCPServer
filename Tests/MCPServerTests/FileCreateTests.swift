//
//  FileIOTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 2/28/26.
//

import XCTest
@testable import Swift_MCPServer

enum ConfigurationError: Error {
   case noData
}

// Validate that the various 'append/insert' entry points can all create a file
final class FileCreateTests: XCTestCase {
   let responseId = "-1"
   let serverInfo = ServerInfo(name: "FileContentTest", title: "", version: "", description: "")
   
   func testFileCreate_LineInsert() throws {
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_create.txt"
      
      let configuration = try configure(initialContent: initialContent, fileName: fileName)
      
      let tool = Tool_FileLineInsert(serverName: "name")
      let result = tool.insertDataIntoFile(serverInfo, responseId, inPath: configuration.directory.path(percentEncoded: false), name: fileName,
                                                     atOffset: 0, newData: configuration.data)
      try validateCreate(result, configuration.file, initialContent)
      
      try? FileManager.default.removeItem(at: configuration.file)
   }

   func testFileCreate_InLineInsert() throws {
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_create.txt"
      
      let configuration = try configure(initialContent: initialContent, fileName: fileName)
      
      let tool = Tool_FileInlineInsert(serverName: "name")
      let result = tool.insertDataIntoFile(serverInfo, responseId, inPath: configuration.directory.path(percentEncoded: false), name: fileName,
                                                     atOffset: 0, newData: configuration.data)
      try validateCreate(result, configuration.file, initialContent)
      
      try? FileManager.default.removeItem(at: configuration.file)
   }

   func testFileCreate_Append() throws {
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_create.txt"
      
      let configuration = try configure(initialContent: initialContent, fileName: fileName)
      
      let tool = Tool_FileAppend(serverName: "name")
      let result = tool.appendToFile(serverInfo, responseId, at: configuration.directory.path(percentEncoded: false), name: fileName, with: initialContent)

      try validateCreate(result, configuration.file, initialContent)
      
      try? FileManager.default.removeItem(at: configuration.file)
   }

   private func configure(initialContent: String,fileName: String) throws -> (directory: URL, file: URL, data: Data) {
      // Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.path(percentEncoded: false)).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      guard let data = initialContent.data(using: .utf8) else {
         XCTFail()
         throw ConfigurationError.noData
      }
      
      return (directoryURL,testFileURL,data)
   }
   
   private func validateCreate(_ result: MCPResponse,_ fileUrl: URL,_ expectedContent: String) throws {
      let message = try result.stringResponse()
      
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError, message)
      
      do {
         let actualContent = try String(contentsOf: fileUrl, encoding: .utf8)
         
         XCTAssertEqual(expectedContent, actualContent, "The file content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
   }
}
