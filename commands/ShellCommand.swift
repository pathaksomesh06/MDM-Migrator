//
//  ShellCommand.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation

/// Errors that can occur during shell command execution
enum ShellCommandError: LocalizedError {
    case commandNotFound(String)
    case executionFailed(String)
    case invalidOutput
    case timeout
    case invalidPrivileges
    
    var errorDescription: String? {
        switch self {
        case .commandNotFound(let command):
            return "Command not found: \(command)"
        case .executionFailed(let message):
            return "Command execution failed: \(message)"
        case .invalidOutput:
            return "Invalid command output"
        case .timeout:
            return "Command timed out"
        case .invalidPrivileges:
            return "Insufficient privileges to execute command"
        }
    }
}

/// Result of a shell command execution
struct ShellCommandResult {
    let output: String
    let error: String
    let exitCode: Int32
    
    var isSuccessful: Bool {
        return exitCode == 0
    }
    
    var combinedOutput: String {
        [output, error].filter { !$0.isEmpty }.joined(separator: "\n")
    }
}

final class ShellCommand {
    /// Execute a shell command
    static func execute(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        asRoot: Bool = false,
        timeout: TimeInterval? = nil
    ) async throws -> ShellCommandResult {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        // Check if running as root when required
        if asRoot && getuid() != 0 {
            throw ShellCommandError.invalidPrivileges
        }
        
        // Setup process
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set working directory if specified
        if let workingDirectory = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }
        
        // Handle command path
        if command.starts(with: "/") {
            process.executableURL = URL(fileURLWithPath: command)
        } else {
            // Try to find command in PATH
            if let commandPath = try? which(command) {
                process.executableURL = URL(fileURLWithPath: commandPath)
            } else {
                throw ShellCommandError.commandNotFound(command)
            }
        }
        
        process.arguments = arguments
        
        // Setup timeout if specified
        var timeoutTask: DispatchWorkItem?
        if let timeout = timeout {
            timeoutTask = DispatchWorkItem {
                process.terminate()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutTask!)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try process.run()
                
                process.terminationHandler = { process in
                    timeoutTask?.cancel()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    
                    let result = ShellCommandResult(
                        output: output.trimmingCharacters(in: .whitespacesAndNewlines),
                        error: error.trimmingCharacters(in: .whitespacesAndNewlines),
                        exitCode: process.terminationStatus
                    )
                    
                    if process.terminationStatus == -1 && timeoutTask?.isCancelled == false {
                        continuation.resume(throwing: ShellCommandError.timeout)
                    } else {
                        continuation.resume(returning: result)
                    }
                }
            } catch {
                continuation.resume(throwing: ShellCommandError.executionFailed(error.localizedDescription))
            }
        }
    }
    
    /// Execute a shell command and return output as string
    static func executeAndReturnOutput(
        _ command: String,
        arguments: [String] = [],
        asRoot: Bool = false
    ) async throws -> String {
        let result = try await execute(command, arguments: arguments, asRoot: asRoot)
        guard result.isSuccessful else {
            throw ShellCommandError.executionFailed(result.error)
        }
        return result.output
    }
    
    /// Execute a shell command and return success status
    static func executeAndReturnSuccess(
        _ command: String,
        arguments: [String] = [],
        asRoot: Bool = false
    ) async throws -> Bool {
        let result = try await execute(command, arguments: arguments, asRoot: asRoot)
        return result.isSuccessful
    }
    
    /// Find path of a command in PATH
    private static func which(_ command: String) throws -> String {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            throw ShellCommandError.commandNotFound(command)
        }
        
        return path
    }
    
    /// Check if a command exists in PATH
    static func commandExists(_ command: String) -> Bool {
        return (try? which(command)) != nil
    }
}

// MARK: - Convenience Methods
extension ShellCommand {
    /// Check if running as root
    static var isRoot: Bool {
        return getuid() == 0
    }
    
    /// Execute a command with sudo
    static func sudo(
        _ command: String,
        arguments: [String] = []
    ) async throws -> ShellCommandResult {
        if isRoot {
            return try await execute(command, arguments: arguments)
        } else {
            return try await execute("/usr/bin/sudo", arguments: [command] + arguments)
        }
    }
    
    /// Read a file's contents
    static func readFile(_ path: String) async throws -> String {
        try await executeAndReturnOutput("/bin/cat", arguments: [path])
    }
    
    /// Write contents to a file
    static func writeFile(_ path: String, contents: String) async throws {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "cat > \(path)"]
        process.standardInput = pipe
        
        try process.run()
        
        if let data = contents.data(using: .utf8) {
            try pipe.fileHandleForWriting.write(contentsOf: data)
            try pipe.fileHandleForWriting.close()
        }
        
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw ShellCommandError.executionFailed("Failed to write to file: \(path)")
        }
    }
}

// MARK: - Common Commands
extension ShellCommand {
    /// Get current user
    static func getCurrentUser() async throws -> String {
        try await executeAndReturnOutput("/usr/bin/whoami")
    }
    
    /// Check if a process is running
    static func isProcessRunning(_ processName: String) async throws -> Bool {
        let result = try await execute("/bin/ps", arguments: ["-ax", "-o", "comm"])
        return result.output.contains(processName)
    }
    
    /// Kill a process
    static func killProcess(_ processName: String, force: Bool = false) async throws {
        let signal = force ? "-9" : "-15"
        _ = try await execute("/usr/bin/pkill", arguments: [signal, processName])
    }
    
    /// Get system info
    static func getSystemInfo() async throws -> [String: String] {
        var info: [String: String] = [:]
        
        // Get OS version
        if let version = try? await executeAndReturnOutput("/usr/bin/sw_vers", arguments: ["-productVersion"]) {
            info["osVersion"] = version
        }
        
        // Get hardware info
        if let model = try? await executeAndReturnOutput("/usr/sbin/sysctl", arguments: ["-n", "hw.model"]) {
            info["model"] = model
        }
        
        // Get serial number
        if let serial = try? await executeAndReturnOutput("/usr/sbin/system_profiler", arguments: ["SPHardwareDataType"]) {
            if let serialNumber = serial.components(separatedBy: "Serial Number (system): ").last?.components(separatedBy: "\n").first {
                info["serialNumber"] = serialNumber.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        return info
    }
}
