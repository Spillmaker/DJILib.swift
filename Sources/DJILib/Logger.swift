//
//  Logger.swift
//  xirl
//
//  Created by Spillmaker on 03/10/2024.
//

import Foundation
import os.log

public enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

public class Logger: @unchecked Sendable {
    private static let shared = Logger()
    private let osLog: OSLog
    private let fileURL: URL
    private var logBuffer: [String] = []
    private let bufferQueue = DispatchQueue(label: "com.logger.bufferQueue")
    private let fileQueue = DispatchQueue(label: "com.logger.fileQueue")
    private let batchInterval: TimeInterval = 5.0
    
    public init() {
        osLog = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.app", category: "CustomLogger")
               
       // Use the Application Support directory instead of Documents
       let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
       let logsDirectory = appSupportDirectory.appendingPathComponent("Logs", isDirectory: true)
       
       // Create the Logs directory if it doesn't exist
       try? FileManager.default.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
       
       fileURL = logsDirectory.appendingPathComponent("app.log")
       
        clearLogFile()
        startBatchWriter()
    }
    
    private func clearLogFile() {
        do {
            try "".write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            os_log("Failed to clear log file: %{public}@", log: osLog, type: .error, error.localizedDescription)
        }
    }
    
    private func startBatchWriter() {
        Timer.scheduledTimer(withTimeInterval: batchInterval, repeats: true) { [weak self] _ in
            self?.writeBatchToFile()
        }
    }
    
    private func writeBatchToFile() {
        bufferQueue.sync {
            guard !logBuffer.isEmpty else { return }
            let batchToWrite = logBuffer
            logBuffer.removeAll()
            
            fileQueue.async {
                do {
                    let logString = batchToWrite.joined(separator: "\n") + "\n"
                    if FileManager.default.fileExists(atPath: self.fileURL.path) {
                        let fileHandle = try FileHandle(forWritingTo: self.fileURL)
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(logString.data(using: .utf8)!)
                        fileHandle.closeFile()
                    } else {
                        try logString.write(to: self.fileURL, atomically: true, encoding: .utf8)
                    }
                } catch {
                    os_log("Failed to write to log file: %{public}@", log: self.osLog, type: .error, error.localizedDescription)
                }
            }
        }
    }
    
    public static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let logMessage = "[\(timestamp)] [\(level.rawValue)] [\(fileName):\(line)] \(function) - \(message)"
        
        // Print to console
        //print(logMessage)
        
        // Log using os_log
        os_log("%{public}@", log: shared.osLog, type: shared.osLogType(for: level), logMessage)
        
        // Add to buffer for file logging
        shared.bufferQueue.async {
            shared.logBuffer.append(logMessage)
        }
    }
    
    private func osLogType(for level: LogLevel) -> OSLogType {
        switch level {
        case .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        }
    }
    
    public static func getLogFileURL() -> URL {
            return shared.fileURL
        }
}

// Usage example:
// Logger.log("This is a debug message", level: .debug)
// Logger.log("This is an info message")
// Logger.log("This is a warning message", level: .warning)
// Logger.log("This is an error message", level: .error)
