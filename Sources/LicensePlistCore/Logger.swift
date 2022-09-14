import HeliumLogger
import LoggerAPI
import Foundation
import TSCBasic
import System

public struct LoggerConfiguration {
    public var silence: Bool
    public var colored: Bool
    public var verbose: Bool

    public static let noColorEnv = "NO_COLOR"
    private static let env = ProcessInfo.processInfo.environment
    
    public init(silenceModeCommandLineFlag: Bool,
                noColorCommandLineFlag: Bool,
                colorCommandLineFlag: Bool,
                verboseCommandLineFlag: Bool){
        silence = silenceModeCommandLineFlag
        
        colored = {
            // commandline
            if noColorCommandLineFlag {
                return false
            }
            if colorCommandLineFlag {
                return true
            }
            
            // environment variable:
            if Self.env[Self.noColorEnv] == "1" {
                return false
            }
            
            // auto:
            do {
                let terminalType = try terminalType();
                
                switch terminalType {
                case .file:
                    return false
                case .dumb:
                    return false // dumb terminals don't interpret escape sequences
                case .tty:
                    break // keep guessing
                }

                // TODO: detect pipe and -> no-color
            } catch { // TODO: catch specific error
            }
            
            if Self.env["TERM"] == "xterm-256color" {
                return true
            }
            
            return false
        }()
        
        self.verbose = verboseCommandLineFlag
    }
}

public struct Logger {
    public static func configure(with loggerConfiguration: LoggerConfiguration) {
        if loggerConfiguration.silence {
            return
        }

        let logger: HeliumLogger = {
            if loggerConfiguration.verbose {
                return createDebugLogger()
            } else {
                return createDefaultLogger()
            }
        }()
        
        logger.colored = loggerConfiguration.colored
        Log.logger = logger
    }

    private static func createDefaultLogger() -> HeliumLogger {
        let logger = HeliumLogger(LoggerMessageType.info)
        logger.details = false
        return logger
    }

    private static func createDebugLogger() -> HeliumLogger {
        let logger = HeliumLogger(LoggerMessageType.debug)
        logger.details = true
        return logger
    }
}

fileprivate func terminalType() throws -> TerminalController.TerminalType {
    // FILEPointer(aka UnsafeMutablePointer<FILE>)はCのFILE*と同じと仮定
    // fdopenで fileDescriptorから filePointerを作り、
    // FILEPointerからLocalFileOutputByteStream を作り、terminalTypeを取得
    let stdOutFileDescriptor: Int32 = {
        if #available(macOS 11,*) {
            return FileDescriptor.standardOutput.rawValue as Int32
        } else {
            return 1 as Int32
        }
    }()
    
    let mode = "r"
    let terminalType:TerminalController.TerminalType = try mode.withCString {
        (modeCString: UnsafePointer<CChar>) -> TerminalController.TerminalType in
        
        let filePointer: FILEPointer! = fdopen(stdOutFileDescriptor, modeCString)
        let stream = try LocalFileOutputByteStream(filePointer: filePointer)
        // TerminalController.terminalType() use isatty() inside.
        return TerminalController.terminalType(stream)
    }
    
    return terminalType
}
