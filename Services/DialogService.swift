//
//  DialogService.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]


import Foundation
import AppKit

enum DialogServiceError: Error {
    case dialogNotInstalled
    case dialogFailed(String)
    case invalidResponse
    case migrationFailed(String)
}

final class DialogService {
    static let shared = DialogService()
    private let dialogPath = "/usr/local/bin/dialog"
    private let defaultIcon = "/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertNoteIcon.icns"
    private let logger = Logger.shared
    
    private init() {
        checkDialogInstallation()
    }
    
    private func checkDialogInstallation() {
        guard FileManager.default.fileExists(atPath: dialogPath) else {
            logger.warning("Swift Dialog not installed at \(dialogPath)")
            return
        }
    }
    
    private func executeDialogScript(_ script: String) throws -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        if let error = error {
            logger.error("Dialog script failed: \(error.description)")
            throw DialogServiceError.dialogFailed(error.description)
        }
        
        let output = result?.stringValue ?? ""
        logger.info("Dialog script raw output: \(output)")
        
        // Check if the output contains CoreSVG error; if so, ignore it
        if output.contains("CoreSVG") {
            logger.warning("CoreSVG issue detected; continuing with default selection")
            return "Button: 1" // Default to "Start Now" as a fallback
        }
        
        return output
    }
    func showDeferralOptions() async throws -> Int {
        logger.info("Showing deferral options dialog")
        
        let message = """
    When would you like to start the migration?

    The process will:
    - Preserve all your data and settings
    - Install Microsoft Intune Company Portal
    - Remove current management profile
    - Take approximately 15-20 minutes

    Please save all work before proceeding.
    """.replacingOccurrences(of: "•", with: "-")

        let script = """
        set dialogPath to "/usr/local/bin/dialog"
        set message to "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        set iconPath to "\(defaultIcon)"

        try
            set args to " --title 'Schedule Migration'"
            set args to args & " --message '" & message & "'"
            set args to args & " --icon '" & iconPath & "'"
            set args to args & " --button1text 'Start Now'"
            -- Remove or comment out these lines to disable the other buttons
            -- set args to args & " --button2text 'In 15 minutes'"
            -- set args to args & " --button3text 'In 30 minutes'"
            -- set args to args & " --button4text 'In 60 minutes'"
            set args to args & " --timer 0"
            set args to args & " --position 'center'"
            set args to args & " --ontop"
            set args to args & " --blurscreen"
            set args to args & " --infobuttontext 'Info'"

            set dialogCmd to dialogPath & args
            set response to do shell script dialogCmd

            if response contains "Button: 1" then
                return 1
            end if
            return 0
        end try
        """
        
        if let result = try executeDialogScript(script),
           let buttonNumber = Int(result) {
            logger.info("User selected option: \(buttonNumber)")
            return buttonNumber
        }
        
        throw DialogServiceError.invalidResponse
    }
    
    func showCountdown(minutes: Int) async throws {
        let message = """
        Migration will begin in \(minutes) minutes.
        
        Please:
        • Save all open documents
        • Close any applications you don't need
        • Keep your Mac plugged in if using a laptop
        
        Your Mac will remain functional during the migration.
        """
        
        let script = """
        set dialogPath to "/usr/local/bin/dialog"
        set message to "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        set iconPath to "\(defaultIcon)"
        
        try
            set args to " --title 'Migration Starting Soon'"
            set args to args & " --message '" & message & "'"
            set args to args & " --icon '" & iconPath & "'"
            set args to args & " --timer \(minutes * 60)"
            set args to args & " --position 'center'"
            set args to args & " --ontop"
            set args to args & " --blurscreen"
            
            do shell script dialogPath & args
        end try
        """
        
        try executeDialogScript(script)
    }
    
    func showProgress(
        title: String = "Migration in Progress",
        message: String,
        progress: Int,
        progressText: String
    ) async throws {
        let script = """
        set dialogPath to "/usr/local/bin/dialog"
        set message to "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        set iconPath to "\(defaultIcon)"
        set titleText to "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
        set progressMessage to "\(progressText.replacingOccurrences(of: "\"", with: "\\\""))"
        
        try
            set args to " --title '" & titleText & "'"
            set args to args & " --message '" & message & "'"
            set args to args & " --icon '" & iconPath & "'"
            set args to args & " --progress \(progress)"
            set args to args & " --progresstext '" & progressMessage & "'"
            set args to args & " --position 'center'"
            set args to args & " --ontop"
            set args to args & " --blurscreen"
            
            do shell script dialogPath & args
        end try
        """
        
        try executeDialogScript(script)
    }
    
    func updateProgress(progress: Int, progressText: String) async throws {
        let script = """
        set dialogPath to "/usr/local/bin/dialog"
        set progressMessage to "\(progressText.replacingOccurrences(of: "\"", with: "\\\""))"
        
        try
            set args to " --progress \(progress)"
            set args to args & " --progresstext '" & progressMessage & "'"
            
            do shell script dialogPath & args
        end try
        """
        
        try executeDialogScript(script)
    }
    
    func showCompletion(success: Bool) async throws {
        let title = success ? "Migration Complete" : "Migration Failed"
        let message = success ?
            """
            Your Mac has been successfully migrated to Microsoft Intune.
            
            What's Next:
            • Launch Company Portal to complete enrollment
            • Sign in with your work account
            • Contact IT support if you need assistance
            
            Thank you for your patience during the migration.
            """ :
            """
            There was an issue during the migration process.
            
            Please contact IT support for assistance.
            
            Error details have been logged and will be sent to the support team.
            """
        
        let script = """
        set dialogPath to "/usr/local/bin/dialog"
        set message to "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        set iconPath to "\(defaultIcon)"
        set titleText to "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
        
        try
            set args to " --title '" & titleText & "'"
            set args to args & " --message '" & message & "'"
            set args to args & " --icon '" & iconPath & "'"
            set args to args & " --button1text '\(success ? "Launch Company Portal" : "Contact Support")'"
            set args to args & " --position 'center'"
            set args to args & " --ontop"
            set args to args & " --blurscreen"
            
            do shell script dialogPath & args
        end try
        """
        
        try executeDialogScript(script)
    }
    
    func showAlert(title: String, message: String, buttonText: String = "OK") async throws {
        let script = """
        set dialogPath to "/usr/local/bin/dialog"
        set message to "\(message.replacingOccurrences(of: "\"", with: "\\\""))"
        set titleText to "\(title.replacingOccurrences(of: "\"", with: "\\\""))"
        set buttonLabel to "\(buttonText.replacingOccurrences(of: "\"", with: "\\\""))"
        
        try
            set args to " --title '" & titleText & "'"
            set args to args & " --message '" & message & "'"
            set args to args & " --icon 'caution'"
            set args to args & " --button1text '" & buttonLabel & "'"
            set args to args & " --position 'center'"
            set args to args & " --ontop"
            set args to args & " --blurscreen"
            
            do shell script dialogPath & args
        end try
        """
        
        try executeDialogScript(script)
    }
    
    private func escapeSingleQuotes(_ str: String) -> String {
        return str.replacingOccurrences(of: "'", with: "'\\''")
    }
}
