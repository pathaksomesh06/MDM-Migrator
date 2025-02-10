//
//  HelperToolServiceManager.swift
//  MDM Migrator
//
//  Created by somesh pathak on 03/11/2024.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation
import ServiceManagement
import Security
import AppKit

typealias HelperToolProtocolType = HelperToolProtocol

@MainActor
final class HelperToolServiceManager: ObservableObject {
    static let shared = HelperToolServiceManager()
    private let helperToolBundleId = "IntuneIRL.MDMMigrator.helper"
    private var connection: NSXPCConnection?
    private let logger = Logger.shared
    private let operationQueue = DispatchQueue(label: "com.intune4mac.helper", qos: .userInitiated)
    
    @Published private(set) var isHelperToolInstalled = false
    @Published private(set) var isHelperToolRunning = false
    
    private init() {
        Task { @MainActor in
            checkHelperToolStatus()
        }
    }
    
    private func checkHelperToolStatus() {
        let helperURL = URL(fileURLWithPath: "/Library/PrivilegedHelperTools/\(helperToolBundleId)")
        let bundledHelperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/\(helperToolBundleId)")
        
        logger.info("""
        Helper Tool Status Check:
        - Helper Bundle ID: \(helperToolBundleId)
        - Installation Path: \(helperURL.path)
        - Installation exists: \(FileManager.default.fileExists(atPath: helperURL.path))
        - Bundle Path: \(bundledHelperURL.path)
        - Bundle exists: \(FileManager.default.fileExists(atPath: bundledHelperURL.path))
        """)
        
        isHelperToolInstalled = FileManager.default.fileExists(atPath: helperURL.path)
        
        if !FileManager.default.fileExists(atPath: bundledHelperURL.path) {
            logger.error("Helper tool not found in app bundle")
        }
        
        Task {
            do {
                let proxy = try getHelperToolProxy()
                proxy.getVersionString { [weak self] version in
                    Task { @MainActor in
                        self?.isHelperToolRunning = true
                        self?.logger.info("Helper Tool Version: \(version)")
                    }
                }
            } catch {
                await MainActor.run {
                    self.isHelperToolRunning = false
                    self.logger.error("Helper tool not running: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func installHelperTool() async throws {
        logger.info("Starting helper tool installation")
        
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let bundledHelperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/\(self.helperToolBundleId)")
                    let bundledPlistURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchDaemons/\(self.helperToolBundleId).plist")
                    
                    guard FileManager.default.fileExists(atPath: bundledHelperURL.path) else {
                        let error = "Helper tool not found at: \(bundledHelperURL.path)"
                        self.logger.error(error)
                        throw NSError(domain: "HelperToolServiceManager", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: error])
                    }
                    
                    guard FileManager.default.fileExists(atPath: bundledPlistURL.path) else {
                        let error = "LaunchDaemon plist not found at: \(bundledPlistURL.path)"
                        self.logger.error(error)
                        throw NSError(domain: "HelperToolServiceManager", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: error])
                    }
                    
                    self.logger.info("Found helper binary and plist")
                    
                    if #available(macOS 13.0, *) {
                        Task { @MainActor in
                            do {
                                try await self.installHelperToolWithSMAppService()
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    } else {
                        Task { @MainActor in
                            do {
                                try await self.installHelperToolWithSMJobBless()
                                continuation.resume()
                            } catch {
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                    
                    Task { @MainActor in
                        self.checkHelperToolStatus()
                        self.logger.info("Helper tool installation completed")
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    @available(macOS 13.0, *)
    private func installHelperToolWithSMAppService() async throws {
        logger.info("Installing helper tool using SMAppService")
        
        let service = SMAppService.daemon(plistName: "\(helperToolBundleId).plist")
        logger.info("Current service status: \(service.status)")
        
        if service.status == .requiresApproval {
            logger.info("Service requires approval, attempting authorization")
            
            await Task(priority: .userInitiated) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }.value
            
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            do {
                try await Task(priority: .userInitiated) {
                    try await service.register()
                }.value
                
                if service.status != .enabled {
                    throw NSError(domain: "HelperToolServiceManager",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Service registration failed"])
                }
            } catch {
                logger.error("Registration failed: \(error.localizedDescription)")
                throw error
            }
        } else if service.status != .enabled {
            try await Task(priority: .userInitiated) {
                try await service.register()
            }.value
        }
        
        logger.info("Service status after registration: \(service.status)")
    }
    
    private func installHelperToolWithSMJobBless() async throws {
        logger.info("Installing helper tool using SMJobBless")
        
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                var authRef: AuthorizationRef?
                let flags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
                
                var error = AuthorizationCreate(nil, nil, flags, &authRef)
                guard error == errAuthorizationSuccess else {
                    continuation.resume(throwing: NSError(domain: NSOSStatusErrorDomain, code: Int(error)))
                    return
                }
                
                guard let authorization = authRef else {
                    continuation.resume(throwing: NSError(domain: "HelperToolServiceManager", code: -1,
                                                       userInfo: [NSLocalizedDescriptionKey: "Failed to create authorization"]))
                    return
                }
                
                defer {
                    if let authRef = authRef {
                        AuthorizationFree(authRef, [])
                    }
                }
                
                var cfError: Unmanaged<CFError>?
                let result = SMJobBless(kSMDomainSystemLaunchd,
                                      self.helperToolBundleId as CFString,
                                      authorization,
                                      &cfError)
                
                if !result {
                    if let error = cfError?.takeRetainedValue() {
                        self.logger.error("Failed to install helper tool: \(error.localizedDescription)")
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: NSError(domain: "HelperToolServiceManager", code: -1,
                                                           userInfo: [NSLocalizedDescriptionKey: "Failed to install helper tool"]))
                    }
                    return
                }
                
                self.logger.info("Helper tool installed successfully via SMJobBless")
                continuation.resume()
            }
        }
    }
    
    func getHelperToolProxy() throws -> HelperToolProtocolType {
        if connection == nil {
            let newConnection = NSXPCConnection(machServiceName: helperToolBundleId)
            newConnection.remoteObjectInterface = NSXPCInterface(with: HelperToolProtocolType.self)
            
            newConnection.invalidationHandler = { [weak self] in
                Task { @MainActor in
                    self?.connection = nil
                    self?.isHelperToolRunning = false
                }
            }
            
            newConnection.resume()
            connection = newConnection
        }
        
        guard let proxy = connection?.remoteObjectProxy as? HelperToolProtocolType else {
            throw NSError(domain: "HelperToolServiceManager", code: -1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to get helper tool proxy"])
        }
        
        return proxy
    }
    
    // MARK: - Helper Tool Operations
    
    func removeJamfManagement() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.removeJamfManagement { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func removeJamfFramework() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.removeJamfFramework { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func enrollInIntune() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.enrollInIntune { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func rotateFileVaultKey() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.rotateFileVaultKey { error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume()
                        }
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - System Requirement Checks
    
    func checkJamfEnrollment() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.checkJamfEnrollment { isEnrolled in
                        continuation.resume(returning: isEnrolled)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func checkFileVaultStatus() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.checkFileVaultStatus { isEnabled in
                        continuation.resume(returning: isEnabled)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func checkGatekeeperStatus() async throws -> Bool {
        return try await withCheckedThrowingContinuation { continuation in
            operationQueue.async {
                do {
                    let proxy = try self.getHelperToolProxy()
                    proxy.checkGatekeeperStatus { isEnabled in
                        continuation.resume(returning: isEnabled)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
