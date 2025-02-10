//
//  HelperProtocol.swift
//  MDMMigratorHelper
//
//  Created by Somesh Pathak on 22/01/2025.
//  Copyright (c) 2025 [Somesh Pathak]

import Foundation

import Foundation

@objc(HelperToolProtocol)
protocol HelperToolProtocol {
    func removeJamfManagement(withReply reply: @escaping (Error?) -> Void)
    func removeJamfFramework(withReply reply: @escaping (Error?) -> Void)
    func enrollInIntune(withReply reply: @escaping (Error?) -> Void)
    func rotateFileVaultKey(withReply reply: @escaping (Error?) -> Void)
    
    // Utility methods
    func getVersionString(withReply reply: @escaping (String) -> Void)
    func getCurrentUser(withReply reply: @escaping (String) -> Void)
    func checkToolVersion(version: String, withReply reply: @escaping (Bool) -> Void)
    
    // System requirement checks
    func checkJamfEnrollment(withReply reply: @escaping (Bool) -> Void)
    func checkFileVaultStatus(withReply reply: @escaping (Bool) -> Void)
    func checkGatekeeperStatus(withReply reply: @escaping (Bool) -> Void)
}
