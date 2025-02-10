//
//  Intune4MacApp.swift
//  MDM Migrator
//
//  Created by somesh pathak on 31/10/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import SwiftUI
import UserNotifications

// MARK: - Main App
@main
struct Intune4MacApp: App {
    @StateObject private var appState = AppState()
    @State private var showSplash = true
    let appDelegate = AppDelegate()
    
    init() {
        NSApplication.shared.delegate = appDelegate
    }
    
    var body: some Scene {
        WindowGroup {
            MainContentView(showSplash: $showSplash, appState: appState)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

// MARK: - Main Content View
struct MainContentView: View {
    @Binding var showSplash: Bool
    @ObservedObject var appState: AppState
    
    var body: some View {
        Group {
            if showSplash {
                SplashView(isShowing: $showSplash)
            } else {
                if appState.isAuthorized {
                    NavigationStack {
                        WelcomeView()
                    }
                } else {
                    RequestPrivilegesView(appState: appState)
                }
            }
        }
        .frame(minWidth: 700, minHeight: 600)
        .onAppear {
            if let window = NSApplication.shared.windows.first {
                window.center()
                window.setFrameAutosaveName("MainWindow")
            }
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger.shared
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        setupMainWindow()
        NotificationService.shared.startMigrationNotifications()
    }
    
    private func setupMainWindow() {
        if let window = NSApplication.shared.windows.first {
            window.center()
            window.setFrameAutosaveName("MainWindow")
            window.makeKeyAndOrderFront(nil)
            
            window.standardWindowButton(.closeButton)?.isEnabled = false
            window.isReleasedWhenClosed = false
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NotificationService.shared.stopNotifications()
        logger.info("Application terminating, cleaned up resources")
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        NSApp.activate(ignoringOtherApps: true)
        NotificationService.shared.stopNotifications()
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
