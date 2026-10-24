//
//  FileContentTests.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 2/28/26.
//

import XCTest
@testable import Swift_MCPServer

final class FileContentTests: XCTestCase {
   let responseId = "-1"
   let serverInfo = ServerInfo(name: "FileContentTest", title: "", version: "", description: "")
   
   func validateOperations() throws {
      for enumValue in FileFindContentInFileTool.Input.Operation.allCases {
         XCTAssertTrue(enumValue.rawValue.lowercased() == enumValue.rawValue)
      }
   }
   
   // MARK: - Test Writing and Reading a Text File
   
   func testWriteAndReadTextFile() throws {
      // 1. Define the file content to write
      let expectedContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath+"/child dir")
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
   
   func testBasicFileAppend() throws {
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_write.txt"
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL: URL = directoryURL.appendingPathComponent(fileName)
      
      let fileAppendTool = Tool_FileAppend(serverName: "name")
      let result = fileAppendTool.appendToFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
      
         let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
         let readResult: MCPResponse = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                                  offset: 0,length: 1000)
         XCTAssertNil(result.error)
         XCTAssertFalse(result.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(initialContent+"\n", stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(initialContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
      
   func testFileInsertContent() throws {
      //                              1          2         3                   4         5
      //                    01234567890123 456789012345678901234 5678912345678901234567890123
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_insert.txt"
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      guard let data = initialContent.data(using: .utf8) else {
         XCTFail()
         return
      }
      
      let fileInsertTool = Tool_FileLineInsert(serverName: "name")//Tool_FileAppend(serverName: "name")
      let result = fileInsertTool.insertDataIntoFile(serverInfo, responseId, inPath: directoryURL.filePath, name: fileName,
                                                     atOffset: 0, newData: data)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)

      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")

      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(initialContent+"\n",stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(initialContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      guard let data = "Now ".data(using: .utf8) else {
         XCTFail()
         return
      }
      
      let offset: Int = 35
      let insertResult = fileInsertTool.insertDataIntoFile(serverInfo, responseId, inPath: directoryURL.filePath, name: fileName,
                                                           atOffset: offset, newData: data)
      XCTAssertNil(insertResult.error)
      XCTAssertFalse(insertResult.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(updatedContent+"\n",stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(updatedContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
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
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      let fileAppendTool = Tool_FileAppend(serverName: "name")
      let result = fileAppendTool.appendToFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(initialContent+"\n",stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(initialContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      let insertResult = fileAppendTool.appendToFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName, with: "\nWell now four.")
      XCTAssertNil(insertResult.error)
      XCTAssertFalse(insertResult.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nWith three lines of content.\nWell now four."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(updatedContent+"\n",stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(updatedContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   // Show that sending insert content with an offset that is a number (integer) works
   func testInsertContentViaOperation() throws {
      //                              1          2         3                   4         5
      //                    01234567890123 456789012345678901234 5678912345678901234567890123
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_insert.txt"
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      let fileAppendTool = Tool_FileAppend(serverName: "name")
      let result = fileAppendTool.appendToFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(initialContent+"\n",stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(initialContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      let si = ServerInfo(name: "test", title: "insert", version: "1.0", description: "test")
      var args: [String:Any] = [String:Any]()
      
      let offset: Int = 35
      
      args["operation"] = FileInlineInsertTool.Input.Operation.insertContent.rawValue
      args["path"] = directoryURL.filePath
      args["name"] = fileName
      args["offset"] = offset
      args["content"] = "Now "
      
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
      
      let provider = TestProvider(directoryURL)
      
      let fileInlineInsertTool = Tool_FileInlineInsert(serverName: "name")
      
      let response = try fileInlineInsertTool.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         let stringResponse: String = try readResult.stringResponse()
         XCTAssertEqual(updatedContent+"\n",stringResponse, "Read content does not match the expected value.")
         let jsonResponse: RawJSONString? = readResult.textContent
         XCTAssertEqual(updatedContent+"\n", jsonResponse?.value, "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // 6. Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }

   private func writeInitialContent(fileName: String, content: String) throws -> (directoryURL: URL,testFileURL: URL) {
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      let fileAppendTool = Tool_FileAppend(serverName: "name")
      let result = fileAppendTool.appendToFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName, with: content)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      return (directoryURL, testFileURL)
   }
   
   private func validateResponse(expected: String,response readResult: MCPResponse) throws {
      let stringResponse: String = try readResult.stringResponse()
      XCTAssertEqual(expected,stringResponse, "Read content does not match the expected value.")
      let jsonResponse: RawJSONString? = readResult.textContent
      XCTAssertEqual(expected, jsonResponse?.value, "Read content does not match the expected value.")
   }
   
   // Show that sending insert content with an offset that is a number (integer) works
   func testInsertContentViaOperation2() throws {
      //                              1          2         3                   4         5
      //                    01234567890123 456789012345678901234 5678912345678901234567890123
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_insert.txt"
      
      let urls = try writeInitialContent(fileName: fileName, content: initialContent)
      let testFileURL = urls.testFileURL
      let directoryURL = urls.directoryURL
      
      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         try validateResponse(expected: initialContent+"\n", response: readResult)
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      let si = ServerInfo(name: "test", title: "insert", version: "1.0", description: "test")
      var args: [String:Any] = [String:Any]()
      
      let offset: Int = 35
      
      args["operation"] = FileInlineInsertTool.Input.Operation.insertContent.rawValue
      args["path"] = directoryURL.filePath
      args["name"] = fileName
      args["offset"] = offset
      args["content"] = "Now "
      
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
      
      let provider = TestProvider(directoryURL)
      
      let fileLineInsertTool = Tool_FileInlineInsert(serverName: "name")
      
      let response = try fileLineInsertTool.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         try validateResponse(expected: updatedContent+"\n", response: readResult)
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   // Show that sending insert content with an offset that is a string works
   func testInsertContentViaOperationWithString() throws {
      //                              1          2         3                   4         5
      //                    01234567890123 456789012345678901234 5678912345678901234567890123
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      let fileName = "test_insert.txt"
      
      let urls = try writeInitialContent(fileName: fileName, content: initialContent)
      let testFileURL = urls.testFileURL
      let directoryURL = urls.directoryURL
      
      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         try validateResponse(expected: initialContent+"\n", response: readResult)
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      let si = ServerInfo(name: "test", title: "insert", version: "1.0", description: "test")
      var args: [String:Any] = [String:Any]()
      
      let offset: String = "35"
      
      args["operation"] = FileInlineInsertTool.Input.Operation.insertContent.rawValue
      args["path"] = directoryURL.filePath
      args["name"] = fileName
      args["offset"] = offset
      args["content"] = "Now "
      
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
      
      let provider = TestProvider(directoryURL)
      
      let fileLineInsertTool = Tool_FileInlineInsert(serverName: "name")
      
      let response = try fileLineInsertTool.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         try validateResponse(expected: updatedContent+"\n", response: readResult)
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      // Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   // Show that sending insert content with a line offset that is a number (integer) works
   func testInsertContentViaOperationByLineOffset() throws {
      let fileName = "test_insert.txt"
      let (directoryURL,testFileURL) = try createFile(fileName)
      
      let si = ServerInfo(name: "test", title: "insert", version: "1.0", description: "test")
      var args: [String:Any] = [String:Any]()
      
      args["operation"] = FileLineInsertTool.Input.Operation.insertContent.rawValue
      args["path"] = directoryURL.filePath
      args["name"] = fileName
      args["offset"] = 2
      args["content"] = "Now "
      
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
      
      let provider = TestProvider(directoryURL)
      
      var response: MCPResponse
      
      let fileLineInsertTool = Tool_FileLineInsert(serverName: "name")
      
      response = try fileLineInsertTool.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      let message = try response.stringResponse()
      XCTAssertFalse(response.isToolError, message)
      
      let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
      
      do {
         let updatedContent = "Hello, World!\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(updatedContent+"\n",try readResult.stringResponse(), "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      args["offset"] = 1
      args["content"] = "Another\n"

      response = try fileLineInsertTool.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)

      do {
         let updatedContent = "Hello, World!\nAnother\nThis is a test file.\nNow With three lines of content."
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(updatedContent+"\n",try readResult.stringResponse(), "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }

      args["offset"] = 8
      args["content"] = "\nEnd"
      
      response = try fileLineInsertTool.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)
      
      do {
         let updatedContent = "Hello, World!\nAnother\nThis is a test file.\nNow With three lines of content.\nEnd"
         
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(updatedContent,actualContent, "The file content does not match the expected value.")
         
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(updatedContent+"\n",try readResult.stringResponse(), "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }

      // Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }

   // Show that sending insert content with a line offset that is a number (integer) works
   func testReadContentRange() throws {
      let fileName = "test_read.txt"
      let (directoryURL,testFileURL) = try createFile(fileName)
      
      let t = Tool_FileReadLines(serverName: "name")
      
      let si = ServerInfo(name: "test", title: "read", version: "1.0", description: "test")
      var args: [String:Any] = [String:Any]()
      
      args["operation"] = FileReadLinesTool.Input.Operation.readContentRange.rawValue
      args["path"] = directoryURL.filePath
      args["name"] = fileName
      args[FileReadLinesTool.Input.Arguments.offset.rawValue] = 1
      args[FileReadLinesTool.Input.Arguments.length.rawValue] = 1
      
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
      
      let provider = TestProvider(directoryURL)
      
      var response: MCPResponse
      
      response = try t.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      let message: String = try response.stringResponse()
      XCTAssertFalse(response.isToolError, message)
      
      var expectedContent = "This is a test file.\n"
      XCTAssertEqual(expectedContent,try response.stringResponse(), "The read content does not match the expected value.")
      
      args[FileReadLinesTool.Input.Arguments.offset.rawValue] = 2
      
      response = try t.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)
      
      expectedContent = "With three lines of content.\n"
      XCTAssertEqual(expectedContent,try response.stringResponse(), "The read content does not match the expected value.")
      
      args[FileReadLinesTool.Input.Arguments.offset.rawValue] = 0
      
      response = try t.handleOperation(si, provider, "responseId", args)
      XCTAssertNil(response.error)
      XCTAssertFalse(response.isToolError)
      
      expectedContent = "Hello, World!\n"
      XCTAssertEqual(expectedContent,try response.stringResponse(), "The read content does not match the expected value.")

      // Clean up (delete the test file)
      try? FileManager.default.removeItem(at: testFileURL)
   }
   
   private func createFile(_ fileName: String) throws -> (directory:URL,file:URL) {
      //                              1          2         3                   4         5
      //                    01234567890123 456789012345678901234 5678912345678901234567890123
      let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."
      
      // 2. Create a temporary directory for testing
      let tempDir = FileManager.default.temporaryDirectory
      
      let directoryURL = URL(fileURLWithPath: tempDir.filePath).appending(path: "child dir",directoryHint: URL.DirectoryHint.isDirectory)
      try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
      
      let testFileURL = directoryURL.appendingPathComponent(fileName)
      
      let fileAppendTool = Tool_FileAppend(serverName: "name")
      let result = fileAppendTool.appendToFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName, with: initialContent)
      XCTAssertNil(result.error)
      XCTAssertFalse(result.isToolError)
      
      do {
         let actualContent = try String(contentsOf: testFileURL, encoding: .utf8)
         
         XCTAssertEqual(initialContent,actualContent, "The file content does not match the expected value.")
         
         let fileReadLinesTool = Tool_FileReadLines(serverName: "name")
         let readResult = fileReadLinesTool.readFile(serverInfo, responseId, at: directoryURL.filePath, name: fileName,
                                                     offset: 0,length: 1000)
         XCTAssertNil(readResult.error)
         XCTAssertFalse(readResult.isToolError)
         
         XCTAssertEqual(initialContent+"\n",try readResult.stringResponse(), "Read content does not match the expected value.")
      } catch {
         XCTFail("Failed to write or read the file: \(error.localizedDescription)")
      }
      
      return (directoryURL,testFileURL)
   }

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
      var first: Optional<Substring>
      var last: Optional<Substring>

      readResult = try readLines(directory: directory, fileName: fileName, offset: 0, length: 100)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)

      response = try readResult.stringResponse()

      XCTAssertTrue(response.hasSuffix("\n"))
      
      first = (response.split(separator: "\n").first ?? "")+"\n"
      last = (response.split(separator: "\n").last ?? "")+"\n"
      
      XCTAssertEqual("//\n",first, "Read content does not match the expected value.")
      XCTAssertEqual("         let button = NSButton(title: \"Stop Server\", target: self, action: #selector(self.buttonClicked))\n",last, "Read content does not match the expected value.")

      readResult = try readLines(directory: directory, fileName: fileName, offset: 50, length: 30)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      XCTAssertTrue(response.hasSuffix("\n"))
      
      first = (response.split(separator: "\n").first ?? "")+"\n"
      last = (response.split(separator: "\n").last ?? "")+"\n"
      
      XCTAssertEqual("   }\n",first, "Read content does not match the expected value.")
      XCTAssertEqual("      super.viewDidLoad()\n",last, "Read content does not match the expected value.")
   }
   
   func testSimpleFile() throws {
      guard let fileURL: URL = Bundle.module.url(
         forResource: "SimpleFile",
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
      var first: Optional<Substring>
      var last: Optional<Substring>
      
      readResult = try readLines(directory: directory, fileName: fileName, offset: 0, length: 100)

      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      first = response.split(separator: "\n").first
      last = response.split(separator: "\n").last
      
      XCTAssertEqual("//001",first, "Read content does not match the expected value.")
      XCTAssertEqual("//100",last, "Read content does not match the expected value.")
      XCTAssertTrue(response.hasSuffix("\n"))

      readResult = try readLines(directory: directory, fileName: fileName, offset: 0, length: 10)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      first = response.split(separator: "\n").first
      last = response.split(separator: "\n").last
      
      XCTAssertEqual("//001",first, "Read content does not match the expected value.")
      XCTAssertEqual("//010",last, "Read content does not match the expected value.")
      XCTAssertTrue(response.hasSuffix("\n"))

      readResult = try readLines(directory: directory, fileName: fileName, offset: 10, length: 10)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      first = response.split(separator: "\n").first
      last = response.split(separator: "\n").last
      
      XCTAssertEqual("//011",first, "Read content does not match the expected value.")
      XCTAssertEqual("//020",last, "Read content does not match the expected value.")
      XCTAssertTrue(response.hasSuffix("\n"))

      readResult = try readLines(directory: directory, fileName: fileName, offset: 1, length: 1)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      first = response.split(separator: "\n").first
      last = response.split(separator: "\n").last
      
      XCTAssertEqual("//002",first, "Read content does not match the expected value.")
      XCTAssertEqual("//002",last, "Read content does not match the expected value.")
      XCTAssertTrue(response.hasSuffix("\n"))

      readResult = try readLines(directory: directory, fileName: fileName, offset: 1, length: 2)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      first = response.split(separator: "\n").first
      last = response.split(separator: "\n").last
      
      XCTAssertEqual("//002",first, "Read content does not match the expected value.")
      XCTAssertEqual("//003",last, "Read content does not match the expected value.")
      XCTAssertTrue(response.hasSuffix("\n"))

      readResult = try readLines(directory: directory, fileName: fileName, offset: 50, length: 30)

      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      first = response.split(separator: "\n").first
      last = response.split(separator: "\n").last
      
      XCTAssertEqual("//051",first, "Read content does not match the expected value.")
      XCTAssertEqual("//080",last, "Read content does not match the expected value.")
      XCTAssertTrue(response.hasSuffix("\n"))
   }
   
   func testReadBytes() throws {
      //                                1          2         3                   4         5
      //                      01234567890123 456789012345678901234 5678912345678901234567890123
      //let initialContent = "Hello, World!\nThis is a test file.\nWith three lines of content."

      let fileName = "test_read_bytes.txt"
      let (directory,fileURL) = try createFile(fileName)

      var readResult: MCPResponse
      var response: String
      
      readResult = try readBytes(directory: directory, fileName: fileName, offset: 0, length: 100)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      XCTAssertEqual("Hello, World!\nThis is a test file.\nWith three lines of content.",response, "Read content does not match the expected value.")

      readResult = try readBytes(directory: directory, fileName: fileName, offset: 0, length: 10)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      XCTAssertEqual("Hello, Wor",response, "Read content does not match the expected value.")

      readResult = try readBytes(directory: directory, fileName: fileName, offset: 1, length: 1)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      XCTAssertEqual("e",response, "Read content does not match the expected value.")

      readResult = try readBytes(directory: directory, fileName: fileName, offset: 1, length: 2)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      XCTAssertEqual("el",response, "Read content does not match the expected value.")

      readResult = try readBytes(directory: directory, fileName: fileName, offset: 7, length: 10)
      
      XCTAssertNil(readResult.error)
      XCTAssertFalse(readResult.isToolError)
      
      response = try readResult.stringResponse()
      
      XCTAssertEqual("World!\nThi",response, "Read content does not match the expected value.")

      // Clean up (delete the test file)
      try? FileManager.default.removeItem(at: fileURL)
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
