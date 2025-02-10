//
//  ContentView.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import SwiftUI

struct ContentView: View {
    @State private var resultMessage = "Ready to check for Jamf Profile."
    
    var body: some View {
        VStack {
            Text("Welcome to MDM Migrator")
                .font(.headline)
                .padding()
            
            Button(action: {
                startMigration()
            }) {
                Text("Start Migration")
                    .font(.title)
                    .padding()
            }
            
            Button(action: {
                NSApplication.shared.terminate(self)
            }) {
                Text("Exit")
                    .font(.title)
                    .padding()
            }
            
            Text(resultMessage)
                .padding()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.2))
    }
    
    // Function to start the migration and prompt for credentials
    func startMigration() {
        runWithSudo(command: "/usr/bin/profiles", arguments: ["-L"]) { result in
            DispatchQueue.main.async {
                self.resultMessage = result.contains("com.jamf.") || result.contains("com.jamfsoftware.") ?
                    "Jamf profile found." : "No Jamf profile found."
            }
        }
    }
    
    // Function to run a command using osascript for sudo prompt
    func runWithSudo(command: String, arguments: [String], completion: @escaping (String) -> Void) {
        // Create the AppleScript string to run the command as sudo
        let commandString = "\(command) \(arguments.joined(separator: " "))"
        let script = """
        do shell script "\(commandString)" with administrator privileges
        """

        // Run osascript with the above script to prompt for sudo password
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        task.launch()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? "No output"
        
        completion(output)
    }
}
