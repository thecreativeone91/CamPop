import Cocoa
import AVFoundation
import Security

class CameraController {
    private var process: Process?
    private var displayTimer: Timer?
    
    func showCamera() {
        guard let rtspUrl = UserDefaults.standard.string(forKey: "rtspUrl"), !rtspUrl.isEmpty else {
            print("RTSP URL not configured")
            return 
        }
        
        // Force reload settings
        let displayDuration = UserDefaults.standard.double(forKey: "displayDuration")
        let windowX = UserDefaults.standard.double(forKey: "windowX")
        let windowY = UserDefaults.standard.double(forKey: "windowY")
        let windowWidth = UserDefaults.standard.double(forKey: "windowWidth")
        let windowHeight = UserDefaults.standard.double(forKey: "windowHeight")
        
        // Kill any existing ffplay process
        terminateProcess()
        
        // Get ffplay path and resolve symlink
        let ffplayPath = "/opt/homebrew/bin/ffplay"
        let fileManager = FileManager.default
        
        // Resolve the symlink
        var resolvedPath: String
        do {
            resolvedPath = try fileManager.destinationOfSymbolicLink(atPath: ffplayPath)
            if !resolvedPath.hasPrefix("/") {
                resolvedPath = (ffplayPath as NSString).deletingLastPathComponent + "/" + resolvedPath
            }
            print("Resolved ffplay path: \(resolvedPath)")
        } catch {
            print("Error resolving symlink: \(error)")
            resolvedPath = ffplayPath
        }
        
        guard fileManager.fileExists(atPath: resolvedPath) else {
            print("ffplay not found at resolved path: \(resolvedPath)")
            return
        }
        
        // Start new ffplay process
        process = Process()
        process?.executableURL = URL(fileURLWithPath: resolvedPath)
        process?.arguments = [
            "-noborder",            // Borderless window
            "-alwaysontop",        // Keep window on top
            "-window_title", "ffplay",  // Add window title for easier identification
            "-fflags", "nobuffer",  // Disable buffering
            "-flags", "low_delay",  // Minimize latency
            "-framedrop",          // Allow frame dropping
            "-rtsp_transport", "tcp", // Force TCP transport
            "-protocol_whitelist", "file,crypto,tcp,udp,rtp,rtsp,tls,rtmps,rtsps",
            "-an",                 // Disable audio
            "-sn",                 // Disable subtitles
            rtspUrl
        ]
        
        let pipe = Pipe()
        process?.standardOutput = pipe
        process?.standardError = pipe
        
        // Set environment variables for X11 display
        var env = ProcessInfo.processInfo.environment
        env["DISPLAY"] = ":0"
        process?.environment = env
        
        // Read pipe for better error reporting
        pipe.fileHandleForReading.readabilityHandler = { handle in
            if let data = try? handle.read(upToCount: 1024),
               let output = String(data: data, encoding: .utf8) {
                print("ffplay output: \(output)")
            }
        }
        
        do {
            // Pre-position the window using defaults with correct format
            let script = """
            defaults write org.ffmpeg.ffplay "NSWindow Frame ffplay" "{{{\(Int(windowX)), \(Int(windowY))}, {\(Int(windowWidth)), \(Int(windowHeight))}}}"
            """
            let prePositionTask = Process()
            prePositionTask.launchPath = "/usr/bin/env"
            prePositionTask.arguments = ["bash", "-c", script]
            try prePositionTask.run()
            prePositionTask.waitUntilExit()
            
            try process?.run()
            print("Started ffplay process")
            
            // Position window with multiple attempts and increased delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {  // Increased delay
                self.positionWindowWithRetry(x: Int(windowX), y: Int(windowY), width: Int(windowWidth), height: Int(windowHeight))
            }
            
            // Set timer to close window
            displayTimer?.invalidate()
            displayTimer = Timer.scheduledTimer(withTimeInterval: displayDuration, repeats: false) { [weak self] _ in
                self?.terminateProcess()
            }
        } catch {
            print("Failed to start ffplay: \(error)")
            if let posixError = error as? POSIXError {
                print("POSIX error code: \(posixError.code.rawValue)")
            }
        }
    }
    
    private func positionWindowWithRetry(x: Int, y: Int, width: Int, height: Int, attempts: Int = 10) {
        func attempt(remaining: Int) {
            // Calculate the Y position accounting for screen height and window height
            let screenHeight = Int(NSScreen.main?.frame.height ?? 0)
            let adjustedY = screenHeight - y - height
            
            let script = """
            tell application "System Events"
                repeat with i from 1 to 5
                    try
                        set ffplayApp to first process whose name contains "ffplay"
                        tell ffplayApp
                            tell window 1
                                set size to {\(width), \(height)}
                                delay 0.1
                                set position to {\(x), \(adjustedY)}
                            end tell
                        end tell
                        return true
                    on error
                        delay 0.2
                    end try
                end repeat
            end tell
            """
            
            var error: NSDictionary?
            if let scriptObject = NSAppleScript(source: script) {
                _ = scriptObject.executeAndReturnError(&error)
                if error != nil && remaining > 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        attempt(remaining: remaining - 1)
                    }
                }
            }
        }
        
        attempt(remaining: attempts)
    }
    
    private func terminateProcess() {
        if process?.isRunning == true {
            process?.terminate()
            print("Terminated existing ffplay process")
        }
        process = nil
    }
}