//
//  FileUtils.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation

typealias FileFindResult = Result<FileFind,FileFindError>

struct FileFind {
   var files = Array<Text_Content>()
}

enum FileFindError: Error {
   case error(message: String,root: (any Error))
}

typealias FileContentFindResult = Result<FileContentFind,FileContentFindError>

struct FileContentFind {
   var content = Array<Text_Content>()
}

enum FileContentFindError: Error {
   case error(message: String,root: (any Error))
   case utfError(message: String)
}

public typealias FileReadResult = Result<FileRead,FileReadError>

public struct FileRead {
   public var content = Array<Text_Content>()
}

public enum FileReadError: Error {
   case error(message: String,root: (any Error))
   case eof(message: String)
}

public
final
class FileUtils {
   public
   static func accessibleURL(_ urlProvider: URLProvider?,_ path: String) -> URL? {
      guard let urlProvider else {
         debug("No urlProvider")
         return nil
      }
      let urls = urlProvider.urls
      if urls.isEmpty {
         debug("No urlProvider.urls")
         return nil
      }
      
      let expandedPath = NSString(string: path).expandingTildeInPath
      let desiredURL = URL(fileURLWithPath: expandedPath)
      
      let first = urls.first(where: { url in
         debug("url:\(url.path)\npath:\(path)")
         
         return desiredURL.isContained(in: url)
      })
      
      return first
   }

   public static func fileURL(path inPath: String,_ name: String) -> URL {
//      // Convert the tilde path (~/) to an absolute path
//      let expandedPath = NSString(string: inPath).expandingTildeInPath
//      let root = URL(fileURLWithPath: expandedPath)
//      
//      if root.lastPathComponent == name {
//         // Allow for cases where the name is already part of the path
//         return root
//      } else {
//         return root.appendingPathComponent(name)
//      }
      // Convert the tilde path (~/) to an absolute path
      let expandedPath = NSString(string: inPath).expandingTildeInPath
      
      // Ensure the path ends with a separator
      var fullPath = expandedPath
      if !fullPath.hasSuffix("/") {
         fullPath += "/"
      }
      
      // Combine the path and name without URL encoding
      let combinedPath = fullPath + name
      
      // Create the URL directly from the combined path
      return URL(fileURLWithPath: combinedPath)
   }

   public static func readFileToString(atPath path: String,name: String) throws -> String? {
      let fileURL = fileURL(path: path,name)
      
      if ( try fileURL.isExistingDirectory() ) {
         let error = FileIOError.path_is_directory(fileURL)
         logError(error)
         throw error
      }
      
      do {
         // Read file contents as Data
         let fileData = try Data(contentsOf: fileURL)
         
         // Convert to String using UTF-8 encoding
         return String(data: fileData, encoding: .utf8)
      } catch {
         logError("Error reading file:'\(fileURL.path())' error:'\(error.localizedDescription)'")
         throw FileIOError.read_error(fileURL,error)
      }
   }
}

// MARK: Read file content
extension FileUtils {
   public static func readFileOffset(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,offset: Int,length: Int) -> FileReadResult {
      if ( inPath.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let fileContentString: String?
      do {
         fileContentString = try FileUtils.readFileToString(atPath: inPath,name: name)
      } catch {
         logError(error)
         return FileReadResult.failure(FileReadError.error(message: error.localizedDescription, root: error))
      }
      
      let subString: String
      
      if let content = fileContentString {
         if let start = content.index(content.startIndex, offsetBy: Int(offset), limitedBy: content.endIndex) {
            let end = content.index(content.startIndex, offsetBy: Int(offset+length), limitedBy: content.endIndex) ?? content.endIndex
            subString = String(content[start..<end])
            
            let fileContent: Text_Content = Text_Content(text: subString)
            
            var fullContent = Array<Text_Content>()
            
            fullContent.append(fileContent)

            return FileReadResult.success(FileRead(content: fullContent))
         } else {
            let message = "End of file, file:'\(FileUtils.fileURL(path: inPath,name).path())'"
            logWarn(message)
            return FileReadResult.failure(FileReadError.eof(message: message))
         }
      } else {
         let message = "No content in file, file:'\(FileUtils.fileURL(path: inPath,name).path())'"
         logWarn(message)
         return FileReadResult.failure(FileReadError.eof(message: message))
      }
   }
}

// MARK: Find file
extension FileUtils {
   /// Given a path and name to find (and if it should be a directory), recursively
   /// - Parameters:
   ///   - rootPath: <#rootPath description#>
   ///   - name: <#name description#>
   ///   - directory: <#directory description#>
   /// - Returns: <#description#>
   func find(in rootPath: String,named name: String,directory: Bool) -> FileFindResult {
      let expandedRootPath = NSString(string: rootPath).expandingTildeInPath
      let fileManager = FileManager.default
      var foundFiles = [Text_Content]()
      
      do {
         // Get the contents of the root directory
         let rootURL = URL(fileURLWithPath: expandedRootPath)
         let contents = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if item.lastPathComponent == name && ( directory == isDirectory ) {
               // Found the file/directory directly in the root
               foundFiles.append(Text_Content(text: "Found '" + name + "' at path: " + item.path))
            }
            
            if isDirectory {
               // Recursively search in subdirectories
               let foundInSubdirs = try findRecursive(in: item.path, named: name,directory: directory)
               for foundItem in foundInSubdirs {
                  foundFiles.append(foundItem)
               }
            }
         }
      } catch {
         let message = "Error searching for file:'\(name)', error:'\(error.localizedDescription)'"
         logError(message)
         return FileFindResult.failure(FileFindError.error(message: message,root: error))
      }
      
      //let message = "No file or directory named '" + name + "' found in '" + rootPath + "'"
      return FileFindResult.success(FileFind(files: foundFiles))
   }
   
   private func findRecursive(in directoryPath: String, named name: String,directory: Bool) throws -> [Text_Content] {
      let fileManager = FileManager.default
      var foundItems = [Text_Content]()
      
      do {
         let directoryURL = URL(fileURLWithPath: directoryPath)
         let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
         
         for item in contents {
            let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            
            if item.lastPathComponent == name && ( directory == isDirectory ) {
               foundItems.append(Text_Content(text: "Found '" + name + "' at path: " + item.path))
            }
            
            if isDirectory {
               // Recursively search in subdirectories
               let foundInSubdirs = try findRecursive(in: item.path, named: name,directory: directory)
               for foundItem in foundInSubdirs {
                  foundItems.append(foundItem)
               }
            }
         }
      } catch {
         logError(error)
         throw error
      }
      
      return foundItems
   }
}

// MARK: Find Content
extension FileUtils {
   public struct SearchResult {
      public let lineNumber: Int
      public let characterOffset: Int
      public let byteOffset: Int
   }
   
   public static func find(string target: String,content: String) -> [SearchResult] {
      var results: [SearchResult] = []
      let lines = content.components(separatedBy: "\n")
      var currentByteOffset = 0
      var currentCharacterOffset = 0
      
      for (lineIdx, line) in lines.enumerated() {
         // Line indices in editor usually start at 1
         let lineNumber = lineIdx + 1
         
         // Find all occurrences within the current line
         var searchRange = line.startIndex..<line.endIndex
         while let range = line.range(of: target, options: [], range: searchRange) {
            
            // 1. Character distance from start of file
            let charDistance = content.distance(from: content.startIndex, to: range.lowerBound)
            
            // 2. Byte offset (UTF-8)
            let substring = content[..<range.lowerBound]
            let byteOffset = substring.utf8.count
            
            results.append(SearchResult(
               lineNumber: lineNumber,
               characterOffset: charDistance,
               byteOffset: byteOffset
            ))
            
            // Advance search range to find subsequent occurrences on the same line
            searchRange = range.upperBound..<line.endIndex
         }
         
         // Add lengths of line + "\n" to offsets for the next iteration
         let lineWithNewline = line + "\n"
         currentCharacterOffset += lineWithNewline.count
         currentByteOffset += lineWithNewline.utf8.count
      }
      
      return results
   }
   
   static func findContent(_ serverInfo: ServerInfo,_ responseId: String,at inPath: String,name: String,find string:String) -> FileContentFindResult {
      do {
         if let fileContentString = try FileUtils.readFileToString(atPath: inPath,name: name) {
            let searchResults = find(string: string,content: fileContentString)
            
            var results = [Text_Content]()
            
            for result in searchResults {
               let textContent = Text_Content(text: "Found '" + string + "' on line:\(result.lineNumber) at char offset:\(result.characterOffset), byte offset:\(result.byteOffset)")
               results.append(textContent)
            }
            
            return FileContentFindResult.success(FileContentFind(content: results))
         } else {
            let message = "No UTF8 string content present in file:\(name)"
            logWarn(message)
            return FileContentFindResult.failure(FileContentFindError.utfError(message: message))
         }
      } catch {
         logError(error)
         return FileContentFindResult.failure(FileContentFindError.error(message: error.localizedDescription, root: error))
      }
   }
}

// MARK: Write
extension FileUtils {
   // Helper function to write data to a temporary file and return its path
   public func writeToTempFile(path: String,ext: String,data: String) throws -> String {
      if ( path.contains("%20") ) {
         logWarn("Invalid string!!!")
      }
      
      let fileName = ProcessInfo.processInfo.globallyUniqueString + ext
      let fileURL = FileUtils.fileURL(path: path, fileName)
      
      if ( try fileURL.isExistingDirectory() ) {
         let error = Tool_FileAppend_Error.path_is_directory(fileURL)
         logError(error.description)
         throw error
      }
      
      do {
         try data.write(to: fileURL, atomically: true, encoding: .utf8)
         return fileURL.path()
      } catch {
         logError("Failed to write to temporary file: \(error.localizedDescription)")
         logError(error)
         throw error
      }
   }
}
