//
//  MigrationService.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import SwiftUI

@MainActor
final class MigrationService: ObservableObject {
    static let shared = MigrationService()
    
    private let helperToolManager = HelperToolServiceManager.shared
    private let notificationService = NotificationService.shared
    private let logger = Logger.shared
    
    @Published private(set) var currentStatus: MigrationStatus = .notStarted
    @Published private(set) var migrationState = MigrationState()
    @Published private(set) var currentStepDescription: String = ""
    
    private init() {}
    
    // MARK: - Main Migration Methods
    
    func startMigration() async throws {
        logger.info("Starting migration process")
        currentStatus = .inProgress(progress: 0)
        
        do {
            // Check prerequisites
            try await checkPrerequisites()
            
            // Perform migration steps
            try await performMigrationSteps()
            
            // Complete migration
            await completeMigration()
            
        } catch {
            await handleMigrationError(error)
            throw error
        }
    }
    
    func checkPrerequisites() async throws {
        logger.info("Checking prerequisites")
        updateProgress(step: "Checking system requirements", progress: 10)
        
        // First, ensure helper tool is installed
        if !helperToolManager.isHelperToolInstalled {
            logger.info("Installing helper tool")
            try await helperToolManager.installHelperTool()
        }
        
        // Use helper tool to check requirements
        let jamfEnrolled = try await helperToolManager.checkJamfEnrollment()
        let fileVaultEnabled = try await helperToolManager.checkFileVaultStatus()
        let gatekeeperEnabled = try await helperToolManager.checkGatekeeperStatus()
        
        // Update migration state
        migrationState.updatePrerequisites(
            isJamfEnrolled: jamfEnrolled,
            isMacOSCompatible: true, // This is checked at app launch
            isFileVaultEnabled: fileVaultEnabled,
            isGatekeeperEnabled: gatekeeperEnabled
        )
        
        guard migrationState.prerequisites.allPrerequisitesMet else {
            let failures = migrationState.prerequisites.getFailedPrerequisites().joined(separator: ", ")
            logger.error("Prerequisites check failed: \(failures)")
            throw MigrationError.prerequisitesFailed(failures)
        }
        
        logger.info("Prerequisites check passed")
        updateProgress(step: "Prerequisites check completed", progress: 20)
    }
    
    // MARK: - Private Methods
    
    private func performMigrationSteps() async throws {
        // Step 1: Check Prerequisites
        updateProgress(step: "prerequisites", description: "Verifying system requirements", progress: 10)
        try await checkPrerequisites()
        migrationState.updateStepStatus(id: "prerequisites", status: .completed)
        
        // Step 2: Remove MDM Profile
        updateProgress(step: "removeMDM", description: "Removing Jamf management profile", progress: 30)
        try await helperToolManager.removeJamfManagement()
        migrationState.updateStepStatus(id: "removeMDM", status: .completed)
        
        // Step 3: Remove Framework
        updateProgress(step: "removeFramework", description: "Removing Jamf framework", progress: 50)
        try await helperToolManager.removeJamfFramework()
        migrationState.updateStepStatus(id: "removeFramework", status: .completed)
        
        // Step 4: Start Intune Enrollment
        updateProgress(step: "intuneEnrollment", description: "Starting Intune enrollment", progress: 70)
        try await helperToolManager.enrollInIntune()
        migrationState.updateStepStatus(id: "intuneEnrollment", status: .completed)
        
        // Step 5: Rotate FileVault Key
        updateProgress(step: "fileVault", description: "Rotating FileVault key", progress: 90)
        try await helperToolManager.rotateFileVaultKey()
        migrationState.updateStepStatus(id: "fileVault", status: .completed)
        
        // Final Step: Complete
        updateProgress(step: "completion", description: "Finalizing migration", progress: 100)
        migrationState.updateStepStatus(id: "completion", status: .completed)
    }
    
    private func updateProgress(step: String, description: String, progress: Int) {
        currentStatus = .inProgress(progress: progress)
        currentStepDescription = description
        
        // Update step status in MigrationState
        migrationState.updateStepStatus(id: step, status: .inProgress)
        migrationState.updateProgress(progress: progress, stepDescription: description)
    }
    
    private func completeMigration() async {
        updateProgress(step: "Migration completed successfully", progress: 100)
        currentStatus = .completed
        logger.info("Migration completed successfully")
        
        do {
            try await notificationService.showMigrationCompleteNotification(success: true)
            await showCompletionAlert()
        } catch {
            logger.error("Failed to show completion notification: \(error.localizedDescription)")
        }
    }
    
    private func handleMigrationError(_ error: Error) async {
        currentStatus = .failed(error)
        logger.error("Migration failed: \(error.localizedDescription)")
        
        do {
            try await notificationService.showMigrationCompleteNotification(success: false)
        } catch {
            logger.error("Failed to show error notification: \(error.localizedDescription)")
        }
    }
    
    private func updateProgress(step: String, progress: Int) {
        currentStatus = .inProgress(progress: progress)
        currentStepDescription = step
        logger.info("\(step): \(progress)%")
        
        // Update migration state
        migrationState.updateProgress(progress: progress, stepDescription: step)
    }
    
    private func showCompletionAlert() async {
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "Migration Complete"
            alert.informativeText = """
            The migration to Microsoft Intune has been completed successfully.
            
            Next Steps:
            1. Restart your Mac to apply all changes
            2. After restart, launch Company Portal
            3. Sign in with your work account to complete the setup
            
            Would you like to restart now?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Restart Now")
            alert.addButton(withTitle: "Restart Later")
            
            if alert.runModal() == .alertFirstButtonReturn {
                // User chose to restart
                let restartScript = """
                do shell script "shutdown -r now" with administrator privileges
                """
                
                var error: NSDictionary?
                if NSAppleScript(source: restartScript)?.executeAndReturnError(&error) == nil {
                    self.logger.error("Failed to initiate restart")
                }
            }
        }
    }
}
