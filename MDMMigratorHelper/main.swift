//
//  main.swift
//  MDMMigratorHelper
//
//  Created by Somesh Pathak on 22/01/2025.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation

class HelperToolDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                 shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure the connection
        newConnection.exportedInterface = NSXPCInterface(with: HelperToolProtocol.self)
        
        // Create and set the exported object
        let exportedObject = HelperTool()
        newConnection.exportedObject = exportedObject
        
        // Resume the connection
        newConnection.resume()
        
        return true
    }
}

// Create the listener for the helper tool
let delegate = HelperToolDelegate()
let listener = NSXPCListener.service()
listener.delegate = delegate

// Start the listener and run the helper tool
listener.resume()
RunLoop.main.run()
