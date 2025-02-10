//
//  MigrationProgressView.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]


import SwiftUI

struct MigrationProgressView: View {
    @ObservedObject var migrationService = MigrationService.shared
    @Environment(\.dismiss) private var dismiss
    
    private let logger = Logger.shared
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .padding(.top, 20)
            
            Text("Migration in Progress")
                .font(.system(size: 24, weight: .medium))
            
            // Progress Section
            VStack(alignment: .leading, spacing: 15) {
                Text(migrationService.currentStepDescription)
                    .font(.system(size: 16, weight: .regular))
                
                // Progress Bar
                ProgressView(value: Double(progressValue), total: 100)
                    .progressViewStyle(LinearProgressViewStyle())
                    .frame(height: 6)
                    .animation(.easeInOut, value: progressValue)
                
                Text("In Progress (\(progressValue)%)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Steps List
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(migrationService.migrationState.steps) { step in
                        StepRow(
                            step: step,
                            isCompleted: isStepCompleted(step),
                            isCurrent: isCurrentStep(step)
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
            
            // Warning or Success Message
            if case .completed = migrationService.currentStatus {
                Text("Migration completed successfully! Please restart your Mac.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.green)
                    .padding(.bottom, 20)
                
                Button("Restart Now") {
                    restartMac()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Text("Please do not restart your Mac during the migration process")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
            }
        }
        .padding()
        .frame(width: 600, height: 500)
    }
    
    private var progressValue: Int {
        if case .inProgress(let progress) = migrationService.currentStatus {
            return progress
        } else if case .completed = migrationService.currentStatus {
            return 100
        }
        return 0
    }
    
    private func isStepCompleted(_ step: MigrationStep) -> Bool {
        if case .completed = migrationService.currentStatus {
            return true
        }
        return step.status == .completed
    }
    
    private func isCurrentStep(_ step: MigrationStep) -> Bool {
        step.id == migrationService.migrationState.currentStep?.id
    }
    
    private func restartMac() {
        let script = """
        do shell script "shutdown -r now" with administrator privileges
        """
        
        var error: NSDictionary?
        if NSAppleScript(source: script)?.executeAndReturnError(&error) == nil {
            logger.error("Failed to initiate restart: \(error?.description ?? "Unknown error")")
        }
    }
}

// MARK: - Step Row View
struct StepRow: View {
    let step: MigrationStep
    let isCompleted: Bool
    let isCurrent: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // Status Icon
            Circle()
                .fill(statusColor)
                .frame(width: 20, height: 20)
                .overlay {
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else if isCurrent {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(.white)
                    }
                }
            
            // Step Info
            VStack(alignment: .leading, spacing: 4) {
                Text(step.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isCurrent || isCompleted ? .primary : .secondary)
                Text(step.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .opacity(isCompleted || isCurrent ? 1.0 : 0.6)
    }
    
    private var statusColor: Color {
        if isCompleted {
            return .green
        } else if isCurrent {
            return .blue
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    MigrationProgressView()
}
