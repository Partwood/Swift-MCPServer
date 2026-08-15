//
//  ToolProvider.swift
//  Swift-MCPServer
//
//  Copyright © 2026 JVSherwood. All rights reserved.
//


import Foundation

public
protocol ToolProvider {
   func tools(_ context: [String:String]) -> Array<MCPTool>?
   func cacheTools(_ uuid: UUID,_ tools: Array<MCPTool>?)
}
