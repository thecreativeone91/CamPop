import SwiftUI
import AppKit

struct SettingsView: View {
    @AppStorage("rtspUrl") private var rtspUrl: String = ""
    @AppStorage("displayDuration") private var displayDuration: Double = 5.0
    @AppStorage("windowX") private var windowX: Double = 1600
    @AppStorage("windowY") private var windowY: Double = 900
    @AppStorage("windowWidth") private var windowWidth: Double = 960
    @AppStorage("windowHeight") private var windowHeight: Double = 540
    @AppStorage("webhookPort") private var webhookPort: Int = 8080
    
    @State private var showingPositioner = false
    
    var body: some View {
        VStack {
            Form {
                Section(header: Text("RTSP Stream")) {
                    TextField("RTSP URL", text: $rtspUrl)
                        .onChange(of: rtspUrl) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "rtspUrl")
                            UserDefaults.standard.synchronize()
                        }
                    HStack {
                        Text("Display Duration")
                        Slider(value: $displayDuration, in: 1...30)
                            .onChange(of: displayDuration) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "displayDuration")
                                UserDefaults.standard.synchronize()
                            }
                        Text("\(Int(displayDuration))s")
                    }
                }
                
                Section(header: Text("Webhook Settings")) {
                    HStack {
                        Text("Port")
                        TextField("", value: $webhookPort, formatter: NumberFormatter())
                            .frame(width: 80)
                            .onChange(of: webhookPort) { _, newValue in
                                UserDefaults.standard.set(newValue, forKey: "webhookPort")
                                UserDefaults.standard.synchronize()
                                // Restart the webhook server to apply new port
                                NotificationCenter.default.post(name: NSNotification.Name("RestartWebhookServer"), object: nil)
                            }
                    }
                }
                
                Section(header: Text("Window Position")) {
                    Button("Configure Window Position and Size") {
                        openPositioningWindow()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(height: 250) // Increased height to accommodate new section
        }
        .frame(width: 400)
    }
    
    private func openPositioningWindow() {
        let positioningWindow = NSWindow(
            contentRect: NSScreen.main?.frame ?? .zero,
            styleMask: [.titled, .closable],  // Changed style mask to allow key window
            backing: .buffered,
            defer: false
        )
        positioningWindow.level = .floating
        positioningWindow.backgroundColor = .clear
        positioningWindow.isOpaque = false
        positioningWindow.hasShadow = false
        positioningWindow.acceptsMouseMovedEvents = true
        positioningWindow.ignoresMouseEvents = false
        positioningWindow.titleVisibility = .hidden
        positioningWindow.titlebarAppearsTransparent = true
        
        let hostingView = NSHostingView(rootView: WindowPositioningView(
            windowX: $windowX,
            windowY: $windowY,
            windowWidth: $windowWidth,
            windowHeight: $windowHeight,
            window: positioningWindow
        ))
        
        positioningWindow.contentView = hostingView
        positioningWindow.makeKeyAndOrderFront(nil)
    }
}

struct WindowPositioningView: View {
    @Binding var windowX: Double
    @Binding var windowY: Double
    @Binding var windowWidth: Double
    @Binding var windowHeight: Double
    let window: NSWindow
    
    @State private var dragPosition: CGPoint = .zero
    @State private var dragSize: CGSize = .zero
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent overlay
                Color.black.opacity(0.2)
                
                // Draggable window preview
                Rectangle()
                    .strokeBorder(Color.red, lineWidth: 2)
                    .background(Color.red.opacity(0.1))
                    .frame(width: dragSize.width, height: dragSize.height)
                    .position(x: dragPosition.x, y: dragPosition.y)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                }
                                dragPosition = value.location
                                // Update bindings immediately during drag
                                windowX = Double(dragPosition.x)
                                let screenHeight = NSScreen.main?.frame.height ?? 0
                                windowY = Double(screenHeight - dragPosition.y)
                                
                                // Save immediately
                                UserDefaults.standard.set(windowX, forKey: "windowX")
                                UserDefaults.standard.set(windowY, forKey: "windowY")
                                UserDefaults.standard.synchronize()
                            }
                    )
                
                // Resize handle
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 20, height: 20)
                    .position(x: dragPosition.x + dragSize.width/2, y: dragPosition.y + dragSize.height/2)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newWidth = max(320, min(value.location.x - dragPosition.x + dragSize.width/2, 1920))
                                let newHeight = max(240, min(value.location.y - dragPosition.y + dragSize.height/2, 1080))
                                dragSize = CGSize(width: newWidth, height: newHeight)
                                // Update bindings immediately during resize
                                windowWidth = Double(dragSize.width)
                                windowHeight = Double(dragSize.height)
                                // Save immediately
                                UserDefaults.standard.set(windowWidth, forKey: "windowWidth")
                                UserDefaults.standard.set(windowHeight, forKey: "windowHeight")
                                UserDefaults.standard.synchronize()
                            }
                    )
                
                // Done button with better visibility
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            // Save final position and size
                            windowX = Double(dragPosition.x)
                            windowY = Double(NSScreen.main?.frame.height ?? 0 - dragPosition.y)
                            windowWidth = Double(dragSize.width)
                            windowHeight = Double(dragSize.height)
                            
                            // Ensure values are saved to UserDefaults
                            UserDefaults.standard.synchronize()
                            
                            // Close the window
                            window.close()
                        }) {
                            Text("Save & Close")
                                .font(.headline)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                        .shadow(radius: 3)
                        .padding(20)
                    }
                    Spacer()
                }
            }
            .onAppear {
                // Load saved position correctly
                let screenHeight = NSScreen.main?.frame.height ?? 0
                dragPosition = CGPoint(
                    x: UserDefaults.standard.double(forKey: "windowX"),
                    y: screenHeight - UserDefaults.standard.double(forKey: "windowY")
                )
                dragSize = CGSize(
                    width: UserDefaults.standard.double(forKey: "windowWidth"),
                    height: UserDefaults.standard.double(forKey: "windowHeight")
                )
            }
        }
    }
}