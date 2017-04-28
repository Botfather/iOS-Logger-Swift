//  MIT License
//
//  Copyright (c) 2017 Tushar Mohan
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit
import Foundation

/// To be used when the log file needs to be accessed. Returning a YES will delete the file. NO will retain the file
typealias LogFileAccessClosure = (String) -> (Bool)

/// The following are used to specigy the log output
///
/// - LogLevelFile: Log contents to file
/// - LogLevelConsole: Log contents to console
/// - LogLevelBoth: log contents to file and console Both

enum LogOutput {
    case LogOutputFile, LogOutputConsole, LogOutputBoth
}

/// Enumeration for Setting the Log Level
///
/// - LogLevelInfo: Prints INFO level Logs
/// - LogLevelWarn: Prints INFO WARNING Logs and lower
/// - LogLevelParse: Prints INFO PARSE Logs and lower
/// - LogLevelError: Prints INFO ERROR Logs and lower

enum LogLevel:Comparable {
    case LogLevelInfo, LogLevelWarn, LogLevelParse, LogLevelError
    
    /// Get the log level stamp for the set log level. Change the values in switch statement to return as per need
    ///
    /// - Returns: Log stamp for that level
    func getLevel() -> String {
        let refLevel: String
        
        switch self {
        case .LogLevelInfo:
            refLevel = "[INFO]"
        case .LogLevelWarn:
            refLevel = "[WARN]"
        case .LogLevelParse:
            refLevel = "[PARSE]"
        case .LogLevelError:
            refLevel = "[ERROR]"
        }
        
        return refLevel
    }
    
    static public func ==(x: LogLevel, y: LogLevel) -> Bool {
        return x.hashValue == y.hashValue
    }
    
    static public func <(x: LogLevel, y: LogLevel) -> Bool {
        return x.hashValue < y.hashValue
    }
}

// MARK: - Extension to get build number and version number at run time

fileprivate extension UIApplication {
    
    class func applicationVersion() -> String {
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as! String
    }
    
    class func applicationBuild() -> String {
        return Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as! String
    }
    
    class func versionBuild() -> String {
        let version = applicationVersion(), build = applicationBuild()
        
        return version == build ? "v\(version)" : "v\(version)(\(build))"
    }
}

class Logger {
    
    /************** Make changes here to vary the log level or log output and toggle logging **********************/
    
    static let loggingEnabled: Bool  = true                 ///Toggle logging
    static let logOutput: LogOutput  = .LogOutputBoth       ///Change Output
    static let minLogLevel: LogLevel = .LogLevelError       ///Change Log Error Level
    
    /**************************************************************************************************************/
    
    static let loggingQueue = DispatchQueue(label:"loggingQueue", qos:.background)
    
    class func info(_ items: Any, file: String = #file, line: Int = #line, function: String = #function) {
        buildLogStatement(items, file: file, line: line, function: function,level:LogLevel.LogLevelInfo)
    }
    
    class func warn(_ items: Any, file: String = #file, line: Int = #line, function: String = #function) {
        buildLogStatement(items, file: file, line: line, function: function,level:LogLevel.LogLevelWarn)
    }
    
    class func parse(_ items: Any, file: String = #file, line: Int = #line, function: String = #function) {
        buildLogStatement(items, file: file, line: line, function: function,level:LogLevel.LogLevelParse)
    }
    
    class func error(_ items: Any, file: String = #file, line: Int = #line, function: String = #function) {
        buildLogStatement(items, file: file, line: line, function: function,level:LogLevel.LogLevelError)
    }
    
    
    /// 🚧 Work in Progress. Have not yet tested the following code. Will update this soon. ⏱ 🚧
    /// Access the log file
    ///
    /// - Parameter handler: return YES to delete the log file else return NO
    class func getLogFile(handler: LogFileAccessClosure?) {
        guard let callbackHandler = handler else {return}
        
        guard let filePath = getLogFilePath() else {return}
        
        let isOperationComplete: Bool = callbackHandler(filePath)
        if isOperationComplete {
            let fileMgr = FileManager.default
            try? fileMgr.removeItem(atPath: filePath)
        }
    }
    /// 🚧 Work in Progress. Have not yet tested the code above. Will update this soon. ⏱ 🚧
    
    // MARK: - Private
    
    /// Get the file name from the path
    class private func getFileNameFromPath(_ fileNameWithPath: String) -> String {
        guard let fileURL = URL(string:fileNameWithPath) else {return fileNameWithPath}
        
        return fileURL.deletingPathExtension().lastPathComponent
    }
    
    /// Generates the log statements with time and log level stampings
    class private func buildLogStatement(_ items: Any..., file: String = #file, line: Int = #line, function: String = #function, level:LogLevel) {
        
        guard loggingEnabled == true, level <= minLogLevel else {return}
        
        loggingQueue.sync {
            let filename = getFileNameFromPath(file)
            let dateStamp = Date()
            let dateFormatter = DateFormatter()
            
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            
            let loggerText = "[\(dateFormatter.string(from: dateStamp))]: \(level.getLevel())-\(filename)-\(line): \(function):- \(items.map({ String(describing: $0) }).joined(separator: ""))"
            
            switch(logOutput) {
                
            case .LogOutputConsole:
                logToConsole(loggerText)
            case .LogOutputFile:
                log(toFile: loggerText)
            case .LogOutputBoth:
                log(toFile: loggerText)
                logToConsole(loggerText)
            }
        }
        
    }
    
    class private func logToConsole(_ text: String) {
        print(text,separator: "", terminator: "\n")
    }
    
    class func log(toFile log: String) {
        
        let fileLogString = log.appending("\n")
        
        guard let logFilePath = getLogFilePath(), let dataToWrite = fileLogString.data(using: String.Encoding.utf8) else {return}
        
        guard let fileHandle = FileHandle(forWritingAtPath: logFilePath) else { return }
        
        fileHandle.seekToEndOfFile()
        fileHandle.write(dataToWrite)
        fileHandle.closeFile()
        
    }
    
    class private func getLogFilePath() -> String? {
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        guard let filePath  = URL(string:documents)?.appendingPathComponent("log.txt").absoluteString else {return nil}
        
        let informationString = "*** \(UIApplication.versionBuild()) *** \n"
        
        guard let  _ = FileHandle(forWritingAtPath: filePath) else {
            try? informationString.write(toFile: filePath, atomically: false, encoding: .utf8)
            return filePath }
        
        return filePath
    }
    
}
