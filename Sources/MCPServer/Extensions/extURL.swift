//
//  extURL.swift
//  MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//

import Cocoa

extension URL {
   /// Returns true if this URL is contained within the other URL
   func isContained(in parentURL: URL) -> Bool {
      // Standardize both URLs by resolving symlinks and getting absolute paths
      let standardizedSelf = self.resolvingSymlinksInPath().standardizedFileURL
      let standardizedParent = parentURL.resolvingSymlinksInPath().standardizedFileURL
      
      // Check if the path starts with the parent's path
      return standardizedSelf.path.starts(with: standardizedParent.path)
   }
   
   /// Given the current url and a sourceURL that is expected to be a child, return a copy of the
   func append(from sourceURL: URL) -> URL? {
      // Standardize both URLs by resolving symlinks and getting absolute paths
      let standardizedSelf = self.resolvingSymlinksInPath().standardizedFileURL
      let standardizedSource = sourceURL.resolvingSymlinksInPath().standardizedFileURL
      
      // Check if the path starts with the parent's path
      if ( !standardizedSource.path.starts(with: standardizedSelf.path) ) {
         // Not contained
         return nil
      }
      
      let selfPath = self.pathComponents
      let sourcePath = sourceURL.pathComponents
      
      var result: URL = self
      
      for pathComponent in sourcePath.enumerated() {
         if ( pathComponent.offset < selfPath.count ) {
            continue
         } else {
            // Must have accessed url securely
            result.append(path: pathComponent.element)
         }
      }
      
      return result
   }
}
