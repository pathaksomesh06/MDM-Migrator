//
//  HelperTool.swift
//  MDMMigratorHelper
//
//  Created by Somesh Pathak on 22/01/2025.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import AppKit

@objc(HelperTool)
final class HelperTool: NSObject, HelperToolProtocol {
    private let version = "1.0"
    private let logger = Logger.shared
    
    // MARK: - System Operations
    
    func removeJamfManagement(withReply reply: @escaping (Error?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        process.arguments = ["-R", "-p", "com.jamf.management"]
        
        do {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            if process.terminationStatus == 0 {
                logger.info("Successfully removed Jamf management profile")
                reply(nil)
            } else {
                let error = HelperToolError.operationFailed("Failed to remove Jamf profile: \(output)")
                logger.error("Failed to remove Jamf profile: \(output)")
                reply(error)
            }
        } catch {
            logger.error("Error removing Jamf profile: \(error.localizedDescription)")
            reply(HelperToolError.operationFailed(error.localizedDescription))
        }
    }
    
    func removeJamfFramework(withReply reply: @escaping (Error?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/rm")
        process.arguments = ["-rf", "/Library/Application Support/JAMF"]
        
        do {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                logger.info("Successfully removed Jamf framework")
                reply(nil)
            } else {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = HelperToolError.operationFailed("Failed to remove Jamf framework: \(output)")
                logger.error("Failed to remove Jamf framework: \(output)")
                reply(error)
            }
        } catch {
            logger.error("Error removing Jamf framework: \(error.localizedDescription)")
            reply(HelperToolError.operationFailed(error.localizedDescription))
        }
    }
    
    func enrollInIntune(withReply reply: @escaping (Error?) -> Void) {
        // Here you would implement the Intune enrollment process
        // This might involve installing Company Portal and initiating enrollment
        logger.info("Starting Intune enrollment process")
        
        // For now, we'll just simulate success
        reply(nil)
    }
    
    func rotateFileVaultKey(withReply reply: @escaping (Error?) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        process.arguments = ["changerecovery", "-personal"]
        
        do {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                logger.info("Successfully rotated FileVault key")
                reply(nil)
            } else {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = HelperToolError.operationFailed("Failed to rotate FileVault key: \(output)")
                logger.error("Failed to rotate FileVault key: \(output)")
                reply(error)
            }
        } catch {
            logger.error("Error rotating FileVault key: \(error.localizedDescription)")
            reply(HelperToolError.operationFailed(error.localizedDescription))
        }
    }
    
    // MARK: - System Requirement Checks
    
    func checkJamfEnrollment(withReply reply: @escaping (Bool) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        process.arguments = ["-L"]
        
        do {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            let isEnrolled = output.contains("com.jamf.") || output.contains("com.jamfsoftware.")
            logger.info("Jamf enrollment status: \(isEnrolled)")
            reply(isEnrolled)
        } catch {
            logger.error("Error checking Jamf enrollment: \(error.localizedDescription)")
            reply(false)
        }
    }
    
    func checkFileVaultStatus(withReply reply: @escaping (Bool) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
        process.arguments = ["status"]
        
        do {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            let isEnabled = output.contains("FileVault is On")
            logger.info("FileVault status: \(isEnabled)")
            reply(isEnabled)
        } catch {
            logger.error("Error checking FileVault status: \(error.localizedDescription)")
            reply(false)
        }
    }
    
    func checkGatekeeperStatus(withReply reply: @escaping (Bool) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        process.arguments = ["--status"]
        
        do {
            let outputPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = outputPipe
            
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            
            let isEnabled = output.contains("assessments enabled")
            logger.info("Gatekeeper status: \(isEnabled)")
            reply(isEnabled)
        } catch {
            logger.error("Error checking Gatekeeper status: \(error.localizedDescription)")
            reply(false)
        }
    }
    
    // MARK: - Utility Methods
    
    func getVersionString(withReply reply: @escaping (String) -> Void) {
        reply(version)
    }
    
    func getCurrentUser(withReply reply: @escaping (String) -> Void) {
            let userName = NSUserName()
            reply(userName)
        }
    
    func checkToolVersion(version: String, withReply reply: @escaping (Bool) -> Void) {
        reply(version == self.version)
    }
}
