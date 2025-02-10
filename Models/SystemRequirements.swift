//
//  SystemRequirements.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import AppKit

struct SystemRequirements {
    private let logger = Logger.shared

    let minimumOSVersion: String = "14.0"
    let requiredDiskSpace: Int64 = 10 * 1024 * 1024 * 1024  // 10 GB
    let requiredMemory: Int64 = 4 * 1024 * 1024 * 1024      // 4 GB

    struct ValidationResult {
        var isValid: Bool
        var message: String
    }

    struct SystemStatus {
        var isJamfEnrolled: Bool
        var isMacOSCompatible: Bool
        var isFileVaultEnabled: Bool
        var isGatekeeperEnabled: Bool
        var hasSufficientDiskSpace: Bool
        var hasSufficientMemory: Bool
        var isAppRunningAsRoot: Bool
        var hasInternetConnection: Bool
        var companyPortalInstalled: Bool
        
        var allRequirementsMet: Bool {
            return isJamfEnrolled &&
                   isMacOSCompatible &&
                   isFileVaultEnabled &&
                   isGatekeeperEnabled &&
                   hasSufficientDiskSpace &&
                   hasSufficientMemory &&
                   isAppRunningAsRoot &&
                   hasInternetConnection
        }
        
        var failedRequirements: [String] {
            var failures: [String] = []
            
            if !isJamfEnrolled { failures.append("Device not enrolled in Jamf") }
            if !isMacOSCompatible { failures.append("macOS version not compatible") }
            if !isFileVaultEnabled { failures.append("FileVault not enabled") }
            if !isGatekeeperEnabled { failures.append("Gatekeeper not enabled") }
            if !hasSufficientDiskSpace { failures.append("Insufficient disk space") }
            if !hasSufficientMemory { failures.append("Insufficient memory") }
            if !isAppRunningAsRoot { failures.append("App not running as root") }
            if !hasInternetConnection { failures.append("No internet connection") }
            
            return failures
        }
    }

    func performAllChecks() async -> SystemStatus {
        var status = SystemStatus(
            isJamfEnrolled: await checkJamfEnrollment(),
            isMacOSCompatible: validateMacOSVersion().isValid,
            isFileVaultEnabled: await checkFileVaultStatus(),
            isGatekeeperEnabled: await checkGatekeeperStatus(),
            hasSufficientDiskSpace: validateDiskSpace().isValid,
            hasSufficientMemory: validateMemory().isValid,
            isAppRunningAsRoot: validateRootPrivileges().isValid,
            hasInternetConnection: validateInternetConnection().isValid,
            companyPortalInstalled: false // Implement check if necessary
        )
        
        logSystemStatus(status)
        return status
    }
    
    private func checkJamfEnrollment() async -> Bool {
        let script = """
        do shell script "/usr/bin/profiles -L" with administrator privileges
        """
        
        var error: NSDictionary?
        if let result = NSAppleScript(source: script)?.executeAndReturnError(&error),
           let profilesList = result.stringValue {
            
            logger.info("=== Profiles List Start ===")
            logger.info(profilesList)
            logger.info("=== Profiles List End ===")
            
            let profiles = profilesList.components(separatedBy: .newlines)
            for profile in profiles {
                let lowercasedProfile = profile.lowercased()
                if lowercasedProfile.contains("com.jamf.") ||
                   lowercasedProfile.contains("com.jamfsoftware.") {
                    logger.info("Jamf enrollment detected")
                    return true
                }
            }
            
            logger.warning("No Jamf profiles found")
            
        } else {
            let errorDesc = error?.description ?? "Unknown error"
            logger.error("Failed to list profiles: \(errorDesc)")
        }
        
        return false
    }

    private func checkFileVaultStatus() async -> Bool {
        do {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
            process.arguments = ["status"]
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                logger.info("FileVault status output: \(output)")
                return output.contains("FileVault is On")
            }
        } catch {
            logger.error("Failed to check FileVault status: \(error)")
        }
        return false
    }
    
    private func checkGatekeeperStatus() async -> Bool {
        do {
            let process = Process()
            let pipe = Pipe()
            
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
            process.arguments = ["--status"]
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                logger.info("Gatekeeper status output: \(output)")
                return output.contains("assessments enabled")
            }
        } catch {
            logger.error("Failed to check Gatekeeper status: \(error)")
        }
        return false
    }
    
    func validateMacOSVersion() -> ValidationResult {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isCompatible = (osVersion.majorVersion >= 14)
        
        logger.info("macOS version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
        return ValidationResult(
            isValid: isCompatible,
            message: isCompatible ? "macOS version compatible" : "Requires macOS 14 or later"
        )
    }
    
    func validateDiskSpace() -> ValidationResult {
        do {
            let fileURL = URL(fileURLWithPath: "/")
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            
            if let availableSpace = values.volumeAvailableCapacityForImportantUsage {
                let hasSpace = availableSpace >= requiredDiskSpace
                logger.info("Available disk space: \(availableSpace / 1024 / 1024 / 1024) GB")
                return ValidationResult(
                    isValid: hasSpace,
                    message: hasSpace ? "Sufficient disk space available" : "Requires at least 10GB of free space"
                )
            }
        } catch {
            logger.error("Failed to check disk space: \(error)")
        }
        
        return ValidationResult(isValid: false, message: "Unable to verify available disk space")
    }
    
    func validateMemory() -> ValidationResult {
        let processInfo = ProcessInfo.processInfo
        let physicalMemory = processInfo.physicalMemory
        
        let hasEnoughMemory = physicalMemory >= requiredMemory
        logger.info("Available memory: \(physicalMemory / 1024 / 1024 / 1024) GB")
        return ValidationResult(
            isValid: hasEnoughMemory,
            message: hasEnoughMemory ? "Sufficient memory available" : "Requires at least 4GB of RAM"
        )
    }
    
    func validateInternetConnection() -> ValidationResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", "8.8.8.8"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let hasConnection = process.terminationStatus == 0
            logger.info("Internet connection status: \(hasConnection)")
            return ValidationResult(
                isValid: hasConnection,
                message: hasConnection ? "Internet connection available" : "No internet connection"
            )
        } catch {
            logger.error("Failed to check internet connection: \(error)")
            return ValidationResult(isValid: false, message: "Unable to verify internet connection")
        }
    }
    
    func validateRootPrivileges() -> ValidationResult {
        #if DEBUG
        return ValidationResult(
            isValid: true,
            message: "Running in debug mode - root check bypassed"
        )
        #else
        let isRoot = getuid() == 0
        logger.info("Root privileges status: \(isRoot)")
        return ValidationResult(
            isValid: isRoot,
            message: isRoot ? "Running with root privileges" : "Not running as root"
        )
        #endif
    }
    
    private func logSystemStatus(_ status: SystemStatus) {
        logger.info("""
        System Status Check Results:
        - Jamf Enrolled: \(status.isJamfEnrolled)
        - FileVault Enabled: \(status.isFileVaultEnabled)
        - macOS Compatible: \(status.isMacOSCompatible)
        - Gatekeeper Enabled: \(status.isGatekeeperEnabled)
        - Disk Space Sufficient: \(status.hasSufficientDiskSpace)
        - Memory Sufficient: \(status.hasSufficientMemory)
        - Running as Root: \(status.isAppRunningAsRoot)
        - Internet Connected: \(status.hasInternetConnection)
        - All Requirements Met: \(status.allRequirementsMet)
        """)
        
        if !status.allRequirementsMet {
            logger.warning("Failed Requirements: \(status.failedRequirements.joined(separator: ", "))")
        }
    }
}
