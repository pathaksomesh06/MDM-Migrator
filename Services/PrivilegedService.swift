//
//  PrivilegedService.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import AppKit

enum PrivilegedServiceError: Error {
    case scriptExecutionFailed(String)
    case commandFailed(String)
    case invalidResponse
    case notRunningAsRoot
    case privilegeElevationFailed
}

final class PrivilegedService {
    static let shared = PrivilegedService()
    private let logger = Logger.shared
    private let companyPortalURL = "https://officecdn.microsoft.com/pr/C1297A47-86C4-4C1F-97FA-950631F94777/MacAutoupdate/CompanyPortal-Installer.pkg"
    
    var isRunningAsRoot: Bool {
        return getuid() == 0
    }
    
    private var isDebugBuild: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    private init() {
        Task {
            await verifyPrivileges()
        }
    }
    
    private func verifyPrivileges() async {
        if !isRunningAsRoot {
            logger.info("Starting privilege verification...")
            
            // In debug, allow time for authentication
            #if DEBUG
                do {
                    if try await requestPrivileges() {
                        logger.info("Successfully obtained privileges in debug mode")
                        return
                    }
                } catch {
                    logger.error("Failed to obtain privileges in debug mode: \(error.localizedDescription)")
                }
            #else
                // In production, check if we're root
                if !isRunningAsRoot {
                    logger.error("Not running as root in production mode")
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                    return
                }
            #endif
            
            logger.error("Failed to obtain required privileges")
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        } else {
            logger.info("✅ Already running with root privileges")
        }
    }
    
    func executeCommand(_ command: String, requireRoot: Bool = true, useAdmin: Bool = false) async throws -> String {
        // Check for root requirement in production
        if requireRoot && !isRunningAsRoot && !isDebugBuild {
            logger.error("Root privileges required but not available")
            throw PrivilegedServiceError.notRunningAsRoot
        }
        
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Determine execution mode
        if isDebugBuild && !isRunningAsRoot && requireRoot {
            // In debug mode, use sudo or admin privileges
            if useAdmin {
                let script = """
                osascript -e 'do shell script "\(command.replacingOccurrences(of: "\"", with: "\\\""))" with administrator privileges'
                """
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", script]
            } else {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
                process.arguments = ["-S", "/bin/bash", "-c", command]
            }
        } else {
            // Direct execution
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = ["-c", command]
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                logger.error("Command failed: \(error)")
                throw PrivilegedServiceError.commandFailed(error)
            }
            
            if !error.isEmpty {
                logger.warning("Command output to stderr: \(error)")
            }
            
            return output
            
        } catch let error as PrivilegedServiceError {
            throw error
        } catch {
            logger.error("Command execution failed: \(error.localizedDescription)")
            throw PrivilegedServiceError.scriptExecutionFailed(error.localizedDescription)
        }
    }
    
    func requestPrivileges() async throws -> Bool {
        if isRunningAsRoot {
            return true
        }
        
        #if DEBUG
        // In debug mode, show authentication dialog
        do {
            let authenticated = try await showAuthenticationDialog()
            if authenticated {
                // Test privileges after authentication
                let result = try await executeCommand("echo 'privilege test'", requireRoot: true)
                return !result.isEmpty
            }
            return false
        } catch {
            logger.error("Failed to get privileges: \(error.localizedDescription)")
            return false
        }
        #else
        // In production, we should already be root
        return isRunningAsRoot
        #endif
    }
    
    private func showAuthenticationDialog() async throws -> Bool {
            let script = """
                do shell script "echo 'Authentication successful'" with administrator privileges with prompt "MDM Migrator requires administrator privileges to perform the migration."
            """
            
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script),
               appleScript.executeAndReturnError(&error) != nil {
                return true
            } else if let error = error {
                logger.error("Authentication failed: \(error)")
                throw PrivilegedServiceError.privilegeElevationFailed
            }
            return false
        }
    
    func testPrivileges() async throws -> Bool {
        do {
            let whoami = try await executeCommand("whoami", requireRoot: false)
            let currentUser = whoami.trimmingCharacters(in: .whitespacesAndNewlines)
            logger.info("Running as user: \(currentUser)")
            return currentUser == "root"
        } catch {
            logger.error("Privilege test failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func getCurrentUser() async throws -> String {
        let output = try await executeCommand("whoami", requireRoot: false)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func removeJamfManagement() async throws {
        logger.info("Starting Jamf MDM profile removal")
        
        // First check if Jamf is installed
        let checkScript = """
        profiles list
        """
        
        let output = try await executeCommand(checkScript, requireRoot: true)
        if !output.contains("Jamf") {
            logger.info("No Jamf profile found, skipping removal")
            return
        }
        
        // Remove MDM profile
        try await executeCommand("profiles remove -all", requireRoot: true)
        
        // Wait for profile removal to complete
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Verify profile removal
        let verifyOutput = try await executeCommand(checkScript, requireRoot: true)
        if verifyOutput.contains("Jamf") {
            logger.error("Jamf profile still present after removal")
            throw PrivilegedServiceError.commandFailed("Jamf profile still present after removal attempt")
        }
        
        logger.info("Jamf MDM profile successfully removed")
    }
    
    func removeJamfFramework() async throws {
        logger.info("Starting Jamf framework removal")
        
        // First check if Jamf binary exists
        let exists = try await executeCommand("test -f /usr/local/jamf/bin/jamf && echo 'exists' || echo 'not found'", requireRoot: true)
        if exists.contains("not found") {
            logger.info("Jamf framework not found, skipping removal")
            return
        }
        
        // Remove framework
        try await executeCommand("/usr/local/jamf/bin/jamf removeFramework", requireRoot: true)
        
        // Wait for framework removal
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Verify removal
        let verifyExists = try await executeCommand("test -f /usr/local/jamf/bin/jamf && echo 'exists' || echo 'not found'", requireRoot: true)
        if verifyExists.contains("exists") {
            logger.error("Jamf framework still present after removal")
            throw PrivilegedServiceError.commandFailed("Jamf framework still present after removal attempt")
        }
        
        logger.info("Jamf framework successfully removed")
    }
    
    func installCompanyPortal() async throws {
        logger.info("Checking Company Portal installation")
        
        // Check if already installed
        let exists = try await executeCommand("test -d '/Applications/Company Portal.app' && echo 'yes' || echo 'no'", requireRoot: false)
        if exists.contains("yes") {
            logger.info("Company Portal is already installed")
            return
        }
        
        logger.info("Downloading and installing Company Portal")
        
        // Download and install
        let installCommand = """
        curl -L '\(companyPortalURL)' -o /private/tmp/CompanyPortal.pkg && \
        installer -pkg /private/tmp/CompanyPortal.pkg -target / && \
        rm /private/tmp/CompanyPortal.pkg
        """
        
        try await executeCommand(installCommand, requireRoot: true)
        
        // Verify installation
        let verifyInstall = try await executeCommand("test -d '/Applications/Company Portal.app' && echo 'yes' || echo 'no'", requireRoot: false)
        if !verifyInstall.contains("yes") {
            logger.error("Company Portal installation verification failed")
            throw PrivilegedServiceError.commandFailed("Company Portal installation verification failed")
        }
        
        logger.info("Company Portal successfully installed")
    }
    
    func rotateFileVaultKey() async throws {
        logger.info("Starting FileVault key rotation")
        
        guard let scriptURL = Bundle.main.url(forResource: "reissueKey", withExtension: "sh") else {
            throw PrivilegedServiceError.scriptExecutionFailed("FileVault rotation script not found")
        }
        
        let tempScriptPath = "/private/tmp/reissueKey.sh"
        try FileManager.default.copyItem(at: scriptURL, to: URL(fileURLWithPath: tempScriptPath))
        
        // Set permissions
        try await executeCommand("chmod +x '\(tempScriptPath)'", requireRoot: true)
        
        // Execute script and capture output
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", tempScriptPath]
        
        // Set environment to allow GUI interaction
        var environment = ProcessInfo.processInfo.environment
        environment["DISPLAY"] = ":0"
        process.environment = environment
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let error = String(data: errorData, encoding: .utf8) ?? ""
            
            // Check output for success indication
            if process.terminationStatus != 0 || error.contains("error") {
                logger.error("FileVault key rotation failed: \(error)")
                throw PrivilegedServiceError.commandFailed(error)
            }
            
            // Look for successful completion message
            if output.contains("FileVault key rotation completed successfully") {
                logger.info("FileVault key rotation completed")
            } else {
                logger.error("FileVault key rotation completion message not found")
                throw PrivilegedServiceError.commandFailed("FileVault key rotation completion not verified")
            }
        } catch {
            logger.error("Failed to execute FileVault rotation script: \(error.localizedDescription)")
            throw PrivilegedServiceError.scriptExecutionFailed(error.localizedDescription)
        }
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: tempScriptPath)
    }
    
    func enrollInIntune() async throws {
        logger.info("Starting Intune enrollment")
        
        // Execute enrollment
        try await executeCommand("profiles -N", requireRoot: true)
        
        // Wait for enrollment
        var enrolled = false
        var retryCount = 0
        let maxRetries = 60 // 1 minute total
        
        while !enrolled && retryCount < maxRetries {
            let profilesOutput = try await executeCommand("profiles show -all", requireRoot: true)
            if profilesOutput.contains("Microsoft.Profiles.") || profilesOutput.contains("Microsoft.Profiles.MDM") {
                enrolled = true
                break
            }
            
            retryCount += 1
            try await Task.sleep(nanoseconds: 5_000_000_000)
        }
        
        if !enrolled {
            throw PrivilegedServiceError.commandFailed("Intune enrollment did not complete within expected time")
        }
        
        logger.info("Intune enrollment completed successfully")
    }
}
