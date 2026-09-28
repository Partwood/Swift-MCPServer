//
//  ToolArguments.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 9/26/26.
//

import Foundation

enum ToolArgumentError: LocalizedError {
   case argument_missing(message: String)
   case invalid_string(message: String)
   case empty_string(message: String)
   case invalid_integer(message: String)
   case path_not_accessible(message: String)
   case enum_missing(message: String)

   public var errorDescription: String? {
      return description
   }
}

extension ToolArgumentError: CustomStringConvertible {
   public
   var description: String {
      let localizedMessage: String
      
      switch(self) {
      case .argument_missing(let message):
         localizedMessage = NSLocalizedString(message, comment: "Missing")
      case .empty_string(let message):
         localizedMessage = NSLocalizedString(message, comment: "Empty")
      case .invalid_string(let message):
         localizedMessage = NSLocalizedString(message, comment: "Invalid")
      case .invalid_integer(let message):
         localizedMessage = NSLocalizedString(message, comment: "Invalid")
      case .path_not_accessible(let message):
         localizedMessage = NSLocalizedString(message, comment: "Not Accessible")
      case .enum_missing(let message):
         localizedMessage = NSLocalizedString(message, comment: "Missing")
      }
      
      return localizedMessage
   }
}

public
class ToolArguments {
   private let arguments: [String : Any]

   public
   init(arguments: [String : Any]) {
      self.arguments = arguments
   }
   
   func asString(_ argument: String,allowEmpty: Bool) throws -> String {
      if let value = arguments[argument] {
         if let stringValue = value as? String {
            if ( !allowEmpty && stringValue.isEmpty ) {
               let stringError = ToolArgumentError.empty_string(message: "\(argument) is an empty string")
               logError(stringError)
               throw stringError
            } else {
               return stringValue
            }
         } else {
            let stringError = ToolArgumentError.invalid_string(message: "\(argument) is not a string")
            logError(stringError)
            throw stringError
         }
      } else {
         let stringError = ToolArgumentError.argument_missing(message: "\(argument) not provided")
         logError(stringError)
         throw stringError
      }
   }
   
   private func asInteger(_ argument: String) throws -> Int {
      if let value = arguments[argument] {
         if let intValue: Int = value as? Int {
            return intValue
         } else if let valueString: String = value as? String,
                   let intValue: Int = Int(valueString) {
            return intValue
         } else {
            let integerError = ToolArgumentError.invalid_string(message: "\(argument) is not an integer or a string that is an integer value")
            logError(integerError)
            throw integerError
         }
      } else {
         let integerError = ToolArgumentError.argument_missing(message: "\(argument) not provided")
         logError(integerError)
         throw integerError
      }
   }
      
   public func asInteger(_ argument: String,min: Int? = nil,max: Int? = nil) throws -> Int {
      let value = try asInteger(argument)
      
      if let min {
         if ( value < min ) {
            let message = "\(argument) value(\(value)) is to small, should be equal or greater than \(min)"
            let integerError = ToolArgumentError.invalid_integer(message: message)
            logError(integerError)
            throw integerError
         }
      }
      
      if let max {
         if ( value > max ) {
            let message = "\(argument) value(\(value)) is to large, should be equal or less than \(max)"
            let integerError = ToolArgumentError.invalid_integer(message: message)
            logError(integerError)
            throw integerError
         }
      }
      
      return value
   }
   
   func asAccessibleURL(_ urlProvider: URLProvider?,_ argument: String) throws -> (path: String,rootURL: URL) {
      let argumentPath: String = try asString(argument,allowEmpty: false)
      
      guard let whichURL = FileUtils.accessibleURL(urlProvider,argumentPath) else {
         let paths = urlProvider?.urls.map({ "\"\($0.path)\"" }).joined(separator: ",")
         let message = "\(argumentPath) is not accessible, path is not a child of the paths: \(paths ?? "nil")"
         let argumentError = ToolArgumentError.path_not_accessible(message: message)
         logError(argumentError)
         throw argumentError
      }
      
      return (argumentPath, whichURL)
   }
   
   func enumFromString<T>(_ argument: String, as enumType: T.Type) throws -> T where T: RawRepresentable, T.RawValue == String, T: CaseIterable {
      let possibleValue: String = try asString(argument, allowEmpty: false).lowercased()
      
      // Check if the string matches any raw value in the enum
      if let matched = T(rawValue: possibleValue) {
         return matched
      }
      
      // Collect all actual raw string values to list in the error
      let actualValues = T.allCases.map { $0.rawValue }
      let message = "Unknown \(argument) '\(possibleValue)'. Valid options for \(argument) are \(actualValues) and are all lower case."
      let enumError = ToolArgumentError.enum_missing(message: message)
      logError(enumError)
      throw enumError
   }
}
