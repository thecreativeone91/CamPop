import Foundation
import Network

class WebhookServer {
    private var listener: NWListener?
    var onWebhookReceived: (() -> Void)?
    
    init() {
        setupServer()
        // Listen for restart notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(restartServer),
            name: NSNotification.Name("RestartWebhookServer"),
            object: nil
        )
    }
    
    @objc private func restartServer() {
        listener?.cancel()
        listener = nil
        setupServer()
    }
    
    private func setupServer() {
        // Get port from UserDefaults with default value of 8080
        let port = UInt16(UserDefaults.standard.integer(forKey: "webhookPort"))
        let parameters = NWParameters.tcp
        
        do {
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(integerLiteral: port))
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    print("Server ready on port \(port)")
                case .failed(let error):
                    print("Server failed with error: \(error)")
                    // Try to restart with a different port
                    if let strongSelf = self {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                            let newPort = port + 1
                            UserDefaults.standard.set(newPort, forKey: "webhookPort")
                            UserDefaults.standard.synchronize()
                            strongSelf.setupServer()
                        }
                    }
                case .cancelled:
                    print("Server was cancelled")
                default:
                    break
                }
            }
            
            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }
            
            listener?.start(queue: .main)
        } catch {
            print("Failed to create listener: \(error)")
            // Try a different port
            let newPort = port + 1
            UserDefaults.standard.set(newPort, forKey: "webhookPort")
            UserDefaults.standard.synchronize()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                self.setupServer()
            }
        }
    }
    
    private func handleConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connection established")
            case .failed(let error):
                print("Connection failed: \(error)")
                connection.cancel()
            default:
                break
            }
        }
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            if let data = content, let requestString = String(data: data, encoding: .utf8) {
                print("Received webhook request: \(requestString)")
                
                // Parse the request line properly
                let requestLines = requestString.components(separatedBy: "\r\n")
                if let firstLine = requestLines.first {
                    let components = firstLine.components(separatedBy: " ")
                    if components.count >= 2 {
                        let path = components[1]
                        
                        switch path {
                        case "/arm":
                            UserDefaults.standard.set(true, forKey: "isArmed")
                            UserDefaults.standard.synchronize()
                            NotificationCenter.default.post(name: NSNotification.Name("UpdateArmToggle"), object: nil)
                        case "/disarm":
                            UserDefaults.standard.set(false, forKey: "isArmed")
                            UserDefaults.standard.synchronize()
                            NotificationCenter.default.post(name: NSNotification.Name("UpdateArmToggle"), object: nil)
                        case "/":
                            DispatchQueue.main.async {
                                self?.onWebhookReceived?()
                            }
                        default:
                            break
                        }
                    }
                }
                
                // Send HTTP response
                let response = """
                HTTP/1.1 200 OK\r
                Content-Type: text/plain\r
                Content-Length: 2\r
                Access-Control-Allow-Origin: *\r
                Connection: close\r
                \r
                OK
                """
                connection.send(content: response.data(using: .utf8)!, completion: .idempotent)
            }
            
            if error != nil || isComplete {
                connection.cancel()
            }
        }
        
        connection.start(queue: .main)
    }
}