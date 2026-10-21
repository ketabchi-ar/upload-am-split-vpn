import Cocoa
import WebKit

class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler, WKNavigationDelegate, NSWindowDelegate {
    var window: NSWindow!
    var webView: WKWebView!
    var statusItem: NSStatusItem!

    let baseProfilePath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("upload-am-vpn.ovpn").path
    let activeProfilePath = "/tmp/upload_am_active.ovpn"
    let generatorScript = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("upload-am-split-vpn/scripts/generate_config.py").path
    let openvpnBin = "/opt/homebrew/sbin/openvpn"
    let pidFile = "/tmp/upload_am_vpn.pid"
    let logFile = "/tmp/upload_am_vpn.log"
    var pollTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupStatusItem()
        setupWindow()
        loadUI()

        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkStatusAndUpdate()
        }
    }

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "✈️ Upload.am VPN"
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Open Dashboard / داشبورد", action: #selector(showWindow), keyEquivalent: "d"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Connect / اتصال", action: #selector(menuConnect), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Disconnect / قطع", action: #selector(menuDisconnect), keyEquivalent: "x"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit / خروج", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func setupWindow() {
        let rect = NSRect(x: 200, y: 200, width: 460, height: 530)
        window = NSWindow(contentRect: rect,
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                          backing: .buffered, defer: false)
        window.center()
        window.title = "Upload.am Split VPN"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isMovableByWindowBackground = true
        window.delegate = self

        let visualEffect = NSVisualEffectView(frame: rect)
        visualEffect.blendingMode = .behindWindow
        visualEffect.material = .hudWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        window.contentView = visualEffect

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "action")
        webView = WKWebView(frame: visualEffect.bounds, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.autoresizingMask = [.width, .height]
        webView.navigationDelegate = self
        visualEffect.addSubview(webView)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func loadUI() {
        let htmlURL = Bundle.main.url(forResource: "index", withExtension: "html") ??
                      URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("upload-am-split-vpn/app/Resources/index.html").path)

        if let htmlContent = try? String(contentsOf: htmlURL, encoding: .utf8) {
            webView.loadHTMLString(htmlContent, baseURL: htmlURL.deletingLastPathComponent())
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let command = body["command"] as? String else { return }

        switch command {
        case "start":
            let mode = body["mode"] as? String ?? "telegram"
            let targets = body["targets"] as? String ?? ""
            startVPN(mode: mode, targets: targets)
        case "stop":
            stopVPN()
        case "poll":
            checkStatusAndUpdate()
        default:
            break
        }
    }

    @objc func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc func menuConnect() {
        startVPN(mode: "telegram", targets: "")
    }

    @objc func menuDisconnect() {
        stopVPN()
    }

    @objc func quitApp() {
        stopVPN()
        NSApp.terminate(nil)
    }

    func startVPN(mode: String, targets: String) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // Ensure base profile exists
            if !FileManager.default.fileExists(atPath: self.baseProfilePath) {
                DispatchQueue.main.async {
                    let err = "خطا: فایل کانفیگ اولیه upload-am-vpn.ovpn در دایرکتوری اصلی یافت نشد."
                    self.webView.evaluateJavaScript("updateUI(false, `\(err)`);", completionHandler: nil)
                }
                return
            }

            // Run generate_config.py
            let targetList = targets.split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " })
                                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                                    .filter { !$0.isEmpty }

            var genArgs = ["/usr/bin/python3", self.generatorScript,
                           "-i", self.baseProfilePath,
                           "-o", self.activeProfilePath,
                           "-m", mode]
            if !targetList.isEmpty {
                genArgs.append("-t")
                genArgs.append(contentsOf: targetList)
            }

            let genProcess = Process()
            genProcess.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
            genProcess.arguments = Array(genArgs.dropFirst())
            try? genProcess.run()
            genProcess.waitUntilExit()

            // Run openvpn via AppleScript for admin privileges
            let script = "do shell script \"\(self.openvpnBin) --config '\(self.activeProfilePath)' --daemon upload-am-vpn --writepid '\(self.pidFile)' --log '\(self.logFile)'; chmod 666 '\(self.logFile)' '\(self.pidFile)' 2>/dev/null\" with administrator privileges"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                self.checkStatusAndUpdate()
            }
        }
    }

    func stopVPN() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let script = "do shell script \"killall openvpn 2>/dev/null; rm -f '\(self.pidFile)'\" with administrator privileges"
            var error: NSDictionary?
            if let appleScript = NSAppleScript(source: script) {
                appleScript.executeAndReturnError(&error)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.checkStatusAndUpdate()
            }
        }
    }

    func isProcessRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "openvpn"]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    func readLogs() -> String {
        guard FileManager.default.fileExists(atPath: logFile) else {
            return "آماده اتصال به سرور."
        }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tail")
        task.arguments = ["-n", "10", logFile]
        let pipe = Pipe()
        task.standardOutput = pipe
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return "خطا در خواندن لاگ."
        }
    }

    func checkStatusAndUpdate() {
        let running = isProcessRunning()
        let rawLogs = readLogs()
        let escapedLogs = rawLogs.replacingOccurrences(of: "\\", with: "\\\\")
                                 .replacingOccurrences(of: "`", with: "\\`")
                                 .replacingOccurrences(of: "$", with: "\\$")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let button = self.statusItem.button {
                button.title = running ? "🟢 Upload.am VPN" : "⚪ Upload.am VPN"
            }
            let js = "updateUI(\(running ? "true" : "false"), `\(escapedLogs)`);"
            self.webView.evaluateJavaScript(js, completionHandler: nil)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        window.orderOut(nil)
        return false
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
