//
//  PrivilegeManager.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import Security

class PrivilegeManager: ObservableObject {
    static let shared = PrivilegeManager()
    private let logger = Logger.shared
    
    @Published private(set) var isAuthorized = false
    private var authRef: AuthorizationRef?
    
    private init() {}
    
    func requestPrivileges() async throws {
        guard authRef == nil else {
            // Already have privileges
            return
        }
        
        var authRef: AuthorizationRef?
        var rights = AuthorizationRights()
        var flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        
        // Set up authorization items
        let items = [
            AuthorizationItem(name: kAuthorizationRightExecute, valueLength: 0, value: nil, flags: 0),
            AuthorizationItem(name: "system.privilege.admin", valueLength: 0, value: nil, flags: 0)
        ]
        
        rights.count = UInt32(items.count)
        rights.items = UnsafeMutablePointer(mutating: items)
        
        // Note: The call to AuthorizationCreate has been corrected
        let status = AuthorizationCreate(&rights, nil, flags, &authRef)
        guard status == errAuthorizationSuccess else {
            logger.error("Failed to create authorization reference")
            throw PrivilegeError.authorizationFailed
        }
        
        if let authRef = authRef {
            self.authRef = authRef
            await MainActor.run {
                self.isAuthorized = true
            }
            logger.info("Successfully obtained and stored admin privileges")
        } else {
            logger.error("Failed to obtain admin privileges")
            throw PrivilegeError.privilegeAcquisitionFailed
        }
    }

    
    func executePrivilegedCommand(_ command: String, arguments: [String] = []) throws -> String {
        guard let authRef = authRef else {
            throw PrivilegeError.noPrivileges
        }
        
        var error: OSStatus = noErr
        var outputFile: AuthorizationExternalForm = AuthorizationExternalForm()
        
        error = AuthorizationMakeExternalForm(authRef, &outputFile)
        guard error == errAuthorizationSuccess else {
            throw PrivilegeError.authorizationFailed
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sudo")
        process.arguments = [command] + arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            if process.terminationStatus != 0 {
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                throw PrivilegeError.commandExecutionFailed(errorOutput)
            }
            
            return String(data: outputData, encoding: .utf8) ?? ""
        } catch {
            throw PrivilegeError.commandExecutionFailed(error.localizedDescription)
        }
    }
    
    func maintainPrivileges() {
        // Periodically verify privileges are still valid
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task {
                do {
                    try await self.verifyPrivileges()
                } catch {
                    self.logger.error("Failed to maintain privileges: \(error)")
                    await MainActor.run {
                        self.isAuthorized = false
                    }
                }
            }
        }
    }
    
    private func verifyPrivileges() async throws {
        guard let authRef = authRef else {
            throw PrivilegeError.noPrivileges
        }
        
        // Try to execute a simple privileged command to verify
        do {
            _ = try executePrivilegedCommand("/usr/bin/whoami")
        } catch {
            // If verification fails, request privileges again
            try await requestPrivileges()
        }
    }
    
    func releasePrivileges() {
        if let authRef = authRef {
            AuthorizationFree(authRef, [])
            self.authRef = nil
            isAuthorized = false
            logger.info("Released admin privileges")
        }
    }
    
    deinit {
        releasePrivileges()
    }
}

enum PrivilegeError: LocalizedError {
    case authorizationFailed
    case privilegeAcquisitionFailed
    case noPrivileges
    case commandExecutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Failed to create authorization"
        case .privilegeAcquisitionFailed:
            return "Failed to acquire admin privileges"
        case .noPrivileges:
            return "No admin privileges available"
        case .commandExecutionFailed(let error):
            return "Command execution failed: \(error)"
        }
    }
}
