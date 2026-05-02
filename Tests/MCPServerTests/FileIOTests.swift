//
//  FileIOTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 2/28/26.
//

import XCTest
@testable import Swift_MCPServer

final class FileIOTests: XCTestCase {
   let responseId = "-1"
   let serverInfo = ServerInfo(name: "FileIOTest", title: "", version: "", description: "")
   
   func testListDirectory() throws {
      let t = Tool_FileSystem(serverName: "name")
      let result = t.listDirectory(serverInfo,responseId,at: "/Users/jvsherwood/Downloads")
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      debug("Ok!")
   }
   
   // MARK: - Test Writing and Reading a Text File
   
   func testWriteAndReadTextFile() throws {
      // 1. Define the file content to write
      let expectedContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.path(percentEncoded: false)+"/child dir")
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent("test_file.txt")
      
      do {
         // 3. Write content to the file
         try expectedContent.write(to: testFileURL, atomically: true, encoding: .utf8)
         
         // 4. Read the file back
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         // 5. Verify the content matches
         XCTAssertEqual(actualContent, expectedContent, "The file content does not match the expected value.")
         
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   func testWriteContent() throws {
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_write.txt"
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.path(percentEncoded: false)).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL: URL = directoryURL.appendingPathComponent(fileName)
      
      let t = Tool_FileSystem(serverName: "name")
      let result = t.writeFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      XCTAssertTrue(result.toolContent?.contains("child dir") ?? false)
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = t.readFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName)
         XCTAssertNil(result.error)
         XCTAssertFalse(result.isToolError)
         
         XCTAssertEqual(initialContent,readResult.toolContent, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   func testInsertContent() throws {
      //                              1          2         3                   4         5
      //                    01234567890123 456789012345678901234 5678912345678901234567890123
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_insert.txt"
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.path(percentEncoded: false)).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      let t = Tool_FileSystem(serverName: "name")
      let result = t.writeFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = t.readFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(initialContent,readResult.toolContent, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      guard let data = "Now ".data(using: .utf8) else {
         XCTFail()
         return
      }
      
      let offset: UInt64 = 35
      let insertResult = t.insertDataIntoFile(serverInfo, responseId, inPath: directoryURL.path(percentEncoded: false), name: fileName, atOffset: offset, newData: data)
      XCTAssertNil(insertResult.error)
      XCTAssertFalse(insertResult.isToolError)

      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = t.readFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(updatedContent,readResult.toolContent, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }

      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   func testAppendContent() throws {
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_append.txt"
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.path(percentEncoded: false)).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      let t = Tool_FileSystem(serverName: "name")
      let result = t.writeFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = t.readFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(initialContent,readResult.toolContent, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      let insertResult = t.appendToFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName, with: "\nWell now four.")
      XCTAssertNil(insertResult.error)
      XCTAssertFalse(insertResult.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nWith three lines of content.\nWell now four."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = t.readFile(serverInfo, responseId, at: directoryURL.path(percentEncoded: false), name: fileName)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(updatedContent,readResult.toolContent, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
}
