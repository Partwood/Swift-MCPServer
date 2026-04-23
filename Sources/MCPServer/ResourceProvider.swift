//
//  ResourceProvider.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 4/23/26.
//

public
protocol ResourceProvider {
   func allowedHeaders() -> Array<String>
   func urlProvider(_ context: [String:String]) -> URLProvider?
}
