//
//  PreRequisitesView.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import SwiftUI
import Foundation

struct PreRequisitesView: View {
    @StateObject private var migrationService = MigrationService.shared
    @State private var navigateToMigration = false
    @State private var checkingInProgress = false
    @State private var debugMessage: String = ""
    @State private var showDebugAlert = false
    
    private let privilegedService = PrivilegedService.shared
    private let systemRequirements = SystemRequirements()
    private let logger = Logger.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Header
                Text("System Requirements")
                    .font(.largeTitle)
                    .padding(.top, 30)
                
                // Description
                Text("Checking your Mac's compatibility for migration")
                    .foregroundColor(.secondary)
                
                // Requirements List
                VStack(alignment: .leading, spacing: 20) {
                    RequirementRow(
                        title: "Jamf Enrollment",
                        description: "Checking current MDM enrollment",
                        isChecked: migrationService.migrationState.prerequisites.isJamfEnrolled
                    )
                    
                    RequirementRow(
                        title: "macOS Version",
                        description: "Checking system compatibility",
                        isChecked: migrationService.migrationState.prerequisites.isMacOSCompatible
                    )
                    
                    RequirementRow(
                        title: "FileVault",
                        description: "Checking disk encryption status",
                        isChecked: migrationService.migrationState.prerequisites.isFileVaultEnabled
                    )
                    
                    RequirementRow(
                        title: "Security Settings",
                        description: "Checking system security",
                        isChecked: migrationService.migrationState.prerequisites.isGatekeeperEnabled
                    )
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                #if DEBUG
                // Debug Section
                VStack(spacing: 16) {
                    Text("Debug Options")
                        .font(.headline)
                    
                    HStack(spacing: 15) {
                        Button("Test Privileges") {
                            Task {
                                await testPrivileges()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        
                        Button("Check User") {
                            Task {
                                await checkCurrentUser()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        
                        Button("Print Logs") {
                            printDebugLogs()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.gray)
                    }
                    
                    if !debugMessage.isEmpty {
                        Text(debugMessage)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                #endif
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await performRequirementChecks()
                        }
                    } label: {
                        HStack {
                            if checkingInProgress {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            }
                            Text("Check Requirements")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .disabled(checkingInProgress)
                    
                    Button {
                        Task {
                            await startMigration()
                        }
                    } label: {
                        Text("Start Migration")
                            .frame(maxWidth: .infinity)
                            .frame(height: 45)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(!migrationService.migrationState.prerequisites.allPrerequisitesMet || checkingInProgress)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 30)
            }
            .padding(30)
            .frame(width: 700, height: 600)
            .onAppear {
                Task {
                    await performRequirementChecks()
                }
            }
            .navigationDestination(isPresented: $navigateToMigration) {
                MigrationProgressView()
            }
            .alert("Debug Info", isPresented: $showDebugAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(debugMessage)
            }
        }
    }
    
    // MARK: - Supporting Views
    struct RequirementRow: View {
        let title: String
        let description: String
        let isChecked: Bool
        
        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isChecked ? .green : .red)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
    }
    
    private func performRequirementChecks() async {
            logger.info("Starting system requirement checks")
            checkingInProgress = true
            
            do {
                // Get system status
                let status = await systemRequirements.performAllChecks()
                
                // Update migration state
                await MainActor.run {
                    migrationService.migrationState.updatePrerequisites(
                        isJamfEnrolled: status.isJamfEnrolled,
                        isMacOSCompatible: status.isMacOSCompatible,
                        isFileVaultEnabled: status.isFileVaultEnabled,
                        isGatekeeperEnabled: status.isGatekeeperEnabled
                    )
                }
            } catch {
                logger.error("Requirement checks failed: \(error.localizedDescription)")
            }
            
            checkingInProgress = false
        }
        
        private func startMigration() async {
            logger.info("Starting migration process")
            
            do {
                // Navigate to progress view first
                await MainActor.run {
                    navigateToMigration = true
                }
                
                // Then start the migration
                try await Task.sleep(nanoseconds: 1_000_000_000) // Small delay to ensure view transition
                try await migrationService.startMigration()
            } catch {
                logger.error("Failed to start migration: \(error.localizedDescription)")
            }
        }
        
        // MARK: - Debug Methods
        #if DEBUG
        private func testPrivileges() async {
            do {
                let isRoot = try await privilegedService.testPrivileges()
                debugMessage = "Root privileges: \(isRoot)\nUser ID: \(getuid())"
                logger.info("Root privileges test: \(isRoot)")
                showDebugAlert = true
            } catch {
                debugMessage = "Error: \(error.localizedDescription)"
                logger.error("Privilege test failed: \(error.localizedDescription)")
                showDebugAlert = true
            }
        }
        
        private func checkCurrentUser() async {
            do {
                let currentUser = try await privilegedService.getCurrentUser()
                debugMessage = "Current user: \(currentUser)"
                logger.info("Current user: \(currentUser)")
                showDebugAlert = true
            } catch {
                debugMessage = "Error: \(error.localizedDescription)"
                logger.error("User check failed: \(error.localizedDescription)")
                showDebugAlert = true
            }
        }
        
        private func printDebugLogs() {
            logger.info("=== Debug Information ===")
            logger.info("Root status: \(getuid() == 0 ? "Running as root" : "Not root")")
            logger.info("User ID: \(getuid())")
            logger.info("Prerequisites met: \(migrationService.migrationState.prerequisites.allPrerequisitesMet)")
            logger.info("Current phase: \(migrationService.currentStatus)")
            debugMessage = "Debug logs printed to console"
            showDebugAlert = true
        }
        #endif
    }

#Preview {
    PreRequisitesView()
}

