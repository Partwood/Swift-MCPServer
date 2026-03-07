//
//  Logging.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Foundation
import os

/**
 Allows for control over debugging a specific file.
 */
class LogManager {
   @MainActor private static let instance = LogManager()
   
   @MainActor static func getInstance() -> LogManager {
      return LogManager.instance
   }
   
   private var ignoredFiles = Set<Substring>()
   
   @MainActor func ignore(whichFile:String = #file) {
      let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
      Logger.basicLog.log("DEBUG ignoring \(fileName, privacy: .public)")
      
      LogManager.getInstance().ignoredFiles.insert(fileName)
   }
   
   @MainActor func debug(whichFile:String = #file) {
      let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
      Logger.basicLog.log("DEBUG debugging \(fileName, privacy: .public)")
      
      LogManager.getInstance().ignoredFiles.remove(fileName)
   }
   
   @MainActor static func debugFile(_ fileName:Substring) -> Bool {
      return !LogManager.getInstance().ignoredFiles.contains(fileName)
   }
}

func logError(_ error:Error,whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   let message = "\(error)"
   let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
   
   Logger.basicLog.error("ERROR \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)] \(message, privacy: .public)")
}

func logError(_ message:String,whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
   
   Logger.basicLog.error("ERROR \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)] \(message, privacy: .public)")
}

func logWarn(_ message:String,whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
   
   Logger.basicLog.error("ERROR \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)] \(message, privacy: .public)")
}

func info(whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
   Logger.basicLog.log("INFO \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)]")
}

func info(_ message:String,whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
   Logger.basicLog.log("DEBUG \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)] \(message, privacy: .public)")
}

#if DEBUG
func debug(whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   Task {
      await MainActor.run {
         let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
         if ( LogManager.debugFile(fileName) ) {
            Logger.basicLog.log("DEBUG \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)]")
         }
      }
   }
}
func debug(_ message:String,whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {
   Task {
      await MainActor.run {
         let fileName = whichFile.suffix(from:whichFile.lastIndex(of: "/")!)
         if ( LogManager.debugFile(fileName) ) {
            Logger.basicLog.log("DEBUG \(fileName, privacy: .public)::\(whichFunction, privacy: .public)[\(whichLine, privacy: .public)] \(message, privacy: .public)")
         }
      }
   }
}
#else
func debug(whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {}
func debug(_ message:String,whichFile:String = #file,whichFunction:String = #function,whichLine:Int = #line) {}
func debugPrint(items: Any..., separator: String = " ", terminator: String = "\n") {}
//func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {}
//func print(items: Any..., separator: String = " ", terminator: String = "\n") {}
#endif

extension Logger {
   private static let subsystem = Bundle.main.bundleIdentifier!
   
   /// Logs the view cycles like viewDidLoad.
   static let basicLog = Logger(subsystem: subsystem, category: "product")
}
