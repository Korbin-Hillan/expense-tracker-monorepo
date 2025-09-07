//
//  Logger.swift
//  IOS-expense-tracker
//
//  Centralized logging utility with configurable levels
//

import Foundation
import os.log

enum LogLevel: Int, CaseIterable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case none = 5
    
    var emoji: String {
        switch self {
        case .verbose: return "💬"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .none: return ""
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .none: return .fault
        }
    }
}

final class Logger {
    static let shared = Logger()
    
    #if DEBUG
    private let currentLevel: LogLevel = .debug
    #else
    private let currentLevel: LogLevel = .error
    #endif
    
    private let osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "ExpenseTracker", category: "API")
    
    private init() {}
    
    func log(_ level: LogLevel, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard level.rawValue >= currentLevel.rawValue else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "\(level.emoji) [\(fileName):\(line)] \(function) - \(message)"
        
        os_log("%@", log: osLog, type: level.osLogType, formattedMessage)
    }
    
    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message, file: file, function: function, line: line)
    }
    
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }
    
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }
    
    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }
}