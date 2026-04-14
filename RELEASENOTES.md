//
//  RELEASENOTES.swift
//  Swift-MCPServer
//
//  Created by Joshua V Sherwood on 3/15/26.
//

2026 Mar 15
- Add tool attributes to allow for tools to have configuration fields for values like authorization tokens (in TeamCity for example)<br>
External applications can iterate over the tools and their attributes, present fields to the user and then pass the values back to the tool for usage (and set again next use, not saved in MCPServer or MCPTool)
- Refactor of Server/Tool to allow for protocol usage to make the tool and attribute pattern more accessible
