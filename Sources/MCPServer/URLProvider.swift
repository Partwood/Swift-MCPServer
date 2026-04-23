//
//  URLProvider.swift
//  MCPServer
//
//  Created by Joshua V Sherwood on 3/6/26.
//

import Foundation

public
protocol URLProvider {
   var provider: UUID { get }
   var url: URL? { get }
}
