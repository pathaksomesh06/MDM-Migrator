//
//  MigrationTypes.swift
//  MDMMigratorHelper
//
//  Created by Somesh Pathak on 22/01/2025.
//  Copyright (c) 2025 [Somesh Pathak]



import Foundation

// MARK: - Migration Status
enum MigrationStatus: Equatable {
    case notStarted
    case inProgress(progress: Int)
    case completed
    case failed(Error)
    
    static func == (lhs: MigrationStatus, rhs: MigrationStatus) -> Bool {
        switch (lhs, rhs) {
        case (.notStarted, .notStarted):
            return true
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
    
    var description: String {
        switch self {
        case .notStarted:
            return "Not Started"
        case .inProgress(let progress):
            return "In Progress (\(progress)%)"
        case .completed:
            return "Completed"
        case .failed(let error):
            return "Failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Migration Errors
enum MigrationError: LocalizedError {
    case prerequisitesFailed(String)
    case jamfRemovalFailed(String)
    case companyPortalInstallFailed(String)
    case configurationFailed(String)
    case helperToolError(String)
    case authorizationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .prerequisitesFailed(let reason):
            return "Prerequisites not met: \(reason)"
        case .jamfRemovalFailed(let reason):
            return "Failed to remove Jamf: \(reason)"
        case .companyPortalInstallFailed(let reason):
            return "Failed to install Company Portal: \(reason)"
        case .configurationFailed(let reason):
            return "Failed to configure settings: \(reason)"
        case .helperToolError(let reason):
            return "Helper tool error: \(reason)"
        case .authorizationFailed(let reason):
            return "Authorization failed: \(reason)"
        }
    }
}

// MARK: - Helper Tool Errors
enum HelperToolError: LocalizedError {
    case operationFailed(String)
    case invalidResponse
    case unauthorized
    case installationFailed(String)
    case communicationError(String)
    
    var errorDescription: String? {
        switch self {
        case .operationFailed(let reason):
            return "Operation failed: \(reason)"
        case .invalidResponse:
            return "Invalid response from helper tool"
        case .unauthorized:
            return "Unauthorized to perform operation"
        case .installationFailed(let reason):
            return "Helper tool installation failed: \(reason)"
        case .communicationError(let reason):
            return "Communication error: \(reason)"
        }
    }
}
