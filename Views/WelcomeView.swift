//
//  WelcomeView.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import SwiftUI

struct WelcomeView: View {
    @State private var navigateToPrerequisites = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Icon and Title
                Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                    .resizable()
                    .frame(width: 128, height: 128)
                
                Text("Welcome to MDM Migration")
                    .font(.largeTitle)
                    .bold()
                
                // Description
                VStack(alignment: .leading, spacing: 15) {
                    Text("This tool will help you migrate your Mac from Jamf to Microsoft Intune management.")
                        .multilineTextAlignment(.center)
                    
                    Text("The process will:")
                        .fontWeight(.medium)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        BulletPoint(text: "Preserve all your data and settings")
                        BulletPoint(text: "Install Microsoft Intune Company Portal")
                        BulletPoint(text: "Remove current management profile")
                        BulletPoint(text: "Take approximately 15-20 minutes")
                    }
                }
                .padding()
                .background(Color(.windowBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                
                Spacer()
                
                // Start Button
                Button {
                    navigateToPrerequisites = true
                } label: {
                    Text("Get Started")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(40)
            .frame(width: 600, height: 500)
            .navigationDestination(isPresented: $navigateToPrerequisites) {
                PreRequisitesView()
            }
        }
    }
}

struct BulletPoint: View {
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("•")
                .font(.title2)
                .foregroundColor(.blue)
            Text(text)
        }
    }
}

#Preview {
    WelcomeView()
}
