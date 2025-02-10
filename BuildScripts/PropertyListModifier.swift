//
//  PropertyListModifier.swift
//  MDMMigratorHelper
//
//  Created by Somesh Pathak on 22/01/2025.
//  Copyright (c) 2025 [Somesh Pathak]
//

#!/usr/bin/swift

import Foundation

// MARK: - Constants
let infoPropertyListKey = "__info_plist"
let launchdPropertyListKey = "__launchd_plist"
let textSegment = "__TEXT"

// MARK: - Configuration
struct Configuration {
    let appBundleId: String
    let helperBundleId: String
    let projectDir: String
    
    init() {
        appBundleId = "IntuneIRL.MDMMigrator"
        helperBundleId = "IntuneIRL.MDMMigrator.helper"
        projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] ?? ""
    }
}

// MARK: - Error Types
enum ScriptError: Error {
    case invalidArguments
    case fileNotFound(String)
    case invalidPropertyList(String)
    case writeFailed(String)
    case environmentError(String)
}

// MARK: - Main Script Logic
class PropertyListModifier {
    let config = Configuration()
    
    func run() throws {
        guard !config.projectDir.isEmpty else {
            throw ScriptError.environmentError("PROJECT_DIR environment variable not set")
        }
        
        let args = CommandLine.arguments
        guard args.count > 1 else {
            throw ScriptError.invalidArguments
        }
        
        print("Project Directory: \(config.projectDir)")
        
        for argument in args[1...] {
            switch argument {
            case "satisfy-job-bless-requirements":
                try satisfyJobBlessRequirements()
            case "specify-mach-services":
                try specifyMachServices()
            case "auto-increment-version":
                try autoIncrementVersion()
            case "cleanup-job-bless-requirements":
                try cleanupJobBlessRequirements()
            case "cleanup-mach-services":
                try cleanupMachServices()
            default:
                print("Warning: Unknown argument '\(argument)'")
            }
        }
    }
    
    // MARK: - Job Bless Requirements
    private func satisfyJobBlessRequirements() throws {
        // Update app's Info.plist
        let appInfoPlistPath = "\(config.projectDir)/Resources/Info.plist"
        let helperPlistPath = "\(config.projectDir)/MDMMigratorHelper/IntuneIRL.MDMMigrator.helper.plist"
        
        print("Looking for app Info.plist at: \(appInfoPlistPath)")
        print("Looking for helper plist at: \(helperPlistPath)")
        
        var appInfoPlist = try loadPropertyList(at: URL(fileURLWithPath: appInfoPlistPath))
        
        // Add SMPrivilegedExecutables
        let requirement = "identifier \"\(config.helperBundleId)\" and anchor apple generic"
        appInfoPlist["SMPrivilegedExecutables"] = [config.helperBundleId: requirement]
        
        try savePropertyList(appInfoPlist, to: URL(fileURLWithPath: appInfoPlistPath))
        
        // Update helper's plist
        var helperPlist = try loadPropertyList(at: URL(fileURLWithPath: helperPlistPath))
        
        // Add SMAuthorizedClients
        let clientRequirement = "identifier \"\(config.appBundleId)\" and anchor apple generic"
        helperPlist["SMAuthorizedClients"] = [clientRequirement]
        
        try savePropertyList(helperPlist, to: URL(fileURLWithPath: helperPlistPath))
    }
    
    // MARK: - Mach Services
    private func specifyMachServices() throws {
        let launchdPlistPath = "\(config.projectDir)/MDMMigratorHelper/IntuneIRL.MDMMigrator.helper.plist"
        print("Looking for helper plist at: \(launchdPlistPath)")
        
        var launchdPlist = try loadPropertyList(at: URL(fileURLWithPath: launchdPlistPath))
        
        // Set Label
        launchdPlist["Label"] = config.helperBundleId
        
        // Add MachServices
        launchdPlist["MachServices"] = [config.helperBundleId: true]
        
        try savePropertyList(launchdPlist, to: URL(fileURLWithPath: launchdPlistPath))
    }
    
    // MARK: - Version Management
    private func autoIncrementVersion() throws {
        let helperPlistPath = "\(config.projectDir)/MDMMigratorHelper/IntuneIRL.MDMMigrator.helper.plist"
        var helperPlist = try loadPropertyList(at: URL(fileURLWithPath: helperPlistPath))
        
        // Get current version
        let currentVersion = helperPlist["CFBundleVersion"] as? String ?? "1.0"
        let components = currentVersion.split(separator: ".")
        
        // Increment last component
        if var lastComponent = components.last.flatMap({ Int($0) }) {
            lastComponent += 1
            let newVersion = components.dropLast().joined(separator: ".") + ".\(lastComponent)"
            helperPlist["CFBundleVersion"] = newVersion
            try savePropertyList(helperPlist, to: URL(fileURLWithPath: helperPlistPath))
        }
    }
    
    // MARK: - Cleanup
    private func cleanupJobBlessRequirements() throws {
        let appInfoPlistPath = "\(config.projectDir)/Resources/Info.plist"
        var appInfoPlist = try loadPropertyList(at: URL(fileURLWithPath: appInfoPlistPath))
        appInfoPlist.removeValue(forKey: "SMPrivilegedExecutables")
        try savePropertyList(appInfoPlist, to: URL(fileURLWithPath: appInfoPlistPath))
    }
    
    private func cleanupMachServices() throws {
        let launchdPlistPath = "\(config.projectDir)/MDMMigratorHelper/IntuneIRL.MDMMigrator.helper.plist"
        var launchdPlist = try loadPropertyList(at: URL(fileURLWithPath: launchdPlistPath))
        launchdPlist.removeValue(forKey: "MachServices")
        try savePropertyList(launchdPlist, to: URL(fileURLWithPath: launchdPlistPath))
    }
    
    // MARK: - Helper Methods
    private func loadPropertyList(at url: URL) throws -> [String: Any] {
        print("Attempting to load plist from: \(url.path)")
        
        guard let data = try? Data(contentsOf: url) else {
            throw ScriptError.fileNotFound(url.path)
        }
        
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            throw ScriptError.invalidPropertyList(url.path)
        }
        
        return plist
    }
    
    private func savePropertyList(_ plist: [String: Any], to url: URL) throws {
        print("Saving plist to: \(url.path)")
        
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        
        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            throw ScriptError.writeFailed(url.path)
        }
        
        try data.write(to: url)
        print("Successfully saved plist to: \(url.path)")
    }
}

// MARK: - Script Execution
do {
    let modifier = PropertyListModifier()
    try modifier.run()
} catch {
    print("Error: \(error)")
    exit(1)
}
