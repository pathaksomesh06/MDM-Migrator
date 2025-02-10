//
//  AppState.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import SwiftUI

@MainActor
class AppState: ObservableObject {
   @Published var isAuthorized = false
   @Published var showError = false
   @Published var errorMessage = ""
   
   private let logger = Logger.shared
   private let helperManager = HelperToolServiceManager.shared

   func requestPrivileges() async {
       print("Starting privilege request")
       do {
           print("Checking helper installation: \(helperManager.isHelperToolInstalled)")
           print("Helper running status: \(helperManager.isHelperToolRunning)")
           
           if !helperManager.isHelperToolInstalled {
               print("Installing helper tool")
               try await helperManager.installHelperTool()
               print("Helper tool installation completed")
           }
           
           print("Getting helper proxy")
           let proxy = try helperManager.getHelperToolProxy()
           
           proxy.getVersionString { version in
               print("Helper version: \(version)")
           }
           
           print("Authorization successful")
           isAuthorized = true
           showError = false
           errorMessage = ""
           logger.info("Successfully authorized via helper tool")
           
       } catch {
           print("Authorization failed: \(error)")
           isAuthorized = false
           errorMessage = "Failed to authorize: \(error.localizedDescription)"
           showError = true
           logger.error("Failed to authorize: \(error)")
       }
   }
}
