//
//  Logger.swift
//  MDMMigratorHelper
//
//  Created by Somesh Pathak on 22/01/2025.
//  Copyright (c) 2025 [Somesh Pathak]
//

import Foundation
import OSLog

/// Log level enum
enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

/// Main logger class
final class Logger {
    static let shared = Logger()
    private let osLog: OSLog
    private let dateFormatter: DateFormatter
    private let logQueue = DispatchQueue(label: "com.company.intune4mac.logger", qos: .utility)
    private let fileManager = FileManager.default
    
    private var logFileHandle: FileHandle?
    private var currentLogFileName: String = ""
    
    // MARK: - Configuration
    private let maxLogFiles = 5
    private let maxLogSize = 10 * 1024 * 1024 // 10MB
    
    private init() {
        self.osLog = OSLog(subsystem: "com.company.intune4mac", category: "Migration")
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        
        logQueue.async { [weak self] in
            self?.setupLogFile()
        }
    }
    
    // MARK: - Public Methods
    func log(
        _ message: String,
        level: LogLevel = .info,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let timestamp = dateFormatter.string(from: Date())
        let sourceFile = (file as NSString).lastPathComponent
        
        let logMessage = """
        [\(timestamp)] \(level.emoji) [\(level.rawValue)] [\(sourceFile):\(line)] \(function):
        \(message)
        """
        
        // Log to console using OSLog
        os_log(level.osLogType, log: osLog, "%{public}@", logMessage)
        
        // Log to file
        logQueue.async { [weak self] in
            self?.writeToFile(logMessage)
        }
    }
    
    func logError(
        _ error: Error,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let nsError = error as NSError
        let errorDetails = """
        Error: \(error.localizedDescription)
        Domain: \(nsError.domain)
        Code: \(nsError.code)
        User Info: \(nsError.userInfo)
        """
        
        log(errorDetails, level: .error, file: file, function: function, line: line)
    }
    
    func startMigrationSession() {
        let divider = String(repeating: "=", count: 80)
        let message = """
        \(divider)
        Starting new migration session
        Device: \(deviceInfo())
        Date: \(dateFormatter.string(from: Date()))
        \(divider)
        """
        
        log(message, level: .info)
    }
    
    func endMigrationSession(success: Bool) {
        let divider = String(repeating: "=", count: 80)
        let message = """
        \(divider)
        Migration session ended
        Status: \(success ? "Success" : "Failed")
        Date: \(dateFormatter.string(from: Date()))
        \(divider)
        """
        
        log(message, level: .info)
    }
    
    func getLogs() -> String? {
        guard let logFileURL = getLogFileURL() else { return nil }
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }
    
    func clearLogs() {
        logQueue.async { [weak self] in
            guard let self = self else { return }
            self.closeLogFile()
            try? self.fileManager.removeItem(at: self.getLogDirectory())
            self.setupLogFile()
        }
    }
    
    // MARK: - Private Methods
    private func setupLogFile() {
        do {
            let logDirectory = getLogDirectory()
            try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
            
            currentLogFileName = "migration_\(Date().timeIntervalSince1970).log"
            let logFileURL = logDirectory.appendingPathComponent(currentLogFileName)
            
            if !fileManager.fileExists(atPath: logFileURL.path) {
                fileManager.createFile(atPath: logFileURL.path, contents: nil)
            }
            
            logFileHandle = try FileHandle(forWritingTo: logFileURL)
            
            rotateLogFiles()
        } catch {
            os_log(.error, log: osLog, "Failed to setup log file: %{public}@", error.localizedDescription)
        }
    }
    
    private func writeToFile(_ message: String) {
        guard let fileHandle = logFileHandle else { return }
        
        if let data = (message + "\n").data(using: .utf8) {
            do {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: data)
                
                if try fileHandle.offset() > maxLogSize {
                    rotateLogFiles()
                }
            } catch {
                os_log(.error, log: osLog, "Failed to write to log file: %{public}@", error.localizedDescription)
            }
        }
    }
    
    private func rotateLogFiles() {
        do {
            let logDirectory = getLogDirectory()
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])
                .filter { $0.pathExtension == "log" }
                .sorted { lhs, rhs in
                    let lhsDate = try lhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    let rhsDate = try rhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
                    return lhsDate > rhsDate
                }
            
            if logFiles.count > maxLogFiles {
                for logFile in logFiles[maxLogFiles...] {
                    try fileManager.removeItem(at: logFile)
                }
            }
        } catch {
            os_log(.error, log: osLog, "Failed to rotate log files: %{public}@", error.localizedDescription)
        }
    }
    
    private func closeLogFile() {
        logFileHandle?.closeFile()
        logFileHandle = nil
    }
    
    private func getLogDirectory() -> URL {
        let paths = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("Intune4Mac/Logs", isDirectory: true)
    }
    
    private func getLogFileURL() -> URL? {
        guard !currentLogFileName.isEmpty else { return nil }
        return getLogDirectory().appendingPathComponent(currentLogFileName)
    }
    
    private func deviceInfo() -> String {
        var info = [String]()
        
        // Get Mac Model
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/sysctl")
        process.arguments = ["-n", "hw.model"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let macModel = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                info.append("Model: \(macModel)")
            }
        } catch {
            os_log(.error, log: osLog, "Error getting Mac model: %{public}@", error.localizedDescription)
        }
        
        // Get macOS Version
        let versionProcess = Process()
        versionProcess.executableURL = URL(fileURLWithPath: "/usr/bin/sw_vers")
        versionProcess.arguments = ["-productVersion"]
        
        let versionPipe = Pipe()
        versionProcess.standardOutput = versionPipe
        
        do {
            try versionProcess.run()
            versionProcess.waitUntilExit()
            
            let data = versionPipe.fileHandleForReading.readDataToEndOfFile()
            if let osVersion = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                info.append("macOS: \(osVersion)")
            }
        } catch {
            os_log(.error, log: osLog, "Error getting macOS version: %{public}@", error.localizedDescription)
        }
        
        // Get Serial Number
        let profileProcess = Process()
        profileProcess.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        profileProcess.arguments = ["SPHardwareDataType"]
        
        let profilePipe = Pipe()
        profileProcess.standardOutput = profilePipe
        
        do {
            try profileProcess.run()
            profileProcess.waitUntilExit()
            
            let data = profilePipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                if let serial = output.components(separatedBy: "Serial Number (system): ").last?.components(separatedBy: "\n").first {
                    info.append("Serial: \(serial.trimmingCharacters(in: .whitespacesAndNewlines))")
                }
            }
        } catch {
            os_log(.error, log: osLog, "Error getting serial number: %{public}@", error.localizedDescription)
        }
        
        return info.joined(separator: ", ")
    }
}

// MARK: - Convenience Methods
extension Logger {
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, file: file, function: function, line: line)
    }
    
    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, file: file, function: function, line: line)
    }
}
