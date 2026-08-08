//
//  ResourceProvider.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 4/23/26.
//

import Foundation

public
protocol ResourceProvider {
   func allowedHeaders() -> Array<String>
   func urlProvider(_ context: [String:String]) -> URLProvider?
   func addResources(_ context: [String:String],_ urls: Array<URL>)
}
