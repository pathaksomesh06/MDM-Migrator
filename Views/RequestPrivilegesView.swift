//
//  RequestPrivilegesView.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import SwiftUI

struct RequestPrivilegesView: View {
    @ObservedObject var appState: AppState
    @State private var isInstalling = false
    @State private var showSettingsPrompt = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Setup Required")
                .font(.title)
                .multilineTextAlignment(.center)
            
            Text("This application needs to install a helper tool to perform the migration from Jamf to Microsoft Intune.")
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("This will enable:")
                    .font(.headline)
                    .padding(.bottom, 5)
                
                ForEach(["Checking system requirements",
                        "Removing Jamf management",
                        "Installing Company Portal",
                        "Configuring system settings"], id: \.self) { requirement in
                    PrivilegeRequirementRow(title: requirement)
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            
            if showSettingsPrompt {
                VStack(spacing: 10) {
                    Text("Helper Installation Required")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Please follow these steps:")
                        .font(.subheadline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Click 'Allow' in System Settings")
                        Text("2. Enable MDM Migrator in Login Items")
                        Text("3. Return to this app and click Install Helper")
                    }
                    .padding(.vertical, 5)
                }
                .padding()
                .background(Color(.windowBackgroundColor))
                .cornerRadius(10)
                .transition(.opacity)
            }
            
            Button {
                isInstalling = true
                showSettingsPrompt = false
                Task {
                    do {
                        await appState.requestPrivileges()
                    } catch {
                        showSettingsPrompt = true
                    }
                    isInstalling = false
                }
            } label: {
                HStack {
                    if isInstalling {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.8)
                    }
                    Text(isInstalling ? "Installing..." : "Install Helper")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .padding(.horizontal)
            .buttonStyle(PlainButtonStyle())
            .disabled(isInstalling)
            
            Text("You will be prompted for your administrator password")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(width: 600, height: 600)
        .animation(.easeInOut, value: showSettingsPrompt)
    }
}

struct PrivilegeRequirementRow: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.blue)
            Text(title)
                .font(.body)
        }
    }
}
