//
//  MigrationState.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import SwiftUI

/// Enum representing the overall state of migration
enum MigrationPhase: Equatable {
    case notStarted
    case checkingPrerequisites
    case prerequisitesFailed(String)
    case readyToMigrate
    case scheduled(Date)
    case inProgress(progress: Int)
    case completed
    case failed(Error)
    
    static func == (lhs: MigrationPhase, rhs: MigrationPhase) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
        case (.checkingPrerequisites, .checkingPrerequisites):
            return true
        case (.prerequisitesFailed(let lhsReason), .prerequisitesFailed(let rhsReason)):
            return lhsReason == rhsReason
        case (.readyToMigrate, .readyToMigrate):
            return true
        case (.scheduled(let lhsDate), .scheduled(let rhsDate)):
            return lhsDate == rhsDate
        case (.inProgress(let lhsProgress), .inProgress(let rhsProgress)):
            return lhsProgress == rhsProgress
        case (.completed, .completed):
            return true
        case (.failed(let lhsError), .failed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Represents the detailed state of prerequisites
struct PrerequisiteState: Equatable {
    var isJamfEnrolled: Bool = false
    var isMacOSCompatible: Bool = false
    var isFileVaultEnabled: Bool = false
    var isGatekeeperEnabled: Bool = false
    
    var allPrerequisitesMet: Bool {
        isJamfEnrolled &&
        isMacOSCompatible &&
        isFileVaultEnabled &&
        isGatekeeperEnabled
    }
    
    func getFailedPrerequisites() -> [String] {
        var failed: [String] = []
        
        if !isJamfEnrolled { failed.append("Device not enrolled in Jamf") }
        if !isMacOSCompatible { failed.append("macOS version not compatible") }
        if !isFileVaultEnabled { failed.append("FileVault not enabled") }
        if !isGatekeeperEnabled { failed.append("Gatekeeper not enabled") }
        
        return failed
    }
}

/// Represents a migration step with its status
struct MigrationStep: Identifiable, Equatable {
    let id: String
    var name: String
    var description: String
    var status: StepStatus
    var progress: Double
    var isBlocker: Bool
    
    enum StepStatus: Equatable {
        case notStarted
        case inProgress
        case completed
        case failed(String)
        
        var description: String {
            switch self {
            case .notStarted: return "Not Started"
            case .inProgress: return "In Progress"
            case .completed: return "Completed"
            case .failed(let reason): return "Failed: \(reason)"
            }
        }
    }
}

@MainActor
class MigrationState: ObservableObject {
    @Published private(set) var phase: MigrationPhase = .notStarted
    @Published private(set) var prerequisites = PrerequisiteState()
    @Published private(set) var steps: [MigrationStep] = []
    @Published private(set) var currentStepIndex: Int = 0
    @Published var selectedDeferralMinutes: Int?
    
    private let logger = Logger.shared
    
    init() {
        setupMigrationSteps()
    }
    
    func updateStepStatus(id: String, status: MigrationStep.StepStatus) {
            if let index = steps.firstIndex(where: { $0.id == id }) {
                steps[index].status = status
                if status == .completed && index < steps.count - 1 {
                    currentStepIndex = index + 1
                }
            }
        }
    private func setupMigrationSteps() {
            steps = [
                MigrationStep(
                    id: "prerequisites",
                    name: "Check Prerequisites",
                    description: "Verifying system requirements",
                    status: .notStarted,
                    progress: 0,
                    isBlocker: true
                ),
                MigrationStep(
                    id: "removeMDM",
                    name: "Remove Jamf MDM",
                    description: "Removing Jamf management profile",
                    status: .notStarted,
                    progress: 0,
                    isBlocker: true
                ),
                MigrationStep(
                    id: "removeFramework",
                    name: "Remove Framework",
                    description: "Removing Jamf framework",
                    status: .notStarted,
                    progress: 0,
                    isBlocker: true
                ),
                MigrationStep(
                    id: "intuneEnrollment",
                    name: "Intune Enrollment",
                    description: "Starting Intune enrollment",
                    status: .notStarted,
                    progress: 0,
                    isBlocker: true
                ),
                MigrationStep(
                    id: "fileVault",
                    name: "FileVault Key",
                    description: "Rotating FileVault recovery key",
                    status: .notStarted,
                    progress: 0,
                    isBlocker: false
                ),
                MigrationStep(
                    id: "completion",
                    name: "Complete Migration",
                    description: "Finalizing migration process",
                    status: .notStarted,
                    progress: 0,
                    isBlocker: false
                )
            ]
        }
    
    func updateProgress(progress: Int, stepDescription: String) {
        logger.info("Updating progress: \(stepDescription) - \(progress)%")
        phase = .inProgress(progress: progress)
        
        // Update current step
        if currentStepIndex < steps.count {
            steps[currentStepIndex].progress = Double(progress)
            steps[currentStepIndex].status = .inProgress
            
            // Mark step as completed if 100%
            if progress == 100 {
                steps[currentStepIndex].status = .completed
                if currentStepIndex < steps.count - 1 {
                    currentStepIndex += 1
                }
            }
        }
    }
    
    func updatePrerequisites(
        isJamfEnrolled: Bool? = nil,
        isMacOSCompatible: Bool? = nil,
        isFileVaultEnabled: Bool? = nil,
        isGatekeeperEnabled: Bool? = nil
    ) {
        if let isJamfEnrolled = isJamfEnrolled {
            prerequisites.isJamfEnrolled = isJamfEnrolled
        }
        if let isMacOSCompatible = isMacOSCompatible {
            prerequisites.isMacOSCompatible = isMacOSCompatible
        }
        if let isFileVaultEnabled = isFileVaultEnabled {
            prerequisites.isFileVaultEnabled = isFileVaultEnabled
        }
        if let isGatekeeperEnabled = isGatekeeperEnabled {
            prerequisites.isGatekeeperEnabled = isGatekeeperEnabled
        }
        
        logger.info("Prerequisites updated: \(prerequisites)")
        
        if prerequisites.allPrerequisitesMet {
            phase = .readyToMigrate
        } else {
            let failedItems = prerequisites.getFailedPrerequisites().joined(separator: ", ")
            phase = .prerequisitesFailed(failedItems)
        }
    }
    
    private func calculateOverallProgress() -> Int {
        let completedSteps = steps.filter { $0.status == .completed }.count
        let totalSteps = steps.count
        return Int((Double(completedSteps) / Double(totalSteps)) * 100)
    }
    
    var currentStep: MigrationStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }
    
    var isInProgress: Bool {
        if case .inProgress = phase { return true }
        return false
    }
    
    var canProceed: Bool {
        prerequisites.allPrerequisitesMet && !isInProgress
    }
    
    func reset() {
        phase = .notStarted
        prerequisites = PrerequisiteState()
        currentStepIndex = 0
        selectedDeferralMinutes = nil
        setupMigrationSteps()
        logger.info("Migration state reset")
    }
}
