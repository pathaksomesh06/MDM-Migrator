//
//  NotificationService.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]


import Foundation
import UserNotifications
import AppKit

final class NotificationService {
    static let shared = NotificationService()
    private let logger = Logger.shared
    private var notificationTimer: Timer?
    private var forceLaunchTimer: Timer?
    private let notificationInterval: TimeInterval = 15 * 60 // 15 minutes
    private let maxDeferralTime: TimeInterval = 60 * 60 // 1 hour
    private var notificationCount = 0
    private let maxNotifications = 4 // Will show 4 times in 1 hour (every 15 mins)
    
    private init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                self.logger.info("Notification authorization granted")
            } else {
                self.logger.error("Notification authorization denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func startMigrationNotifications() {
        // Schedule first notification immediately
        sendMigrationReadyNotification()
        
        // Set up recurring notifications
        notificationTimer = Timer.scheduledTimer(withTimeInterval: notificationInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.notificationCount += 1
            
            if self.notificationCount < self.maxNotifications {
                self.sendMigrationReadyNotification()
            } else {
                self.notificationTimer?.invalidate()
                self.forceLaunchApp()
            }
        }
        
        // Set up force launch timer
        forceLaunchTimer = Timer.scheduledTimer(withTimeInterval: maxDeferralTime, repeats: false) { [weak self] _ in
            self?.forceLaunchApp()
        }
    }
    
    func sendMigrationReadyNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Mac Ready for Migration"
        content.subtitle = "Jamf to Microsoft Intune"
        content.body = "Your Mac is ready to be migrated. Click to begin the process."
        content.sound = .default
        
        sendNotification(content: content, identifier: "migration-ready")
    }
    
    func showMigrationCompleteNotification(success: Bool) {
        let content = UNMutableNotificationContent()
        content.title = success ? "Migration Complete" : "Migration Failed"
        content.subtitle = "Jamf to Microsoft Intune"
        content.body = success ?
            "Your Mac has been successfully migrated to Microsoft Intune. Please launch Company Portal to complete setup." :
            "There was an issue during migration. Please contact IT support for assistance."
        content.sound = .default
        
        sendNotification(content: content, identifier: "migration-complete")
    }
    
    func showMigrationStartingNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Migration Starting"
        content.subtitle = "Jamf to Microsoft Intune"
        content.body = "The migration process is beginning. Please save any open work."
        content.sound = .default
        
        sendNotification(content: content, identifier: "migration-starting")
    }
    
    func showDeferredMigrationNotification(minutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Migration Scheduled"
        content.subtitle = "Starting in \(minutes) minutes"
        content.body = "Your Mac will begin migration to Microsoft Intune soon. Please save your work."
        content.sound = .default
        
        sendNotification(content: content, identifier: "migration-deferred")
    }
    
    func stopNotifications() {
        notificationTimer?.invalidate()
        forceLaunchTimer?.invalidate()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    // MARK: - Private Methods
    
    private func sendNotification(content: UNMutableNotificationContent, identifier: String) {
        let request = UNNotificationRequest(
            identifier: "\(identifier)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Failed to schedule notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func forceLaunchApp() {
        self.notificationTimer?.invalidate()
        self.forceLaunchTimer?.invalidate()
        
        // Force launch the app
        DispatchQueue.main.async {
            if let bundleIdentifier = Bundle.main.bundleIdentifier {
                let path = Bundle.main.bundlePath
                NSWorkspace.shared.launchApplication(path)
                self.logger.info("Forcing app launch after deferral period")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    func removeSpecificNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }
    
    func removeAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
    
    func isPendingNotificationPresent(identifier: String) async -> Bool {
        let pendingRequests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pendingRequests.contains { $0.identifier.starts(with: identifier) }
    }
}
