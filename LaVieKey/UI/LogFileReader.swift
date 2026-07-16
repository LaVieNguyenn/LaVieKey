//
//  LogFileReader.swift
//  LaVieKey
//
//  Incremental log file reader for Debug Window
//  Reads only new lines from the log file to minimize memory usage
//

import Foundation

/// Efficient log file reader that tracks file position for incremental reads
class LogFileReader {
    
    // MARK: - Properties
    
    /// Path to the log file
    private let fileURL: URL
    
    /// Last read position in the file
    private var lastReadPosition: UInt64 = 0
    
    /// Maximum number of lines to keep in memory
    private let maxLines: Int
    
    /// File handle for reading
    private var fileHandle: FileHandle?
    
    /// Queue for file operations
    private let readQueue = DispatchQueue(label: "com.laviekey.logreader", qos: .utility)
    
    // MARK: - Initialization
    
    init(fileURL: URL, maxLines: Int = 1000) {
        self.fileURL = fileURL
        self.maxLines = maxLines
    }
    
    deinit {
        try? fileHandle?.close()
    }
    
    // MARK: - Public Methods
    
    /// Read new lines from the log file since last read
    /// - Parameter completion: Callback with new lines (called on main thread)
    func readNewLines(completion: @escaping ([String]) -> Void) {
        readQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newLines = self.readNewLinesSync()
            
            DispatchQueue.main.async {
                completion(newLines)
            }
        }
    }
    
    /// Read all lines from the beginning (for initial load)
    /// - Parameter completion: Callback with all lines (limited to maxLines)
    func readAllLines(completion: @escaping ([String]) -> Void) {
        readQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Reset position to read from beginning
            self.lastReadPosition = 0
            
            let allLines = self.readAllLinesSync()
            
            DispatchQueue.main.async {
                completion(allLines)
            }
        }
    }
    
    /// Reset the reader to start from beginning
    func reset() {
        readQueue.async { [weak self] in
            self?.lastReadPosition = 0
            try? self?.fileHandle?.close()
            self?.fileHandle = nil
        }
    }
    
    /// Get the current file size
    func getFileSize() -> UInt64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? UInt64 else {
            return 0
        }
        return size
    }
    
    // MARK: - Private Methods
    
    private func readNewLinesSync() -> [String] {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        
        // Get current file size
        let fileSize = getFileSize()
        
        // If file was truncated (smaller than last position), reset
        if fileSize < lastReadPosition {
            lastReadPosition = 0
        }
        
        // No new data
        if fileSize <= lastReadPosition {
            return []
        }
        
        // Open file handle if needed
        if fileHandle == nil {
            fileHandle = try? FileHandle(forReadingFrom: fileURL)
        }
        
        guard let handle = fileHandle else { return [] }
        
        do {
            // Seek to last read position
            try handle.seek(toOffset: lastReadPosition)
            
            // Read new data
            let newDataLength = fileSize - lastReadPosition
            guard let data = try handle.read(upToCount: Int(newDataLength)),
                  let content = String(data: data, encoding: .utf8) else {
                return []
            }
            
            // Update position
            lastReadPosition = fileSize
            
            // Split into lines and filter empty
            let lines = content.components(separatedBy: .newlines)
                .filter { !$0.isEmpty }
            
            return lines
            
        } catch {
            // Reset handle on error
            try? handle.close()
            fileHandle = nil
            return []
        }
    }
    
    private func readAllLinesSync() -> [String] {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return []
        }
        
        // Update position to end
        lastReadPosition = getFileSize()
        
        // Split and get last N lines
        var lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        
        // Keep only last maxLines
        if lines.count > maxLines {
            lines = Array(lines.suffix(maxLines))
        }
        
        return lines
    }
}
